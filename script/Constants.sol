// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Protocol configuration
uint256 constant MIN_PURCHASE_AMOUNT = 25 ether; // at least 25 DOC on each purchase
uint256 constant MIN_FEE_RATE = 100;
uint256 constant MAX_FEE_RATE_TEST = 200; // 2% for testing - allows for better fee range testing
uint256 constant MAX_FEE_RATE_PRODUCTION = 100; // 1% flat rate for production (same as MIN_FEE_RATE for flat fee)
uint256 constant FEE_PURCHASE_LOWER_BOUND = 1000 ether; // 1000 DOC
uint256 constant FEE_PURCHASE_UPPER_BOUND = 100_000 ether; // 100,000 DOC
uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000;
uint256 constant MIN_PURCHASE_PERIOD = 1 days; // Default to at most one purchase each day
uint256 constant MAX_SCHEDULES_PER_TOKEN = 10; // Default to a maximum of 10 DCA schedules per token

// Chain IDs
uint256 constant ANVIL_CHAIN_ID = 31337;
uint256 constant RSK_MAINNET_CHAIN_ID = 30;
uint256 constant RSK_TESTNET_CHAIN_ID = 31;

// Lending protocols
string constant TROPYKUS_STRING = "tropykus";
uint256 constant TROPYKUS_INDEX = 1;
string constant SOVRYN_STRING = "sovryn";
uint256 constant SOVRYN_INDEX = 2;
// No lending -> 0
// "tropykus" -> 1
// "sovryn" -> 2

// Default configurations
string constant DEFAULT_STABLECOIN = "DOC"; // Default stablecoin to use if not specified
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT = 0.988 ether; // 98.8%
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK = 0.95 ether; // 95%
uint256 constant MAX_SLIPPAGE_PERCENT = 1 ether - DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT; 
uint256 constant EXCHANGE_RATE_DECIMALS = 1e18; // Valid for DOC and USDRIF in both Tropykus and Sovryn


/*//////////////////////////////////////////////////////////////
                        TESTS CONSTANTS
//////////////////////////////////////////////////////////////*/

// Test account names
string constant OWNER_STRING = "owner";
string constant USER_STRING = "user";
string constant ADMIN_STRING = "ADMIN";
string constant SWAPPER_STRING = "SWAPPER";
string constant FEE_COLLECTOR_STRING = "feeCollector";

// Test values
uint256 constant BTC_PRICE = 50_000; // 1 BTC = 50,000 DOC

// Token holders on mainnet with significant balances (for fork testing)
address constant DOC_HOLDER = 0x65d189e839aF28B78567bD7255f3f796495141bc; // Large DOC holder on RSK mainnet
address constant USDRIF_HOLDER = 0x14E04dEdE6Df981305Ec01ad4E31CC9E32c62fCe; // Large USDRIF holder on RSK mainnet 
// If these get rid of their holdings, we can look for other holders at 
// https://rootstock.blockscout.com/token/0x3A15461d8AE0f0Fb5fA2629e9dA7D66A794a6E37?tab=holders
// Token holders on testnet with significant balances (for fork testing)
address constant DOC_HOLDER_TESTNET = 0x53Ec0aF115619c536480C95Dec4a065e27E6419F; // Large DOC holder on RSK testnet
address constant USDRIF_HOLDER_TESTNET = 0xe38C86970543173D334b828485D8bc48d19Ff701; // Large USDRIF holder on RSK testnet