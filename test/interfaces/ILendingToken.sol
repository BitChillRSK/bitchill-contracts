// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IkToken} from "../../src/interfaces/IkToken.sol";
import {IiSusdToken} from "../../src/interfaces/IiSusdToken.sol";

/**
 * @title ILendingToken
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Generic interface for lending tokens.
 */
interface ILendingToken is IkToken, IiSusdToken {
    /**
     * @dev Returns the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address owner) external override(IiSusdToken, IkToken) returns (uint256);
}
