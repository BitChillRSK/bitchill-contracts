// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockDocToken} from "../test/mocks/MockDocToken.sol";
import {MockKdocToken} from "../test/mocks/MockKdocToken.sol";
import {MockMocProxy} from "../test/mocks/MockMocProxy.sol";
import {MockWrbtcToken} from "../test/mocks/MockWrbtcToken.sol";
import {MockSwapRouter02} from "../test/mocks/MockSwapRouter02.sol";
import {MockMocOracle} from "../test/mocks/MockMocOracle.sol";
import "../test/Constants.sol";
import {Script} from "forge-std/Script.sol";

contract DexHelperConfig is Script {
    struct NetworkConfig {
        address docTokenAddress;
        address kdocTokenAddress;
        address wrbtcTokenAddress;
        address swapRouter02Address; // @notice NOT DEPLOYED ON RSK TESTNET!!
        address[] swapIntermediateTokens;
        uint24[] swapPoolFeeRates;
        address mocOracleAddress;
    }

    NetworkConfig internal activeNetworkConfig;

    event HelperConfig__CreatedMockDocToken(address docTokenAddress);
    event HelperConfig__CreatedMockKdocToken(address kdocTokenAddress);
    event HelperConfig__CreatedMockWrbtc(address wrbtcTokenAddress);
    event HelperConfig__CreatedMockSwapRouter02(address swapRouter02Address);
    event HelperConfig__CreatedMockMocOracle(address mocOracleAddress);

    constructor() {
        if (block.chainid == 31) {
            activeNetworkConfig = getRootstockTestnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
        // else if Sepolia y RSK
    }

    // 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab WRBTC - RSK TESTNET
    // 0x4D5a316D23eBE168d8f887b4447bf8DbFA4901CC rUSDT - RSK TESTNET
    function getRootstockTestnetConfig() public pure returns (NetworkConfig memory RootstockTestnetNetworkConfig) {
        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = 0x4d5A316d23EBe168D8f887b4447BF8DBfA4901cc; // Address of the rUSDT token in Rootstock testnet

        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 500;
        poolFeeRates[1] = 500;

        RootstockTestnetNetworkConfig = NetworkConfig({
            docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
            kdocTokenAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914, // Address of the kDOC proxy contract in Rootstock testnet
            wrbtcTokenAddress: 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab, // Address of the WRBTC token in Rootstock testnet
            swapRouter02Address: 0x0000000000000000000000000000000000000000, // TODO: Deploy a mock router on RSK testnet?
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracleAddress: 0x0000000000000000000000000000000000000000
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we already have an active network config
        if (activeNetworkConfig.docTokenAddress != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockDocToken mockDocToken = new MockDocToken(msg.sender);
        MockKdocToken mockKdocToken = new MockKdocToken(msg.sender, address(mockDocToken));
        MockWrbtcToken mockWrbtcToken = new MockWrbtcToken();
        MockSwapRouter02 mockSwapRouter02 = new MockSwapRouter02(BTC_PRICE);
        MockMocOracle mockMocOracle = new MockMocOracle();
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockDocToken(address(mockDocToken));
        emit HelperConfig__CreatedMockKdocToken(address(mockKdocToken));
        emit HelperConfig__CreatedMockWrbtc(address(mockWrbtcToken));
        emit HelperConfig__CreatedMockSwapRouter02(address(mockSwapRouter02));
        emit HelperConfig__CreatedMockMocOracle(address(mockMocOracle));

        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = 0x4d5A316d23EBe168D8f887b4447BF8DBfA4901cc; // dummy address

        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 500;
        poolFeeRates[1] = 500;

        anvilNetworkConfig = NetworkConfig({
            docTokenAddress: address(mockDocToken),
            kdocTokenAddress: address(mockKdocToken),
            wrbtcTokenAddress: address(mockWrbtcToken),
            swapRouter02Address: address(mockSwapRouter02),
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracleAddress: address(mockMocOracle)
        });
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    // MAINNET CONTRACTS
    // DOC: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db
    // rUSDT: 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96
    // WRBTC: 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d
}
