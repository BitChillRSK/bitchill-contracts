// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenLending} from "./interfaces/ITokenLending.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FeeHandler} from "./FeeHandler.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenLending
 */
abstract contract TokenLending is ITokenLending {
    //////////////////////
    // State variables ///
    //////////////////////
    uint256 immutable i_exchangeRateDecimals; // The minimum amount of this token for periodic purchases

    constructor(uint256 exchangeRateDecimals) {
        i_exchangeRateDecimals = exchangeRateDecimals;
    }
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // Define abstract functions to be implemented by child contracts

    // function _redeemDoc(address buyer, uint256 amount) internal virtual;

    function _docToLendingToken(uint256 docAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 lendingTokenAmount)
    {
        // lendingTokenAmount = docAmount * i_exchangeRateDecimals / exchangeRate;
        // lendingTokenAmount = Math.mulDiv(docAmount, i_exchangeRateDecimals, exchangeRate, Math.Rounding.Up);
        lendingTokenAmount = Math.mulDiv(docAmount, i_exchangeRateDecimals, exchangeRate);
    }

    function _lendingTokenToDoc(uint256 lendingTokenAmount, uint256 exchangeRate)
        internal
        view
        returns (uint256 docAmount)
    {
        // docAmount = lendingTokenAmount * exchangeRate / i_exchangeRateDecimals;
        // Using OpenZeppelin's Math library for precise division rounding up
        // docAmount = Math.mulDiv(lendingTokenAmount, exchangeRate, i_exchangeRateDecimals, Math.Rounding.Up);
        docAmount = Math.mulDiv(lendingTokenAmount, exchangeRate, i_exchangeRateDecimals);
    }
}
