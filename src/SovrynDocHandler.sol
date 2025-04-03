// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {ISovrynDocLending} from "./interfaces/ISovrynDocLending.sol";
import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenLending} from "src/TokenLending.sol";
import {Test, console} from "forge-std/Test.sol";
/**
 * @title SovrynDocHandler
 * @notice This abstract contract contains the DOC related functions that are common regardless of the method used to swap DOC for rBTC
 */

abstract contract SovrynDocHandler is TokenHandler, TokenLending, ISovrynDocLending {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    // IERC20 public immutable i_docToken;
    IiSusdToken public immutable i_iSusdToken;
    mapping(address user => uint256 balance) internal s_iSusdBalances;
    uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param iSusdTokenAddress the address of Sovryn' iSusd token contract
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
        FeeSettings memory feeSettings
    )
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings)
        TokenLending(EXCHANGE_RATE_DECIMALS)
    {
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
        if (i_stableToken.allowance(address(this), address(i_iSusdToken)) < depositAmount) {
            bool approvalSuccess = i_stableToken.approve(address(i_iSusdToken), depositAmount);
            if (!approvalSuccess) revert TokenLending__LendingTokenApprovalFailed(user, depositAmount);
        }
        uint256 previSusdBalance = i_iSusdToken.balanceOf(address(this));
        i_iSusdToken.mint(address(this), depositAmount);
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
        uint256 exchangeRate = i_iSusdToken.tokenPrice();
        uint256 docInSovryn = _lendingTokenToDoc(s_iSusdBalances[user], exchangeRate);

        if (docInSovryn < withdrawalAmount) {
            emit TokenLending__WithdrawalAmountAdjusted(user, withdrawalAmount, docInSovryn);
            withdrawalAmount = docInSovryn;
        }

        withdrawalAmount = _redeemDoc(user, withdrawalAmount, exchangeRate);
        super.withdrawToken(user, withdrawalAmount);
    }

    function getUsersLendingTokenBalance(address user) external view override returns (uint256) {
        return s_iSusdBalances[user];
    }

    function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_iSusdToken.tokenPrice();
        uint256 totalDocInLending = _lendingTokenToDoc(s_iSusdBalances[user], exchangeRate);
        if (totalDocInLending <= docLockedInDcaSchedules) {
            return; // No interest to withdraw
        }
        uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
        // uint256 iSusdToRepay = _docToLendingToken(docInterestAmount, exchangeRate);
        _redeemDoc(user, docInterestAmount, exchangeRate, user);
        // s_iSusdBalances[user] -= iSusdToRepay;
        // uint256 docRedeemed = i_iSusdToken.burn(user, iSusdToRepay);
        // if (docRedeemed == 0) revert SovrynDocLending__RedeemUnderlyingFailed();
        // emit TokenLending__SuccessfulInterestWithdrawal(user, docInterestAmount, iSusdToRepay);

        // bool transferSuccess = i_docToken.safeTransfer(user, docInterestAmount);
        // if (!transferSuccess) revert TokenLending__InterestWithdrawalFailed(user, docInterestAmount);
    }

    function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
        external
        view
        override
        onlyDcaManager
        returns (uint256 docInterestAmount)
    {
        uint256 totalDocInLending = _lendingTokenToDoc(s_iSusdBalances[user], i_iSusdToken.tokenPrice());
        docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _redeemDoc(address user, uint256 docToRedeem) internal virtual returns (uint256) {
        // For buyRbtc(), we want the DOC to come to the contract
        return _redeemDoc(user, docToRedeem, i_iSusdToken.tokenPrice(), address(this));
    }

    function _redeemDoc(address user, uint256 docToRedeem, uint256 exchangeRate) internal virtual returns (uint256) {
        return _redeemDoc(user, docToRedeem, exchangeRate, address(this));
    }

    function _redeemDoc(address user, uint256 docToRedeem, uint256 exchangeRate, address docRecipient)
        internal
        virtual
        returns (uint256)
    {
        uint256 usersIsusdBalance = s_iSusdBalances[user];
        uint256 iSusdToRepay = _docToLendingToken(docToRedeem, exchangeRate);
        console.log("usersIsusdBalance:", usersIsusdBalance);
        console.log("iSusd to repay:", iSusdToRepay);
        if (iSusdToRepay > usersIsusdBalance) {
            emit TokenLending__AmountToRepayAdjusted(user, iSusdToRepay, usersIsusdBalance);
            iSusdToRepay = usersIsusdBalance;
        }
        console.log("iSusd to repay:", iSusdToRepay);
        s_iSusdBalances[user] -= iSusdToRepay;
        uint256 docRedeemed = i_iSusdToken.burn(docRecipient, iSusdToRepay);
        console.log("DOC redeemed:", docRedeemed);
        // if (docRedeemed < docToRedeem) revert SovrynDocLending__RedeemUnderlyingFailed();
        // @notice If a withdrawal is done right after the funds have been deposited, 1 wei less is obtained, so this check made the tx revert
        // From now on, we'll trust that Sovryn returns the correct amount of DOC
        if (docRedeemed == 0) revert SovrynDocLending__RedeemUnderlyingFailed();
        emit TokenLending__SuccessfulDocRedemption(user, docRedeemed, iSusdToRepay);
        return docRedeemed;
    }

    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocToRedeem)
        internal
        virtual
        returns (uint256)
    {
        uint256 underlyingAmount =
            i_iSusdToken.assetBalanceOf(address(this)) + uint256(i_iSusdToken.profitOf(address(this))); // TODO: check if int->uint conversion is OK
        if (totalDocToRedeem > underlyingAmount) {
            revert TokenLending__DocRedeemAmountExceedsBalance(totalDocToRedeem, underlyingAmount);
        }
        uint256 totaliSusdToRepay = _docToLendingToken(totalDocToRedeem, i_iSusdToken.tokenPrice());

        uint256 numOfPurchases = users.length;
        for (uint256 i; i < numOfPurchases; ++i) {
            // @notice the amount of iSusd each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
            uint256 usersRepayediSusd = totaliSusdToRepay * purchaseAmounts[i] / totalDocToRedeem;
            s_iSusdBalances[users[i]] -= usersRepayediSusd;
            emit TokenLending__DocRedeemedLendingTokenRepayed(users[i], purchaseAmounts[i], usersRepayediSusd);
        }
        uint256 docRedeemed = i_iSusdToken.burn(address(this), totaliSusdToRepay);
        if (docRedeemed > 0) emit TokenLending__SuccessfulBatchDocRedemption(totalDocToRedeem, totaliSusdToRepay);
        else revert SovrynDocLending__RedeemUnderlyingFailed();
        console.log("DOC redeemed (SovrynDocHandler.sol)", docRedeemed);
        return docRedeemed;
    }
}
