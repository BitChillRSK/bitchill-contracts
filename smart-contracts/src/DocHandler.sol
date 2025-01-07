// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {IDocHandler} from "./interfaces/IDocHandler.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DocHandler
 * @dev Implementation of the IDocHandler interface.
 * @notice This abstract contract contains the DOC related functions that are common regardless of the method used to swap DOC for rBTC
 */
abstract contract DocHandler is TokenHandler, IDocHandler {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IERC20 public immutable i_docToken;
    IkDocToken public immutable i_kDocToken;
    mapping(address user => uint256 balance) internal s_kDocBalances;
    uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

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
        address docTokenAddress,
        address kDocTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        bool yieldsInterest
    )
        Ownable()
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings, yieldsInterest)
    {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkDocToken(kDocTokenAddress);
    }

    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositToken(address user, uint256 depositAmount)
        public
        override(TokenHandler, ITokenHandler)
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
        override(TokenHandler, ITokenHandler)
        onlyDcaManager
    {
        uint256 docInTropykus = _kdocToDoc(s_kDocBalances[user], i_kDocToken.exchangeRateStored());
        if (docInTropykus < withdrawalAmount) {
            revert DocHandler__WithdrawalAmountExceedsKdocBalance(user, withdrawalAmount, docInTropykus);
        }
        _redeemDoc(user, withdrawalAmount);
        super.withdrawToken(user, withdrawalAmount);
    }

    function getUsersLendingTokenBalance(address user) external view override returns (uint256) {
        return s_kDocBalances[user];
    }

    function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        uint256 totalDocInLending = _kdocToDoc(s_kDocBalances[user], exchangeRate);
        uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
        uint256 kDocToRepay = docInterestAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
        // _redeemDoc(user, docInterestAmount);
        s_kDocBalances[user] -= kDocToRepay;
        uint256 result = i_kDocToken.redeemUnderlying(docInterestAmount);
        if (result == 0) emit DocHandler__SuccessfulDocRedemption(user, docInterestAmount, kDocToRepay);
        else revert DocHandler__RedeemUnderlyingFailed(result);
        i_docToken.safeTransfer(user, docInterestAmount);
        emit DocHandler__SuccessfulInterestWithdrawal(user, docInterestAmount, kDocToRepay);

        // bool transferSuccess = i_docToken.safeTransfer(user, docInterestAmount);
        // if (!transferSuccess) revert DocHandler__InterestWithdrawalFailed(user, docInterestAmount);
    }

    function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
        external
        view
        override
        onlyDcaManager
        returns (uint256 docInterestAmount)
    {
        uint256 totalDocInLending = _kdocToDoc(s_kDocBalances[user], i_kDocToken.exchangeRateStored());
        docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods)
        internal
        view
        returns (uint256, uint256[] memory, uint256)
    {
        uint256 fee;
        uint256 aggregatedFee;
        uint256[] memory netDocAmountsToSpend = new uint256[](purchaseAmounts.length);
        uint256 totalDocAmountToSpend;
        for (uint256 i; i < purchaseAmounts.length; ++i) {
            fee = _calculateFee(purchaseAmounts[i], purchasePeriods[i]);
            aggregatedFee += fee;
            netDocAmountsToSpend[i] = purchaseAmounts[i] - fee;
            totalDocAmountToSpend += netDocAmountsToSpend[i];
        }
        return (aggregatedFee, netDocAmountsToSpend, totalDocAmountToSpend);
    }

    function _redeemDoc(address user, uint256 docToRedeem) internal {
        // (, uint256 underlyingAmount,,) = i_kDocToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        // if (docToRedeem > underlyingAmount) {
        //     revert DocHandler__DocRedeemAmountExceedsBalance(docToRedeem, underlyingAmount);
        // } // NO SÉ SI ESTO TIENE MUCHO SENTIDO
        uint256 exchangeRate = i_kDocToken.exchangeRateStored(); // esto devuelve la tasa de cambio
        uint256 usersKdocBalance = s_kDocBalances[user];
        uint256 kDocToRepay = _docToKdoc(docToRedeem, exchangeRate);
        if (kDocToRepay > usersKdocBalance) {
            revert DocHandler__KdocToRepayExceedsUsersBalance(user, docToRedeem * exchangeRate, usersKdocBalance);
        }
        s_kDocBalances[user] -= kDocToRepay;
        uint256 result = i_kDocToken.redeemUnderlying(docToRedeem);
        if (result == 0) emit DocHandler__SuccessfulDocRedemption(user, docToRedeem, kDocToRepay);
        else revert DocHandler__RedeemUnderlyingFailed(result);
    }

    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocToRedeem)
        internal
    {
        (, uint256 underlyingAmount,,) = i_kDocToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        if (totalDocToRedeem > underlyingAmount) {
            revert DocHandler__DocRedeemAmountExceedsBalance(totalDocToRedeem, underlyingAmount);
        }
        uint256 totalKdocToRepay = _docToKdoc(totalDocToRedeem, i_kDocToken.exchangeRateStored());

        // TODO: delete this commented code after further testing (we realised this could be done following CEI)
        // @notice here we don't follow CEI, but this function is protected by an onlyDcaManager modifier
        // uint256 kDocBalancePrev = i_kDocToken.balanceOf(address(this));
        // i_kDocToken.redeemUnderlying(totalDocToRedeem);
        // uint256 kDocBalancePost = i_kDocToken.balanceOf(address(this));

        // if (kDocToRepay != kDocBalancePrev - kDocBalancePost) revert("PERO QUE COJONES");

        // if (kDocBalancePrev - kDocBalancePost > 0) {
        //     uint256 totalKdocRepayed = kDocBalancePrev - kDocBalancePost;
        //     uint256 numOfPurchases = users.length;
        //     for (uint256 i; i < numOfPurchases; ++i) {
        //         // @notice the amount of kDOC each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
        //         uint256 usersRepayedKdoc = totalKdocRepayed * purchaseAmounts[i] / totalDocToRedeem;
        //         s_kDocBalances[users[i]] -= usersRepayedKdoc;
        //         emit DocHandler__DocRedeemedKdocRepayed(users[i], purchaseAmounts[i], usersRepayedKdoc);
        //     }
        //     emit DocHandler__SuccessfulBatchDocRedemption(totalDocToRedeem, totalKdocRepayed);
        // } else {
        //     revert DocHandler__BatchRedeemDocFailed();
        // }

        uint256 numOfPurchases = users.length;
        for (uint256 i; i < numOfPurchases; ++i) {
            // @notice the amount of kDOC each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
            uint256 usersRepayedKdoc = totalKdocToRepay * purchaseAmounts[i] / totalDocToRedeem;
            s_kDocBalances[users[i]] -= usersRepayedKdoc;
            emit DocHandler__DocRedeemedKdocRepayed(users[i], purchaseAmounts[i], usersRepayedKdoc);
        }
        uint256 result = i_kDocToken.redeemUnderlying(totalDocToRedeem);
        if (result == 0) emit DocHandler__SuccessfulBatchDocRedemption(totalDocToRedeem, totalKdocToRepay);
        else revert DocHandler__BatchRedeemDocFailed();
    }

    function _docToKdoc(uint256 docAmount, uint256 exchangeRate) internal pure returns (uint256 kDocAmount) {
        kDocAmount = docAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
    }

    function _kdocToDoc(uint256 kDocAmount, uint256 exchangeRate) internal pure returns (uint256 docAmount) {
        docAmount = kDocAmount * exchangeRate / EXCHANGE_RATE_DECIMALS;
    }
}
