// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FeeHandler} from "./FeeHandler.sol";
import {PurchaseRbtc} from "./PurchaseRbtc.sol";
import {IWRBTC} from "./interfaces/IWRBTC.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {ICoinPairPrice} from "./interfaces/ICoinPairPrice.sol";
import {IPurchaseUniswap} from "./interfaces/IPurchaseUniswap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PurchaseUniswap
 * @notice This contract handles swaps of stablecoin for rBTC using Uniswap V3
 */
abstract contract PurchaseUniswap is
    FeeHandler,
    PurchaseRbtc,
    IPurchaseUniswap
{
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IERC20 public immutable i_purchasingToken;
    IWRBTC public immutable i_wrBtcToken;
    ISwapRouter02 public immutable i_swapRouter02;
    ICoinPairPrice public immutable i_MocOracle;
    uint256 constant HUNDRED_PERCENT = 1 ether;
    uint256 internal s_amountOutMinimumPercent = 0.997 ether; // Default to 99.7%
    uint256 internal s_amountOutMinimumSafetyCheck = 0.99 ether; // Default to 99%
    bytes public s_swapPath;

    /**
     * @param stableTokenAddress the address of the stablecoin token on the blockchain of deployment
     * @param uniswapSettings the settings for the uniswap router
     */
    constructor(
        address stableTokenAddress, // TODO: modify this to passing the interface
        UniswapSettings memory uniswapSettings
    ) 
    {
        i_purchasingToken = IERC20(stableTokenAddress);
        i_swapRouter02 = uniswapSettings.swapRouter02;
        i_wrBtcToken = uniswapSettings.wrBtcToken;
        i_MocOracle = uniswapSettings.mocOracle;
        setPurchasePath(uniswapSettings.swapIntermediateTokens, uniswapSettings.swapPoolFeeRates);
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @param purchaseAmount: the amount to spend on rBTC
     * @param purchasePeriod: the period between purchases
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer, bytes32 scheduleId, uint256 purchaseAmount, uint256 purchasePeriod)
        external
        override
        onlyDcaManager
    {
        // Redeem stablecoin (repaying yield bearing token)
        purchaseAmount = _redeemStablecoin(buyer, purchaseAmount);

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(i_purchasingToken, fee);

        // Swap stablecoin for WRBTC
        uint256 wrBtcPurchased = _swapStablecoinForWrbtc(netPurchaseAmount);

        if (wrBtcPurchased > 0) {
            s_usersAccumulatedRbtc[buyer] += wrBtcPurchased;
            emit PurchaseRbtc__RbtcBought(
                buyer, address(i_purchasingToken), wrBtcPurchased, scheduleId, netPurchaseAmount
            );
        } else {
            revert PurchaseRbtc__RbtcPurchaseFailed(buyer, address(i_purchasingToken));
        }
    }

    /**
     * @notice batch buy rBTC
     * @param buyers: the users on behalf of which the contract is making the rBTC purchase
     * @param scheduleIds: the schedule ids
     * @param purchaseAmounts: the amounts to spend on rBTC
     * @param purchasePeriods: the periods between purchases
     */
    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts,
        uint256[] memory purchasePeriods
    ) external override onlyDcaManager {
        uint256 numOfPurchases = buyers.length;

        // Calculate net amounts
        (uint256 aggregatedFee, uint256[] memory netStablecoinAmountsToSpend, uint256 totalStablecoinAmountToSpend) =
            _calculateFeeAndNetAmounts(purchaseAmounts);

        // Redeem stablecoin (and repay lending token)
        uint256 stablecoinRedeemed = _batchRedeemStablecoin(buyers, purchaseAmounts, totalStablecoinAmountToSpend + aggregatedFee); // total stablecoin to redeem by repaying yield bearing token in order to spend it to redeem rBTC is totalStablecoinAmountToSpend + aggregatedFee
        totalStablecoinAmountToSpend = stablecoinRedeemed - aggregatedFee;

        // Charge fees
        _transferFee(i_purchasingToken, aggregatedFee);

        // Swap stablecoin for wrBTC
        uint256 wrBtcPurchased = _swapStablecoinForWrbtc(totalStablecoinAmountToSpend);

        if (wrBtcPurchased > 0) {
            for (uint256 i; i < numOfPurchases; ++i) {
                uint256 usersPurchasedWrbtc = wrBtcPurchased * netStablecoinAmountsToSpend[i] / totalStablecoinAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedWrbtc;
                emit PurchaseRbtc__RbtcBought(
                    buyers[i], address(i_purchasingToken), usersPurchasedWrbtc, scheduleIds[i], netStablecoinAmountsToSpend[i]
                );
            }
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(i_purchasingToken), wrBtcPurchased, totalStablecoinAmountToSpend
            );
        } else {
            revert PurchaseRbtc__RbtcBatchPurchaseFailed(address(i_purchasingToken));
        }
    }

    /**
     * @param user: the user to withdraw the rBTC to
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc(address user) external override onlyDcaManager {
        uint256 rbtcBalance = _withdrawRbtcChecksEffects(user);

        // Unwrap rBTC
        i_wrBtcToken.withdraw(rbtcBalance);

        // Transfer RBTC from this contract back to the user
        _withdrawRbtc(user, rbtcBalance);
    }

    /**
     * @param stuckUserContract: the contract to withdraw the rBTC from
     * @param rescueAddress: the address to send the rBTC to if the contract has no fallback
     * @notice the owner can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawStuckRbtc(address stuckUserContract, address rescueAddress) external override onlyOwner {
        uint256 rbtcBalance = _withdrawRbtcChecksEffects(stuckUserContract);
        i_wrBtcToken.withdraw(rbtcBalance);
        _withdrawStuckRbtc(stuckUserContract, rescueAddress, rbtcBalance);
    }

    /**
     * @notice Sets a new swap path.
     *  @param intermediateTokens The array of intermediate token addresses in the path.
     * @param poolFeeRates The array of pool fees for each swap step.
     */
    function setPurchasePath(address[] memory intermediateTokens, uint24[] memory poolFeeRates)
        public
        override
        onlyOwner /* TODO: set another role for access control? */
    {
        if (poolFeeRates.length != intermediateTokens.length + 1) {
            revert PurchaseUniswap__WrongNumberOfTokensOrFeeRates(intermediateTokens.length, poolFeeRates.length);
        }

        bytes memory newPath = abi.encodePacked(address(i_purchasingToken));
        for (uint256 i = 0; i < intermediateTokens.length; i++) {
            newPath = abi.encodePacked(newPath, poolFeeRates[i], intermediateTokens[i]);
        }

        newPath = abi.encodePacked(newPath, poolFeeRates[poolFeeRates.length - 1], address(i_wrBtcToken));

        s_swapPath = newPath;
        emit PurchaseUniswap_NewPathSet(intermediateTokens, poolFeeRates, s_swapPath);
    }

    /**
     * @notice Set the minimum percentage of rBTC that must be received from the swap.
     * @param amountOutMinimumPercent The minimum percentage of rBTC that must be received from the swap.
     */
    function setAmountOutMinimumPercent(uint256 amountOutMinimumPercent) external onlyOwner {
        if (amountOutMinimumPercent > HUNDRED_PERCENT) {
            revert PurchaseUniswap__AmountOutMinimumPercentTooHigh();
        }
        if (amountOutMinimumPercent < s_amountOutMinimumSafetyCheck) {
            revert PurchaseUniswap__AmountOutMinimumPercentTooLow();
        }
        emit PurchaseUniswap_AmountOutMinimumPercentUpdated(s_amountOutMinimumPercent, amountOutMinimumPercent);
        s_amountOutMinimumPercent = amountOutMinimumPercent;
    }

    /**
     * @notice Set the minimum percentage of rBTC that must be received from the swap.
     * @param amountOutMinimumSafetyCheck The minimum percentage of rBTC that must be received from the swap.
     */
    function setAmountOutMinimumSafetyCheck(uint256 amountOutMinimumSafetyCheck) external onlyOwner {
        if (amountOutMinimumSafetyCheck > HUNDRED_PERCENT) {
            revert PurchaseUniswap__AmountOutMinimumSafetyCheckTooHigh();
        }
        emit PurchaseUniswap_AmountOutMinimumSafetyCheckUpdated(s_amountOutMinimumSafetyCheck, amountOutMinimumSafetyCheck);
        s_amountOutMinimumSafetyCheck = amountOutMinimumSafetyCheck;
    }

    /**
     * @notice Get the minimum percentage of rBTC that must be received from the swap.
     * @return The minimum percentage of rBTC that must be received from the swap.
     */     
    function getAmountOutMinimumPercent() external view returns (uint256) {
        return s_amountOutMinimumPercent;
    }

    /**
     * @notice Get the minimum percentage of rBTC that must be received from the swap.
     * @return The minimum percentage of rBTC that must be received from the swap.
     */
    function getAmountOutMinimumSafetyCheck() external view returns (uint256) {
        return s_amountOutMinimumSafetyCheck;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param stablecoinAmountToSpend the amount of stablecoin to swap for rBTC
     * @return amountOut the amount of rBTC received
     */
    function _swapStablecoinForWrbtc(uint256 stablecoinAmountToSpend) internal returns (uint256 amountOut) {
        // Approve the router to spend stablecoin.
        TransferHelper.safeApprove(address(i_purchasingToken), address(i_swapRouter02), stablecoinAmountToSpend);

        // Set up the swap parameters
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: s_swapPath,
            recipient: address(this),
            amountIn: stablecoinAmountToSpend,
            amountOutMinimum: _getAmountOutMinimum(stablecoinAmountToSpend)
        });

        amountOut = i_swapRouter02.exactInput(params);
    }

    function _getAmountOutMinimum(uint256 stablecoinAmountToSpend) internal view returns (uint256 minimumRbtcAmount) {
        minimumRbtcAmount = (stablecoinAmountToSpend * s_amountOutMinimumPercent) / i_MocOracle.getPrice();
    }

}
