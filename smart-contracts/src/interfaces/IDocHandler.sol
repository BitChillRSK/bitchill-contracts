// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./ITokenHandler.sol";
import {ITokenLending} from "./ITokenLending.sol";

/**
 * @title IDocHandler: interface common to the different DocHandler contracts
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocHandler contract.
 */
interface IDocHandler is ITokenHandler, ITokenLending {}
