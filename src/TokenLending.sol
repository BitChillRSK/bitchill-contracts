// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenLending} from "./interfaces/ITokenLending.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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
        returns (uint256 lendingTokenAmount)
    {
        lendingTokenAmount = Math.mulDiv(underlyingAmount, i_exchangeRateDecimals, exchangeRate);
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
        underlyingAmount = Math.mulDiv(lendingTokenAmount, exchangeRate, i_exchangeRateDecimals, Math.Rounding.Up);
    }
}
