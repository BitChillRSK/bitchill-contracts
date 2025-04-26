// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {ISovrynErc20Lending} from "./interfaces/ISovrynErc20Lending.sol";
import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TokenLending} from "src/TokenLending.sol";

/**
 * @title SovrynErc20Handler
 * @notice This abstract contract contains the stablecoin related functions that are common regardless of the method used to swap stablecoin for rBTC
 */
abstract contract SovrynErc20Handler is TokenHandler, TokenLending, ISovrynErc20Lending {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IiSusdToken public immutable i_iSusdToken;
    mapping(address user => uint256 balance) internal s_iSusdBalances;
    uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

    /**
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param stableTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param iSusdTokenAddress the address of Sovryn' iSusd token contract
     * @param minPurchaseAmount  the minimum amount of stablecoin for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     */
    constructor(
        address dcaManagerAddress,
        address stableTokenAddress,
        address iSusdTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    )
        TokenHandler(dcaManagerAddress, stableTokenAddress, minPurchaseAmount, feeCollector, feeSettings)
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
        uint256 mintedAmount = i_iSusdToken.mint(address(this), depositAmount);
        if (mintedAmount == 0) revert TokenLending__LendingProtocolDepositFailed();
        s_iSusdBalances[user] += mintedAmount;
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
        uint256 stablecoinInSovryn = _lendingTokenToStablecoin(s_iSusdBalances[user], exchangeRate);

        if (stablecoinInSovryn < withdrawalAmount) {
            emit TokenLending__WithdrawalAmountAdjusted(user, withdrawalAmount, stablecoinInSovryn);
            withdrawalAmount = stablecoinInSovryn;
        }

        withdrawalAmount = _redeemStablecoin(user, withdrawalAmount, exchangeRate);
        super.withdrawToken(user, withdrawalAmount);
    }

    /**
     * @notice get the users lending token balance
     * @param user: the address of the user
     * @return the users lending token balance
     */
    function getUsersLendingTokenBalance(address user) external view override returns (uint256) {
        return s_iSusdBalances[user];
    }

    /**
     * @notice withdraw the interest
     * @param user: the address of the user
     * @param stablecoinLockedInDcaSchedules: the amount of stablecoin locked in DCA schedules
     */
    function withdrawInterest(address user, uint256 stablecoinLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_iSusdToken.tokenPrice();
        uint256 totalErc20InLending = _lendingTokenToStablecoin(s_iSusdBalances[user], exchangeRate);
        if (totalErc20InLending <= stablecoinLockedInDcaSchedules) {
            return; // No interest to withdraw
        }
        uint256 stablecoinInterestAmount = totalErc20InLending - stablecoinLockedInDcaSchedules;
        _redeemStablecoin(user, stablecoinInterestAmount, exchangeRate, user);
    }

    /**
     * @notice get the accrued interest
     * @param user: the address of the user
     * @param stablecoinLockedInDcaSchedules: the amount of stablecoin locked in DCA schedules
     * @return stablecoinInterestAmount the amount of accrued interest
     */
    function getAccruedInterest(address user, uint256 stablecoinLockedInDcaSchedules)
        external
        view
        override
        onlyDcaManager
        returns (uint256 stablecoinInterestAmount)
    {
        uint256 totalErc20InLending = _lendingTokenToStablecoin(s_iSusdBalances[user], i_iSusdToken.tokenPrice());
        stablecoinInterestAmount = totalErc20InLending - stablecoinLockedInDcaSchedules;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice redeem stablecoin
     * @param user: the address of the user
     * @param stablecoinToRedeem: the amount of stablecoin to redeem
     * @return stablecoinRedeemed: the amount of stablecoin redeemed
     */
    function _redeemStablecoin(address user, uint256 stablecoinToRedeem) internal virtual returns (uint256) {
        // For buyRbtc(), we want the stablecoin to come to the contract
        return _redeemStablecoin(user, stablecoinToRedeem, i_iSusdToken.tokenPrice(), address(this));
    }

    /**
     * @notice redeem stablecoin
     * @param user: the address of the user
     * @param stablecoinToRedeem: the amount of stablecoin to redeem
     * @param exchangeRate: the exchange rate of stablecoin to rBTC
     * @return stablecoinRedeemed: the amount of stablecoin redeemed
     */
    function _redeemStablecoin(address user, uint256 stablecoinToRedeem, uint256 exchangeRate) internal virtual returns (uint256) {
        return _redeemStablecoin(user, stablecoinToRedeem, exchangeRate, address(this));
    }

    /**
     * @notice redeem stablecoin
     * @param user: the address of the user
     * @param stablecoinToRedeem: the amount of stablecoin to redeem
     * @param exchangeRate: the exchange rate of stablecoin to rBTC
     * @param stablecoinRecipient: the address of the recipient of the stablecoin
     * @return stablecoinRedeemed: the amount of stablecoin redeemed
     */
    function _redeemStablecoin(address user, uint256 stablecoinToRedeem, uint256 exchangeRate, address stablecoinRecipient)
        internal
        virtual
        returns (uint256)
    {
        uint256 usersIsusdBalance = s_iSusdBalances[user];
        uint256 iSusdToRepay = _stablecoinToLendingToken(stablecoinToRedeem, exchangeRate);
        if (iSusdToRepay > usersIsusdBalance) {
            emit TokenLending__AmountToRepayAdjusted(user, iSusdToRepay, usersIsusdBalance);
            iSusdToRepay = usersIsusdBalance;
        }
        s_iSusdBalances[user] -= iSusdToRepay;
        uint256 stablecoinRedeemed = i_iSusdToken.burn(stablecoinRecipient, iSusdToRepay);
        if (stablecoinRedeemed == 0) revert SovrynErc20Lending__RedeemUnderlyingFailed();
        emit TokenLending__SuccessfulUnderlyingRedemption(user, stablecoinRedeemed, iSusdToRepay);
        return stablecoinRedeemed;
    }

    /**
     * @notice batch redeem stablecoin
     * @param users: the addresses of the users
     * @param purchaseAmounts: the amounts of stablecoin to redeem
     * @param totalErc20ToRedeem: the total amount of stablecoin to redeem
     * @return stablecoinRedeemed: the amount of stablecoin redeemed
     */
    function _batchRedeemStablecoin(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalErc20ToRedeem)
        internal
        virtual
        returns (uint256)
    {
        uint256 underlyingAmount =
            i_iSusdToken.assetBalanceOf(address(this)) + uint256(i_iSusdToken.profitOf(address(this))); // TODO: check if int->uint conversion is OK
        if (totalErc20ToRedeem > underlyingAmount) {
            revert TokenLending__UnderlyingRedeemAmountExceedsBalance(totalErc20ToRedeem, underlyingAmount);
        }
        uint256 totaliSusdToRepay = _stablecoinToLendingToken(totalErc20ToRedeem, i_iSusdToken.tokenPrice());

        uint256 numOfPurchases = users.length;
        for (uint256 i; i < numOfPurchases; ++i) {
            // @notice the amount of iSusd each user repays is proportional to the ratio of that user's stablecoin getting redeemed over the total stablecoin getting redeemed
            uint256 usersRepayediSusd = totaliSusdToRepay * purchaseAmounts[i] / totalErc20ToRedeem;
            s_iSusdBalances[users[i]] -= usersRepayediSusd;
            emit TokenLending__UnderlyingRedeemedLendingTokenRepayed(users[i], purchaseAmounts[i], usersRepayediSusd);
        }
        uint256 stablecoinRedeemed = i_iSusdToken.burn(address(this), totaliSusdToRepay);
        if (stablecoinRedeemed > 0) emit TokenLending__SuccessfulBatchUnderlyingRedemption(totalErc20ToRedeem, totaliSusdToRepay);
        else revert SovrynErc20Lending__RedeemUnderlyingFailed();
        return stablecoinRedeemed;
    }
}
