// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

uint256 constant MIN_FEE_RATE = 100;
uint256 constant MAX_FEE_RATE = 200;
uint256 constant MIN_ANNUAL_AMOUNT =  1000 ether; // 1000 DOC
uint256 constant MAX_ANNUAL_AMOUNT = 100_000 ether; // 100,000 DOC
uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000; // 100,000 DOC