// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

uint256 constant ANVIL_CHAIN_ID = 31337;
uint256 constant RSK_MAINNET_CHAIN_ID = 30;
uint256 constant RSK_TESTNET_CHAIN_ID = 31;
string constant OWNER_STRING = "owner";
string constant USER_STRING = "user";
string constant ADMIN_STRING = "ADMIN";
string constant SWAPPER_STRING = "SWAPPER";
string constant FEE_COLLECTOR_STRING = "feeCollector";
string constant TROPYKUS_STRING = "tropykus";
uint256 constant TROPYKUS_INDEX = 1;
string constant SOVRYN_STRING = "sovryn";
uint256 constant SOVRYN_INDEX = 2;
uint256 constant MIN_PURCHASE_AMOUNT = 25 ether; // at least 25 DOC on each purchase
uint256 constant MIN_FEE_RATE = 100;
uint256 constant MAX_FEE_RATE = 200;
uint256 constant PURCHASE_LOWER_BOUND = 1000 ether; // 1000 DOC
uint256 constant PURCHASE_UPPER_BOUND = 100_000 ether; // 100,000 DOC
uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000;
uint256 constant BTC_PRICE = 50_000; // 1 BTC = 50,000 DOC
uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT = 0.985 ether; // 98.5%
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK = 0.95 ether; // 95%
