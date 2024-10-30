// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDocTokenHandler} from "../../src/interfaces/IDocTokenHandler.sol";
import {IDocTokenHandlerDex} from "../../src/interfaces/IDocTokenHandlerDex.sol";

/**
 * @title ITestDocTokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface used to test the DocTokenHandler contracts
 */
interface ITestDocTokenHandler is IDocTokenHandler, IDocTokenHandlerDex {}
