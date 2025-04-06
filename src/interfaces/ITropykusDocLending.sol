// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenLending} from "./ITokenLending.sol";

/**
 * @title ITropykusDocLending
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the TropykusDocHandler contract.
 */
interface ITropykusDocLending is ITokenLending {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TropykusDocLending__RedeemUnderlyingFailed(uint256 errorCode);
}
