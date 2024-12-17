// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDexSwaps} from "./IDexSwaps.sol";
import {IDocHandler} from "./IDocHandler.sol";

/**
 * @title IDocHandlerDex
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocHandlerDex contract.
 */
interface IDocHandlerDex is IDocHandler, IDexSwaps {}
