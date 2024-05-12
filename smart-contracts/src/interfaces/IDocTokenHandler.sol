// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDocTokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the TokenHandler contract.
 */
interface IDocTokenHandler {
    //////////////////////
    // Events ////////////
    //////////////////////

    //////////////////////
    // Errors ////////////
    //////////////////////
    error DocTokenHandler__RedeemDocRequestFailed();
    error DocTokenHandler__RedeemFreeDocFailed();
}
