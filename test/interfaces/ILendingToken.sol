// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IkDocToken} from "../../src/interfaces/IkDocToken.sol";
import {IiSusdToken} from "../../src/interfaces/IiSusdToken.sol";

/**
 * @title ILendingToken
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Generic interface for lending tokens.
 */
interface ILendingToken is IkDocToken, IiSusdToken {
    /**
     * @dev Returns the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address owner) external override(IiSusdToken, IkDocToken) returns (uint256);
}
