// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenLending} from "./interfaces/ITokenLending.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FeeHandler} from "./FeeHandler.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenLending
 * @notice Defines functions to convert stablecoin balances to interest bearing token and vice versa
 */
abstract contract TokenLending is ITokenLending {
    uint256 immutable i_exchangeRateDecimals;

    constructor(uint256 exchangeRateDecimals) {
        i_exchangeRateDecimals = exchangeRateDecimals;
    }

    /**
     * @notice convert underlying token to interest bearing token
     * @param underlyingAmount: the amount of underlying token to convert
     * @param exchangeRate: the exchange rate of underlying token to interest bearing token
     * @return interestBearingAmount the amount of interest bearing token
     */
    function _underlyingToInterestBearing(uint256 underlyingAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 interestBearingAmount)
    {
        // interestBearingAmount = underlyingAmount * i_exchangeRateDecimals / exchangeRate;
        // interestBearingAmount = Math.mulDiv(underlyingAmount, i_exchangeRateDecimals, exchangeRate, Math.Rounding.Up);
        interestBearingAmount = Math.mulDiv(underlyingAmount, i_exchangeRateDecimals, exchangeRate);
    }

    /**
     * @notice convert interest bearing token to underlying token
     * @param interestBearingAmount: the amount of interest bearing token to convert
     * @param exchangeRate: the exchange rate of interest bearing token to underlying
     * @return underlyingAmount the amount of underlying
     */
    function _interestBearingToUnderlying(uint256 interestBearingAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 underlyingAmount)
    {
        // underlyingAmount = interestBearingAmount * exchangeRate / i_exchangeRateDecimals;
        // Using OpenZeppelin's Math library for precise division rounding up
        underlyingAmount = Math.mulDiv(interestBearingAmount, exchangeRate, i_exchangeRateDecimals, Math.Rounding.Up);
        // underlyingAmount = Math.mulDiv(interestBearingAmount, exchangeRate, i_exchangeRateDecimals);
    }
}
