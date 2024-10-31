// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDocHandlerMoc} from "../../src/interfaces/IDocHandlerMoc.sol";
import {IDocHandlerDex} from "../../src/interfaces/IDocHandlerDex.sol";

/**
 * @title ITestDocTokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface used to test the DocTokenHandler contracts
 */
interface ITestDocTokenHandler is IDocHandlerMoc, IDocHandlerDex {}
