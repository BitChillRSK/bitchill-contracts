// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// Protocol configuration
uint256 constant MIN_PURCHASE_AMOUNT = 25 ether; // at least 25 DOC on each purchase
uint256 constant MIN_FEE_RATE = 100;
uint256 constant MAX_FEE_RATE = 200; // CAMBIAR ESTO PARA EL DESPLIEGUE REAL!!!!
uint256 constant PURCHASE_LOWER_BOUND = 1000 ether; // 1000 DOC
uint256 constant PURCHASE_UPPER_BOUND = 100_000 ether; // 100,000 DOC
uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000;

// Chain IDs
uint256 constant ANVIL_CHAIN_ID = 31337;
uint256 constant RSK_MAINNET_CHAIN_ID = 30;
uint256 constant RSK_TESTNET_CHAIN_ID = 31;

// Lending protocols
string constant TROPYKUS_STRING = "tropykus";
uint256 constant TROPYKUS_INDEX = 1;
string constant SOVRYN_STRING = "sovryn";
uint256 constant SOVRYN_INDEX = 2;

// Default configurations
string constant DEFAULT_STABLECOIN = "DOC"; // Default stablecoin to use if not specified
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT = 0.985 ether; // 98.5%
uint256 constant DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK = 0.95 ether; // 95%
uint256 constant MAX_SLIPPAGE_PERCENT = 1 ether - DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT; 


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
uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

// Token holders on mainnet with significant balances (for fork testing)
address constant DOC_HOLDER = 0x65d189e839aF28B78567bD7255f3f796495141bc; // Large DOC holder on RSK mainnet
address constant USDRIF_HOLDER = 0xaC31A4bEedd7EC916B7A48a612230cb85c1aaf56; // Large USDRIF holder on RSK mainnet 