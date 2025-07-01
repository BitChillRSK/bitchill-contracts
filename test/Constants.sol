// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Import main constants from script
import "../script/Constants.sol";

// Test-specific overrides only - these values are used specifically for testing
// and may differ from production deployment values

// Test addresses for mainnet with significant balances (for fork testing)
address constant DOC_HOLDER_TEST = 0x53Ec0aF115619c536480C95Dec4a065e27E6419F; // Large DOC holder on RSK testnet
address constant USDRIF_HOLDER_TEST = 0xe38C86970543173D334b828485D8bc48d19Ff701; // Large USDRIF holder on RSK testnet
