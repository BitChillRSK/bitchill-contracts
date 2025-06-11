// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenLending} from "./ITokenLending.sol";

/**
 * @title ITropykusErc20Lending
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the TropykusErc20Handler contract.
 */
interface ITropykusErc20Lending is ITokenLending {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error TropykusErc20Lending__RedeemUnderlyingFailed(uint256 errorCode);
}
