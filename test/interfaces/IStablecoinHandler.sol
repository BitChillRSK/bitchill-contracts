// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {ITokenLending} from "../../src/interfaces/ITokenLending.sol";

/**
 * @title IStablecoinHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 */
interface IStablecoinHandler is ITokenHandler, ITokenLending {}
