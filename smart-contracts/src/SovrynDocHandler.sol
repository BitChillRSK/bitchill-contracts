// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {ISovrynDocHandler} from "./interfaces/ISovrynDocHandler.sol";
import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SovrynDocHandler
 * @dev Implementation of the ISovrynDocHandler interface.
 * @notice This abstract contract contains the DOC related functions that are common regardless of the method used to swap DOC for rBTC
 */
abstract contract SovrynDocHandler is TokenHandler, ISovrynDocHandler {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IERC20 public immutable i_docToken;
    IiSusdToken public immutable i_iSusdToken;
    mapping(address user => uint256 balance) internal s_iSusdBalances;
    uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param iSusdTokenAddress the address of Tropykus' iSusd token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address iSusdTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        bool yieldsInterest
    )
        Ownable()
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings, yieldsInterest)
    {
        i_docToken = IERC20(docTokenAddress);
        i_iSusdToken = IiSusdToken(iSusdTokenAddress);
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
        if (i_docToken.allowance(address(this), address(i_iSusdToken)) < depositAmount) {
            bool approvalSuccess = i_docToken.approve(address(i_iSusdToken), depositAmount);
            if (!approvalSuccess) revert DocHandler__iSusdApprovalFailed(user, depositAmount);
        }
        uint256 previSusdBalance = i_iSusdToken.balanceOf(address(this));
        i_iSusdToken.mint(depositAmount);
        uint256 postiSusdBalance = i_iSusdToken.balanceOf(address(this));
        s_iSusdBalances[user] += postiSusdBalance - previSusdBalance;
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
        uint256 docInTropykus = _iSusdToDoc(s_iSusdBalances[user], i_iSusdToken.exchangeRateStored());
        if (docInTropykus < withdrawalAmount) {
            revert DocHandler__WithdrawalAmountExceedsiSusdBalance(user, withdrawalAmount, docInTropykus);
        }
        _redeemDoc(user, withdrawalAmount);
        super.withdrawToken(user, withdrawalAmount);
    }

    function getUsersiSusdBalance(address user) external view override returns (uint256) {
        return s_iSusdBalances[user];
    }

    function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_iSusdToken.exchangeRateStored();
        uint256 totalDocInLending = _iSusdToDoc(s_iSusdBalances[user], exchangeRate);
        uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
        uint256 iSusdToRepay = docInterestAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
        // _redeemDoc(user, docInterestAmount);
        s_iSusdBalances[user] -= iSusdToRepay;
        uint256 result = i_iSusdToken.redeemUnderlying(docInterestAmount);
        if (result == 0) emit DocHandler__SuccessfulDocRedemption(user, docInterestAmount, iSusdToRepay);
        else revert DocHandler__RedeemUnderlyingFailed(result);
        i_docToken.safeTransfer(user, docInterestAmount);
        emit DocHandler__SuccessfulInterestWithdrawal(user, docInterestAmount, iSusdToRepay);

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
        uint256 totalDocInLending = _iSusdToDoc(s_iSusdBalances[user], i_iSusdToken.exchangeRateStored());
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
        // (, uint256 underlyingAmount,,) = i_iSusdToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        // if (docToRedeem > underlyingAmount) {
        //     revert DocHandler__DocRedeemAmountExceedsBalance(docToRedeem, underlyingAmount);
        // } // NO SÉ SI ESTO TIENE MUCHO SENTIDO
        uint256 exchangeRate = i_iSusdToken.exchangeRateStored(); // esto devuelve la tasa de cambio
        uint256 usersiSusdBalance = s_iSusdBalances[user];
        uint256 iSusdToRepay = _docToiSusd(docToRedeem, exchangeRate);
        if (iSusdToRepay > usersiSusdBalance) {
            revert DocHandler__iSusdToRepayExceedsUsersBalance(user, docToRedeem * exchangeRate, usersiSusdBalance);
        }
        s_iSusdBalances[user] -= iSusdToRepay;
        uint256 result = i_iSusdToken.redeemUnderlying(docToRedeem);
        if (result == 0) emit DocHandler__SuccessfulDocRedemption(user, docToRedeem, iSusdToRepay);
        else revert DocHandler__RedeemUnderlyingFailed(result);
    }

    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocToRedeem)
        internal
    {
        (, uint256 underlyingAmount,,) = i_iSusdToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        if (totalDocToRedeem > underlyingAmount) {
            revert DocHandler__DocRedeemAmountExceedsBalance(totalDocToRedeem, underlyingAmount);
        }
        uint256 totaliSusdToRepay = _docToiSusd(totalDocToRedeem, i_iSusdToken.exchangeRateStored());

        // TODO: delete this commented code after further testing (we realised this could be done following CEI)
        // @notice here we don't follow CEI, but this function is protected by an onlyDcaManager modifier
        // uint256 iSusdBalancePrev = i_iSusdToken.balanceOf(address(this));
        // i_iSusdToken.redeemUnderlying(totalDocToRedeem);
        // uint256 iSusdBalancePost = i_iSusdToken.balanceOf(address(this));

        // if (iSusdToRepay != iSusdBalancePrev - iSusdBalancePost) revert("PERO QUE COJONES");

        // if (iSusdBalancePrev - iSusdBalancePost > 0) {
        //     uint256 totaliSusdRepayed = iSusdBalancePrev - iSusdBalancePost;
        //     uint256 numOfPurchases = users.length;
        //     for (uint256 i; i < numOfPurchases; ++i) {
        //         // @notice the amount of iSusd each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
        //         uint256 usersRepayediSusd = totaliSusdRepayed * purchaseAmounts[i] / totalDocToRedeem;
        //         s_iSusdBalances[users[i]] -= usersRepayediSusd;
        //         emit DocHandler__DocRedeemediSusdRepayed(users[i], purchaseAmounts[i], usersRepayediSusd);
        //     }
        //     emit DocHandler__SuccessfulBatchDocRedemption(totalDocToRedeem, totaliSusdRepayed);
        // } else {
        //     revert DocHandler__BatchRedeemDocFailed();
        // }

        uint256 numOfPurchases = users.length;
        for (uint256 i; i < numOfPurchases; ++i) {
            // @notice the amount of iSusd each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
            uint256 usersRepayediSusd = totaliSusdToRepay * purchaseAmounts[i] / totalDocToRedeem;
            s_iSusdBalances[users[i]] -= usersRepayediSusd;
            emit DocHandler__DocRedeemediSusdRepayed(users[i], purchaseAmounts[i], usersRepayediSusd);
        }
        uint256 result = i_iSusdToken.redeemUnderlying(totalDocToRedeem);
        if (result == 0) emit DocHandler__SuccessfulBatchDocRedemption(totalDocToRedeem, totaliSusdToRepay);
        else revert DocHandler__BatchRedeemDocFailed();
    }

    function _docToiSusd(uint256 docAmount, uint256 exchangeRate) internal pure returns (uint256 iSusdAmount) {
        iSusdAmount = docAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
    }

    function _iSusdToDoc(uint256 iSusdAmount, uint256 exchangeRate) internal pure returns (uint256 docAmount) {
        docAmount = iSusdAmount * exchangeRate / EXCHANGE_RATE_DECIMALS;
    }
}
