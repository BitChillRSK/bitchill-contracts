// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {Test, console} from "forge-std/Test.sol";

string constant OWNER_STRING = "owner";
string constant USER_STRING = "user";
string constant ADMIN_STRING = "ADMIN";
string constant SWAPPER_STRING = "SWAPPER";
string constant FEE_COLLECTOR_STRING = "feeCollector";
uint256 constant MIN_PURCHASE_AMOUNT = 25 ether; // at least 25 DOC on each purchase
uint256 constant MIN_FEE_RATE = 100;
uint256 constant MAX_FEE_RATE = 200;
uint256 constant MIN_ANNUAL_AMOUNT = 1000 ether; // 1000 DOC
uint256 constant MAX_ANNUAL_AMOUNT = 100_000 ether; // 100,000 DOC
uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000;
uint256 constant BTC_PRICE = 50_000; // 1 BTC = 50,000 DOC
uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;
bool constant DOC_YIELDS_INTEREST = true;

// uint256 constant DOC_BALANCES_SLOT = 4;
