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
 * @notice Defines functions to convert stablecoin balances to lending token and vice versa
 */
abstract contract TokenLending is ITokenLending {
    uint256 immutable i_exchangeRateDecimals;

    constructor(uint256 exchangeRateDecimals) {
        i_exchangeRateDecimals = exchangeRateDecimals;
    }

    /**
     * @notice convert DOC to lending token
     * @param docAmount: the amount of DOC to convert
     * @param exchangeRate: the exchange rate of DOC to lending token
     * @return lendingTokenAmount the amount of lending token
     */
    function _docToLendingToken(uint256 docAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 lendingTokenAmount)
    {
        // lendingTokenAmount = docAmount * i_exchangeRateDecimals / exchangeRate;
        // lendingTokenAmount = Math.mulDiv(docAmount, i_exchangeRateDecimals, exchangeRate, Math.Rounding.Up);
        lendingTokenAmount = Math.mulDiv(docAmount, i_exchangeRateDecimals, exchangeRate);
    }

    /**
     * @notice convert lending token to DOC
     * @param lendingTokenAmount: the amount of lending token to convert
     * @param exchangeRate: the exchange rate of lending token to DOC
     * @return docAmount the amount of DOC
     */
    function _lendingTokenToDoc(uint256 lendingTokenAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 docAmount)
    {
        // docAmount = lendingTokenAmount * exchangeRate / i_exchangeRateDecimals;
        // Using OpenZeppelin's Math library for precise division rounding up
        docAmount = Math.mulDiv(lendingTokenAmount, exchangeRate, i_exchangeRateDecimals, Math.Rounding.Up);
        // docAmount = Math.mulDiv(lendingTokenAmount, exchangeRate, i_exchangeRateDecimals);
    }
}
