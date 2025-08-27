// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenLending} from "./interfaces/ITokenLending.sol";

/**
 * @title TokenLending
 * @notice Defines functions to convert stablecoin balances to lending token and vice versa
 */
abstract contract TokenLending is ITokenLending {
    uint256 immutable i_exchangeRateDecimals;

    constructor(uint256 exchangeRateDecimals) {
        i_exchangeRateDecimals = exchangeRateDecimals;
    }

    /**
     * @notice convert underlying token to lending token
     * @param underlyingAmount: the amount of underlying token to convert
     * @param exchangeRate: the exchange rate of underlying token to lending token
     * @return lendingTokenAmount the amount of lending token
     */
    function _stablecoinToLendingToken(uint256 underlyingAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 lendingTokenAmount, bool hasTruncated)
    {
        lendingTokenAmount = underlyingAmount * i_exchangeRateDecimals / exchangeRate;
        hasTruncated = underlyingAmount * i_exchangeRateDecimals % exchangeRate != 0;
    }

    /**
     * @notice convert lending token to underlying token
     * @param lendingTokenAmount: the amount of lending token to convert
     * @param exchangeRate: the exchange rate of lending token to underlying
     * @return underlyingAmount the amount of underlying
     */
    function _lendingTokenToStablecoin(uint256 lendingTokenAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 underlyingAmount)
    {
        underlyingAmount = lendingTokenAmount * exchangeRate / i_exchangeRateDecimals;
    }

    /**
     * @notice round up (add 1 WEI to) the lending token amount to avoid underestimating the amount to withdraw from each user's balance
     * @param lendingTokenAmount: the amount of lending token to round up
     * @return lendingTokenAmount the rounded up amount of lending token
     */
    function _lendingTokenRoundUp(uint256 lendingTokenAmount) internal pure returns (uint256) {
        return lendingTokenAmount + 1;
    }
}
