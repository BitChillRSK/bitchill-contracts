// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenLending} from "./ITokenLending.sol";

/**
 * @title ISovrynDocLending
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the SovrynDocHandler contract.
 */
interface ISovrynDocLending is ITokenLending {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error SovrynDocLending__RedeemUnderlyingFailed();
}
