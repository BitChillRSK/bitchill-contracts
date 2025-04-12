// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {DcaManagerAccessControl} from "src/DcaManagerAccessControl.sol";
import {ITropykusDocLending} from "./interfaces/ITropykusDocLending.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TokenLending} from "src/TokenLending.sol";

/**
 * @title TropykusDocHandler
 * @notice This abstract contract contains the DOC related functions that are common regardless of the method used to swap DOC for rBTC
 */
abstract contract TropykusDocHandler is TokenHandler, TokenLending, ITropykusDocLending {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
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
        FeeSettings memory feeSettings
    )
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings)
        TokenLending(EXCHANGE_RATE_DECIMALS)
    {
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
        if (i_stableToken.allowance(address(this), address(i_kDocToken)) < depositAmount) {
            bool approvalSuccess = i_stableToken.approve(address(i_kDocToken), depositAmount);
            if (!approvalSuccess) revert TokenLending__LendingTokenApprovalFailed(user, depositAmount);
        }
        uint256 prevKdocBalance = i_kDocToken.balanceOf(address(this));
        if(i_kDocToken.mint(depositAmount) != 0) revert TokenLending__LendingProtocolDepositFailed();
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
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        uint256 docInTropykus = _lendingTokenToDoc(s_kDocBalances[user], exchangeRate);
        if (docInTropykus < withdrawalAmount) {
            emit TokenLending__WithdrawalAmountAdjusted(user, withdrawalAmount, docInTropykus);
            withdrawalAmount = docInTropykus;
        }
        _redeemDoc(user, withdrawalAmount, exchangeRate);
        super.withdrawToken(user, withdrawalAmount);
    }

    /**
     * @notice get the users lending token balance
     * @param user: the address of the user
     * @return the users lending token balance
     */
    function getUsersLendingTokenBalance(address user) external view override returns (uint256) {
        return s_kDocBalances[user];
    }

    /**
     * @notice withdraw the interest
     * @param user: the address of the user
     * @param docLockedInDcaSchedules: the amount of DOC locked in DCA schedules
     */
    function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        uint256 totalDocInLending = _lendingTokenToDoc(s_kDocBalances[user], exchangeRate);
        if (totalDocInLending <= docLockedInDcaSchedules) {
            return; // No interest to withdraw
        }
        uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
        uint256 docRedeemed = _burnKdoc(user, docInterestAmount, exchangeRate);
        
        i_stableToken.safeTransfer(user, docRedeemed);
    }

    function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
        external
        //view
        override
        onlyDcaManager
        returns (uint256 docInterestAmount)
    {
        uint256 totalDocInLending = _lendingTokenToDoc(s_kDocBalances[user], i_kDocToken.exchangeRateCurrent());
        docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice redeem DOC
     * @param user: the address of the user
     * @param docToRedeem: the amount of DOC to redeem
     * @return docRedeemed: the amount of DOC redeemed
     */
    function _redeemDoc(address user, uint256 docToRedeem) internal virtual returns (uint256) {
        return _redeemDoc(user, docToRedeem, i_kDocToken.exchangeRateCurrent());
    }

    /**
     * @notice redeem DOC
     * @param user: the address of the user
     * @param docToRedeem: the amount of DOC to redeem
     * @param exchangeRate: the exchange rate of DOC to lending token
     * @return docRedeemed: the amount of DOC redeemed
     */
    function _redeemDoc(address user, uint256 docToRedeem, uint256 exchangeRate) internal virtual returns (uint256) {
        uint256 usersKdocBalance = s_kDocBalances[user];
        uint256 kDocToRepay = _underlyingToLendingToken(docToRedeem, exchangeRate);
        if (kDocToRepay > usersKdocBalance) {
            emit TokenLending__AmountToRepayAdjusted(user, kDocToRepay, usersKdocBalance);
            kDocToRepay = usersKdocBalance;
            docToRedeem = _lendingTokenToDoc(kDocToRepay, exchangeRate);
        }
        s_kDocBalances[user] -= kDocToRepay;
        
        // Store DOC balance before redemption
        uint256 docBalanceBefore = i_stableToken.balanceOf(address(this));
        
        uint256 result = i_kDocToken.redeemUnderlying(docToRedeem);
        if (result == 0) {
            uint256 docBalanceAfter = i_stableToken.balanceOf(address(this));
            uint256 docRedeemed = docBalanceAfter - docBalanceBefore;
            emit TokenLending__SuccessfulUnderlyingRedemption(user, docRedeemed, kDocToRepay);
            return docRedeemed;
        }
        else revert TropykusDocLending__RedeemUnderlyingFailed(result);
    }

    /**
     * @notice burn kDOC
     * @param user: the address of the user
     * @param docToRedeem: the amount of DOC to redeem
     * @param exchangeRate: the exchange rate of DOC to lending token
     * @return docRedeemed the amount of DOC redeemed
     */
    function _burnKdoc(address user, uint256 docToRedeem, uint256 exchangeRate)
        internal
        returns (uint256 docRedeemed)
    {
        uint256 usersKdocBalance = s_kDocBalances[user];
        uint256 kDocToRepay = _underlyingToLendingToken(docToRedeem, exchangeRate);
        if (kDocToRepay > usersKdocBalance) {
            emit TokenLending__AmountToRepayAdjusted(user, kDocToRepay, usersKdocBalance);
            kDocToRepay = usersKdocBalance;
            docToRedeem = _lendingTokenToDoc(kDocToRepay, exchangeRate);
        }
        s_kDocBalances[user] -= kDocToRepay;
        uint256 docBalanceBefore = i_stableToken.balanceOf(address(this));
        uint256 result = i_kDocToken.redeem(kDocToRepay);
        if (result == 0) {
            uint256 docBalanceAfter = i_stableToken.balanceOf(address(this));
            docRedeemed = docBalanceAfter - docBalanceBefore;
            emit TokenLending__SuccessfulUnderlyingRedemption(user, docRedeemed, kDocToRepay);
        } else {
            revert TropykusDocLending__RedeemUnderlyingFailed(result);
        }
    }

    /**
     * @notice batch redeem DOC
     * @param users: the addresses of the users
     * @param purchaseAmounts: the amounts of DOC to redeem
     * @param totalDocToRedeem: the total amount of DOC to redeem
     * @return docRedeemed: the amount of DOC redeemed
     */
    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocToRedeem)
        internal
        virtual
        returns (uint256)
    {
        (, uint256 underlyingAmount,,) = i_kDocToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        if (totalDocToRedeem > underlyingAmount) {
            revert TokenLending__UnderlyingRedeemAmountExceedsBalance(totalDocToRedeem, underlyingAmount);
        }
        uint256 totalKdocToRepay = _underlyingToLendingToken(totalDocToRedeem, i_kDocToken.exchangeRateCurrent());

        uint256 numOfPurchases = users.length;
        for (uint256 i; i < numOfPurchases; ++i) {
            // @notice the amount of kDOC each user repays is proportional to the ratio of that user's DOC getting redeemed over the total DOC getting redeemed
            uint256 usersRepayedKdoc = totalKdocToRepay * purchaseAmounts[i] / totalDocToRedeem;
            s_kDocBalances[users[i]] -= usersRepayedKdoc;
            emit TokenLending__UnderlyingRedeemedLendingTokenRepayed(users[i], purchaseAmounts[i], usersRepayedKdoc);
        }
        
        // Store DOC balance before redemption
        uint256 docBalanceBefore = i_stableToken.balanceOf(address(this));
        
        uint256 result = i_kDocToken.redeemUnderlying(totalDocToRedeem);
        if (result == 0) {
            uint256 docBalanceAfter = i_stableToken.balanceOf(address(this));
            uint256 docRedeemed = docBalanceAfter - docBalanceBefore;
            
            emit TokenLending__SuccessfulBatchUnderlyingRedemption(docRedeemed, totalKdocToRepay);
            return docRedeemed;
        }
        else revert TokenLending__BatchRedeemUnderlyingFailed(); // TODO: cambiar a TropykusDocLending__BatchRedeemDocFailed?
    }
}
