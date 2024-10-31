// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {IDocHandler} from "./interfaces/IDocHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {DocHandler} from "./DocHandler.sol";
import {IDocHandlerDex} from "./interfaces/IDocHandlerDex.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IWRBTC} from "./interfaces/IWRBTC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
// import {TransferHelper} from "./libraries/TransferHelper.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
// import {ISwapRouter02} from "./interfaces/ISwapRouter02.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
// import {IV3SwapRouter} from "./interfaces/IV3SwapRouter.sol";
import {ICoinPairPrice} from "./interfaces/ICoinPairPrice.sol";

/**
 * @title DocHandlerDex
 * @dev Implementation of the IDocHandlerDex interface.
 */
contract DocHandlerDex is DocHandler, IDocHandlerDex {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IWRBTC public immutable i_wrBtcToken;
    mapping(address user => uint256 balance) private s_WrbtcBalances;
    ISwapRouter02 public immutable i_swapRouter02;
    ICoinPairPrice public immutable i_MocOracle;
    uint256 constant PRECISION = 1e18;
    bytes public s_swapPath;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param kDocTokenAddress the address of Tropykus' kDOC token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress, // TODO: modify this to passing the interface
        address kDocTokenAddress, // TODO: modify this to passing the interface
        UniswapSettings memory uniswapSettings,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        bool yieldsInterest
    )
        DocHandler(
            dcaManagerAddress,
            docTokenAddress,
            kDocTokenAddress,
            minPurchaseAmount,
            feeCollector,
            feeSettings,
            yieldsInterest
        )
    {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkDocToken(kDocTokenAddress);
        i_swapRouter02 = uniswapSettings.swapRouter02;
        i_wrBtcToken = uniswapSettings.wrBtcToken;
        i_MocOracle = uniswapSettings.mocOracle;
        setPurchasePath(uniswapSettings.swapIntermediateTokens, uniswapSettings.swapPoolFeeRates);
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositToken(address user, uint256 depositAmount)
        public
        override(DocHandler, ITokenHandler)
        onlyDcaManager
    {
        super.depositToken(user, depositAmount);
        if (i_docToken.allowance(address(this), address(i_kDocToken)) < depositAmount) {
            bool approvalSuccess = i_docToken.approve(address(i_kDocToken), depositAmount);
            if (!approvalSuccess) revert DocHandler__kDocApprovalFailed(user, depositAmount);
        }
        uint256 prevKdocBalance = i_kDocToken.balanceOf(address(this));
        i_kDocToken.mint(depositAmount);
        uint256 postKdocBalance = i_kDocToken.balanceOf(address(this));
        s_kDocBalances[user] += postKdocBalance - prevKdocBalance;
    }

    /**
     * @notice withdraw the token amount sending it back to the user's address
     * @param user: the address of the user making the withdrawal
     * @param withdrawalAmount: the amount to withdraw
     */
    function withdrawToken(address user, uint256 withdrawalAmount)
        public
        override(DocHandler, ITokenHandler)
        onlyDcaManager
    {
        uint256 docInTropykus = s_kDocBalances[user] * i_kDocToken.exchangeRateStored() / EXCHANGE_RATE_DECIMALS;
        if (docInTropykus < withdrawalAmount) {
            revert DocHandler__WithdrawalAmountExceedsKdocBalance(user, withdrawalAmount, docInTropykus);
        }
        _redeemDoc(user, withdrawalAmount);
        super.withdrawToken(user, withdrawalAmount);
    }

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
        _redeemDoc(buyer, purchaseAmount);

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(fee);

        // Swap DOC for WRBTC
        uint256 wrBtcPurchased = _swapDocForWrbtc(netPurchaseAmount);

        if (wrBtcPurchased > 0) {
            s_usersAccumulatedRbtc[buyer] += wrBtcPurchased;
            emit TokenHandler__RbtcBought(buyer, address(i_docToken), wrBtcPurchased, scheduleId, netPurchaseAmount);
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docToken));
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

        // Redeem DOC (and repay kDOC)
        _batchRedeemDoc(buyers, purchaseAmounts, totalDocAmountToSpend + aggregatedFee); // total DOC to redeem by repaying kDOC in order to spend it to redeem rBTC is totalDocAmountToSpend + aggregatedFee

        // Charge fees
        _transferFee(aggregatedFee);

        // Swap DOC for wrBTC
        uint256 wrBtcPurchased = _swapDocForWrbtc(totalDocAmountToSpend);

        if (wrBtcPurchased > 0) {
            for (uint256 i; i < numOfPurchases; ++i) {
                uint256 usersPurchasedWrbtc = wrBtcPurchased * netDocAmountsToSpend[i] / totalDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedWrbtc;
                emit TokenHandler__RbtcBought(
                    buyers[i], address(i_docToken), usersPurchasedWrbtc, scheduleIds[i], netDocAmountsToSpend[i]
                );
            }
            emit TokenHandler__SuccessfulRbtcBatchPurchase(address(i_docToken), wrBtcPurchased, totalDocAmountToSpend);
        } else {
            revert TokenHandler__RbtcBatchPurchaseFailed(address(i_docToken));
        }
    }

    function getUsersKdocBalance(address user) external view override(DocHandler, IDocHandler) returns (uint256) {
        return s_kDocBalances[user];
    }

    function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
        external
        view
        override(DocHandler, ITokenHandler)
        onlyDcaManager
        returns (uint256 docInterestAmount)
    {
        uint256 totalDocInLending = s_kDocBalances[user] * EXCHANGE_RATE_DECIMALS / i_kDocToken.exchangeRateStored();
        docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     * @notice anyone can pay for the transaction to have the rBTC sent to the user
     */
    function withdrawAccumulatedRbtc(address user) external override(TokenHandler, ITokenHandler) {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) revert TokenHandler__NoAccumulatedRbtcToWithdraw();

        s_usersAccumulatedRbtc[user] = 0;

        // Unwrap rBTC
        i_wrBtcToken.withdraw(rbtcBalance);

        // Transfer RBTC from this contract back to the user
        (bool sent,) = user.call{value: rbtcBalance}("");
        if (!sent) revert TokenHandler__rBtcWithdrawalFailed();
        emit TokenHandler__rBtcWithdrawn(user, rbtcBalance);
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

        bytes memory newPath = abi.encodePacked(address(i_docToken));
        for (uint256 i = 0; i < intermediateTokens.length; i++) {
            newPath = abi.encodePacked(newPath, poolFeeRates[i], intermediateTokens[i]);
        }

        newPath = abi.encodePacked(newPath, poolFeeRates[poolFeeRates.length - 1], address(i_wrBtcToken));

        s_swapPath = newPath;
        emit DexSwaps_NewPathSet(intermediateTokens, poolFeeRates, s_swapPath);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @param docAmountToSpend the amount of DOC to swap for BTC
     */
    function _swapDocForWrbtc(uint256 docAmountToSpend) internal returns (uint256 amountOut) {
        // Approve the router to spend DOC.
        TransferHelper.safeApprove(address(i_docToken), address(i_swapRouter02), docAmountToSpend);

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
        minimumRbtcAmount = (docAmountToSpend * PRECISION * 99) / (100 * i_MocOracle.getPrice()); // TODO: DOUBLE-CHECK MATH!!!
    }
}
