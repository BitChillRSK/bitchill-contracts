// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenHandler} from "./TokenHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IDocTokenHandlerBase} from "./interfaces/IDocTokenHandlerBase.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";

/**
 * @title BaseDocTokenHandler
 * @dev Abstract base contract for DocTokenHandler implementations.
 */
abstract contract BaseDocTokenHandler is TokenHandler, IDocTokenHandlerBase {
    using SafeERC20 for IERC20;

    //////////////////////
    // State Variables ///
    //////////////////////

    IMocProxy public immutable i_mocProxy;
    IERC20 public immutable i_docToken;
    IkDocToken public immutable i_kDocToken;
    mapping(address => uint256) internal s_kDocBalances;
    uint256 internal constant EXCHANGE_RATE_DECIMALS = 1e18;

    //////////////////////
    // Events and Errors ///
    //////////////////////

    // You can include common events and errors here if applicable

    //////////////////////
    // Constructor ///
    //////////////////////

    /**
     * @notice Initializes the base contract.
     * @param dcaManagerAddress Address of the DCA Manager contract.
     * @param docTokenAddress Address of the DOC token contract.
     * @param kDocTokenAddress Address of the kDOC token contract.
     * @param minPurchaseAmount Minimum DOC amount for purchases.
     * @param feeCollector Address to collect fees.
     * @param feeSettings Fee calculation settings.
     * @param yieldsInterest Boolean indicating if interest is yielded.
     * @param mocProxyAddress Address of the MoC proxy contract.
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address kDocTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        bool yieldsInterest,
        address mocProxyAddress
    )
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings, yieldsInterest)
        Ownable(msg.sender)
    {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkDocToken(kDocTokenAddress);
        i_mocProxy = IMocProxy(mocProxyAddress);
    }

    //////////////////////
    // External Functions ///
    //////////////////////

    /**
     * @notice Withdraw interest earned by the user.
     * @param user The user withdrawing interest.
     * @param docLockedInDcaSchedules The amount of DOC locked in DCA schedules.
     */
    function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        uint256 totalDocInLending = _kdocToDoc(s_kDocBalances[user], exchangeRate);
        uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
        uint256 kDocToRepay = (docInterestAmount * EXCHANGE_RATE_DECIMALS) / exchangeRate;

        s_kDocBalances[user] -= kDocToRepay;
        uint256 result = i_kDocToken.redeemUnderlying(docInterestAmount);
        if (result == 0) emit DocTokenHandler__SuccessfulDocRedemption(user, docInterestAmount, kDocToRepay);
        else revert DocTokenHandler__RedeemUnderlyingFailed(result);
        i_docToken.safeTransfer(user, docInterestAmount);
        emit DocTokenHandler__SuccessfulInterestWithdrawal(user, docInterestAmount, kDocToRepay);
    }
    /**
     * @notice Gets the kDOC balance of the user
     * @param user The user whose balance is checked
     */

    function getUsersKdocBalance(address user) external view virtual returns (uint256) {
        return s_kDocBalances[user];
    }

    /**
     * @notice Calculates accrued interest for a user.
     * @param user The user to calculate interest for.
     * @param docLockedInDcaSchedules The amount of DOC locked in DCA schedules.
     * @return docInterestAmount The calculated interest amount.
     */
    function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
        external
        view
        virtual
        returns (uint256 docInterestAmount);

    //////////////////////
    // Internal Functions ///
    //////////////////////

    /**
     * @notice Converts DOC amount to kDOC.
     * @param docAmount The amount of DOC.
     * @param exchangeRate The current exchange rate.
     * @return kDocAmount The calculated kDOC amount.
     */
    function _docToKdoc(uint256 docAmount, uint256 exchangeRate) internal pure returns (uint256 kDocAmount) {
        kDocAmount = (docAmount * EXCHANGE_RATE_DECIMALS) / exchangeRate;
    }

    /**
     * @notice Converts kDOC amount to DOC.
     * @param kDocAmount The amount of kDOC.
     * @param exchangeRate The current exchange rate.
     * @return docAmount The calculated DOC amount.
     */
    function _kdocToDoc(uint256 kDocAmount, uint256 exchangeRate) internal pure returns (uint256 docAmount) {
        docAmount = (kDocAmount * exchangeRate) / EXCHANGE_RATE_DECIMALS;
    }

    /**
     * @notice Redeems DOC for a user.
     * @param user The user for whom DOC is redeemed.
     * @param docToRedeem The amount of DOC to redeem.
     */
    function _redeemDoc(address user, uint256 docToRedeem) internal virtual;

    /**
     * @notice Batch redeems DOC for multiple users.
     * @param users Array of user addresses.
     * @param purchaseAmounts Array of DOC amounts to redeem.
     * @param totalDocToRedeem Total DOC to redeem.
     */
    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocToRedeem)
        internal
        virtual;
}
