// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {FeeHandler} from "./FeeHandler.sol";
import {IPurchaseRbtc} from "src/interfaces/IPurchaseRbtc.sol";
import {IWRBTC} from "./interfaces/IWRBTC.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {ICoinPairPrice} from "./interfaces/ICoinPairPrice.sol";
import {IUniswapPurchase} from "./interfaces/IUniswapPurchase.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title PurchaseMoc
 * @notice This contract handles swaps of DOC for rBTC directly redeeming the latter from the MoC contract
 */
abstract contract PurchaseUniswap is
    FeeHandler,
    DcaManagerAccessControl, /*IDocHandlerMoc,*/
    IPurchaseRbtc,
    IUniswapPurchase
{
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IERC20 public immutable i_purchasingToken;
    IWRBTC public immutable i_wrBtcToken;
    mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;
    mapping(address user => uint256 balance) private s_WrbtcBalances;
    ISwapRouter02 public immutable i_swapRouter02;
    ICoinPairPrice public immutable i_MocOracle;
    uint256 constant PRECISION = 1e18;
    bytes public s_swapPath;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param stableTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     */
    constructor(
        address stableTokenAddress, // TODO: modify this to passing the interface
        UniswapSettings memory uniswapSettings
    ) 
    // FeeSettings memory feeSettings
    /*FeeHandler(feeCollector, feeSettings) DcaManagerAccessControl(dcaManagerAddress)*/
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
        // Redeem DOC (repaying kDOC)
        purchaseAmount = _redeemDoc(buyer, purchaseAmount);

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(i_purchasingToken, fee);

        // Swap DOC for WRBTC
        uint256 wrBtcPurchased = _swapDocForWrbtc(netPurchaseAmount);

        if (wrBtcPurchased > 0) {
            s_usersAccumulatedRbtc[buyer] += wrBtcPurchased;
            emit PurchaseRbtc__RbtcBought(
                buyer, address(i_purchasingToken), wrBtcPurchased, scheduleId, netPurchaseAmount
            );
        } else {
            revert PurchaseRbtc__RbtcPurchaseFailed(buyer, address(i_purchasingToken));
        }
    }

    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts,
        uint256[] memory purchasePeriods
    ) external override onlyDcaManager {
        uint256 numOfPurchases = buyers.length;

        // Calculate net amounts
        (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 totalDocAmountToSpend) =
            _calculateFeeAndNetAmounts(purchaseAmounts, purchasePeriods);

        console.log(
            "DOC balance of handler before redeeming DOC",
            i_purchasingToken.balanceOf(0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496)
        );

        // Redeem DOC (and repay lending token)
        uint256 docRedeemed = _batchRedeemDoc(buyers, purchaseAmounts, totalDocAmountToSpend + aggregatedFee); // total DOC to redeem by repaying kDOC in order to spend it to redeem rBTC is totalDocAmountToSpend + aggregatedFee
        totalDocAmountToSpend = docRedeemed - aggregatedFee;

        console.log("DOC redeemed (PurchaseUniswap.sol)", docRedeemed);
        console.log(
            "DOC balance of handler after redeeming DOC",
            i_purchasingToken.balanceOf(0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496)
        );

        // Charge fees
        _transferFee(i_purchasingToken, aggregatedFee);

        console.log(
            "DOC balance of handler after transferring fee",
            i_purchasingToken.balanceOf(0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496)
        );

        // Swap DOC for wrBTC
        uint256 wrBtcPurchased = _swapDocForWrbtc(totalDocAmountToSpend);

        if (wrBtcPurchased > 0) {
            for (uint256 i; i < numOfPurchases; ++i) {
                uint256 usersPurchasedWrbtc = wrBtcPurchased * netDocAmountsToSpend[i] / totalDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedWrbtc;
                emit PurchaseRbtc__RbtcBought(
                    buyers[i], address(i_purchasingToken), usersPurchasedWrbtc, scheduleIds[i], netDocAmountsToSpend[i]
                );
            }
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(i_purchasingToken), wrBtcPurchased, totalDocAmountToSpend
            );
        } else {
            revert PurchaseRbtc__RbtcBatchPurchaseFailed(address(i_purchasingToken));
        }
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     * @notice anyone can pay for the transaction to have the rBTC sent to the user
     */
    function withdrawAccumulatedRbtc(address user) external {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) revert PurchaseRbtc__NoAccumulatedRbtcToWithdraw();

        s_usersAccumulatedRbtc[user] = 0;

        // Unwrap rBTC
        i_wrBtcToken.withdraw(rbtcBalance);

        // Transfer RBTC from this contract back to the user
        (bool sent,) = user.call{value: rbtcBalance}("");
        if (!sent) revert PurchaseRbtc__rBtcWithdrawalFailed();
        emit PurchaseRbtc__rBtcWithdrawn(user, rbtcBalance);
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
            revert DexSwaps__WrongNumberOfTokensOrFeeRates(intermediateTokens.length, poolFeeRates.length);
        }

        bytes memory newPath = abi.encodePacked(address(i_purchasingToken));
        for (uint256 i = 0; i < intermediateTokens.length; i++) {
            newPath = abi.encodePacked(newPath, poolFeeRates[i], intermediateTokens[i]);
        }

        newPath = abi.encodePacked(newPath, poolFeeRates[poolFeeRates.length - 1], address(i_wrBtcToken));

        s_swapPath = newPath;
        emit DexSwaps_NewPathSet(intermediateTokens, poolFeeRates, s_swapPath);
    }

    function getAccumulatedRbtcBalance() external view override returns (uint256) {
        return s_usersAccumulatedRbtc[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param docAmountToSpend the amount of DOC to swap for BTC
     */
    function _swapDocForWrbtc(uint256 docAmountToSpend) internal returns (uint256 amountOut) {
        // Approve the router to spend DOC.
        TransferHelper.safeApprove(address(i_purchasingToken), address(i_swapRouter02), docAmountToSpend);

        // Set up the swap parameters
        // ISwapRouter02.ExactInputParams memory params = ISwapRouter02.ExactInputParams({
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: s_swapPath,
            recipient: address(this),
            amountIn: docAmountToSpend,
            amountOutMinimum: _getAmountOutMinimum(docAmountToSpend)
        });

        amountOut = i_swapRouter02.exactInput(params);
        // amountOut = IV3SwapRouter(address(i_swapRouter02)).exactInput(params);
    }

    function _getAmountOutMinimum(uint256 docAmountToSpend) internal view returns (uint256 minimumRbtcAmount) {
        minimumRbtcAmount = 0; // (docAmountToSpend * PRECISION * 920) / (1000 * i_MocOracle.getPrice()); // TODO: DOUBLE-CHECK MATH!!!
    }

    // Define abstract functions to be implemented by child contracts
    function _redeemDoc(address buyer, uint256 amount) internal virtual returns (uint256);

    function _batchRedeemDoc(address[] memory buyers, uint256[] memory purchaseAmounts, uint256 totalDocAmountToSpend)
        internal
        virtual
        returns (uint256);

    // function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods)
    //     internal
    //     view
    //     virtual
    //     returns (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 totalDocAmountToSpend);
}
