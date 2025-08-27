// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {ITokenLending} from "../../src/interfaces/ITokenLending.sol";

/**
 * @title IStablecoinHandler: interface common to the different DocHandler contracts
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocHandler contract.
 */
interface IStablecoinHandler is ITokenHandler, ITokenLending {}
