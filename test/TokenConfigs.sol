// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/**
 * @title TokenConfigs
 * @dev This file contains configurations for different stablecoins supported by the DCA protocol.
 */

struct TokenConfig {
    string tokenSymbol;       // Symbol of the token (e.g., "DOC", "USDRIF")
    address tokenAddress;     // Address of the token contract
    address lendingTokenAddress; // Address of the corresponding lending token (e.g., kDOC, kUSDRIF)
    string mintFunctionName;  // Name of the mint function in the mock proxy
    uint256 defaultAmount;    // Default amount for testing
    bool supportedBySovryn;   // Whether this stablecoin is supported by Sovryn
}

library TokenConfigs {
    // Function to retrieve token configuration based on symbol from Constants.sol
    function getTokenConfig(string memory tokenSymbol, uint256 chainId) internal pure returns (TokenConfig memory) {
        // Return predefined configs for different networks
        if (chainId == 31337) { // ANVIL_CHAIN_ID
            return getAnvilTokenConfig(tokenSymbol);
        } else if (chainId == 30) { // RSK_MAINNET_CHAIN_ID
            return getMainnetTokenConfig(tokenSymbol);
        } else if (chainId == 31) { // RSK_TESTNET_CHAIN_ID
            return getTestnetTokenConfig(tokenSymbol);
        }
        
        revert("Unsupported network");
    }
    
    // Token configs for Anvil test environment
    function getAnvilTokenConfig(string memory tokenSymbol) internal pure returns (TokenConfig memory) {
        bytes32 symbolHash = keccak256(abi.encodePacked(tokenSymbol));
        
        if (symbolHash == keccak256(abi.encodePacked("DOC"))) {
            return TokenConfig({
                tokenSymbol: "DOC",
                tokenAddress: address(0), // Will be set dynamically during deployment
                lendingTokenAddress: address(0), // Will be set dynamically during deployment
                mintFunctionName: "mintDoc",
                defaultAmount: 2000 ether,
                supportedBySovryn: true
            });
        } else if (symbolHash == keccak256(abi.encodePacked("USDRIF"))) {
            return TokenConfig({
                tokenSymbol: "USDRIF",
                tokenAddress: address(0), // Will be set dynamically during deployment
                lendingTokenAddress: address(0), // Will be set dynamically during deployment
                mintFunctionName: "mintUsdrif",
                defaultAmount: 2000 ether,
                supportedBySovryn: false // USDRIF is not supported by Sovryn
            });
        }
        
        revert("Unsupported token");
    }
    
    // Token configs for RSK Mainnet
    function getMainnetTokenConfig(string memory tokenSymbol) internal pure returns (TokenConfig memory) {
        bytes32 symbolHash = keccak256(abi.encodePacked(tokenSymbol));
        
        if (symbolHash == keccak256(abi.encodePacked("DOC"))) {
            return TokenConfig({
                tokenSymbol: "DOC",
                tokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db,
                lendingTokenAddress: 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2,
                mintFunctionName: "mintDoc",
                defaultAmount: 2000 ether,
                supportedBySovryn: true
            });
        } else if (symbolHash == keccak256(abi.encodePacked("USDRIF"))) {
            return TokenConfig({
                tokenSymbol: "USDRIF",
                tokenAddress: 0x3A15461d8aE0F0Fb5Fa2629e9DA7D66A794a6e37,
                lendingTokenAddress: 0xDdf3CE45fcf080DF61ee61dac5Ddefef7ED4F46C,
                mintFunctionName: "mintUsdrif",
                defaultAmount: 2000 ether,
                supportedBySovryn: false // USDRIF is not supported by Sovryn
            });
        }
        
        revert("Unsupported token");
    }
    
    // Token configs for RSK Testnet
    function getTestnetTokenConfig(string memory tokenSymbol) internal pure returns (TokenConfig memory) {
        bytes32 symbolHash = keccak256(abi.encodePacked(tokenSymbol));
        
        if (symbolHash == keccak256(abi.encodePacked("DOC"))) {
            return TokenConfig({
                tokenSymbol: "DOC",
                tokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0,
                lendingTokenAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914,
                mintFunctionName: "mintDoc",
                defaultAmount: 2000 ether,
                supportedBySovryn: true
            });
        } else if (symbolHash == keccak256(abi.encodePacked("USDRIF"))) {
            // NOTE: Update these addresses with actual testnet addresses when available
            return TokenConfig({
                tokenSymbol: "USDRIF",
                tokenAddress: address(0), // Placeholder - update with actual address
                lendingTokenAddress: address(0), // Placeholder - update with actual address
                mintFunctionName: "mintUsdrif",
                defaultAmount: 2000 ether,
                supportedBySovryn: false // USDRIF is not supported by Sovryn
            });
        }
        
        revert("Unsupported token");
    }
} 