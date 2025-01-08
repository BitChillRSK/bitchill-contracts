// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockDocToken} from "../test/mocks/MockDocToken.sol";
import {MockKdocToken} from "../test/mocks/MockKdocToken.sol";
import {MockIsusdToken} from "../test/mocks/MockIsusdToken.sol";
import {MockMocProxy} from "../test/mocks/MockMocProxy.sol";
import "../test/Constants.sol";
import {Script} from "forge-std/Script.sol";

contract MocHelperConfig is Script {
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address mockLendingTokenAddress;

    struct NetworkConfig {
        address docTokenAddress;
        address mocProxyAddress;
        address lendingTokenAddress;
    }

    NetworkConfig public activeNetworkConfig;

    event HelperConfig__CreatedMockDocToken(address docTokenAddress);
    event HelperConfig__CreatedMockMocProxy(address mocProxyAddress);
    event HelperConfig__CreatedMockLendingToken(address lendingTokenAddress);

    constructor() {
        if (block.chainid == 30) {
            activeNetworkConfig = getRootstockMainnetConfig();
        } else if (block.chainid == 31) {
            activeNetworkConfig = getRootstockTestnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
        // else if Sepolia y RSK
    }

    function getRootstockTestnetConfig() public view returns (NetworkConfig memory RootstockTestnetNetworkConfig) {
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            RootstockTestnetNetworkConfig = NetworkConfig({
                docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
                mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
                lendingTokenAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914 // Address of the kDOC proxy contract in Rootstock testnet
            });
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            RootstockTestnetNetworkConfig = NetworkConfig({
                docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
                mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
                lendingTokenAddress: 0x74e00A8CeDdC752074aad367785bFae7034ed89f // Address of the iSUSD proxy contract in Rootstock testnet
            });
        } else {
            revert("Invalid lending protocol");
        }
    }

    function getRootstockMainnetConfig() public view returns (NetworkConfig memory RootstockMainnetNetworkConfig) {
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            RootstockMainnetNetworkConfig = NetworkConfig({
                docTokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // Address of the DOC token contract in Rootstock mainnet
                mocProxyAddress: 0xf773B590aF754D597770937Fa8ea7AbDf2668370, // Address of the MoC proxy contract in Rootstock mainnet
                lendingTokenAddress: 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2 // Address of the kDOC proxy contract in Rootstock mainnet
            });
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            RootstockMainnetNetworkConfig = NetworkConfig({
                docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
                mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
                lendingTokenAddress: 0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1 // Address of the iSUSD proxy contract in Rootstock testnet
            });
        } else {
            revert("Invalid lending protocol");
        }
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we already have an active network config
        if (activeNetworkConfig.docTokenAddress != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockDocToken mockDocToken = new MockDocToken(msg.sender);
        MockMocProxy mockMocProxy = new MockMocProxy(address(mockDocToken));
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            MockKdocToken mockLendingToken = new MockKdocToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            MockIsusdToken mockLendingToken = new MockIsusdToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else {
            revert("Invalid lending protocol");
        }
        vm.stopBroadcast();

        emit HelperConfig__CreatedMockDocToken(address(mockDocToken));
        emit HelperConfig__CreatedMockMocProxy(address(mockMocProxy));
        emit HelperConfig__CreatedMockLendingToken(mockLendingTokenAddress);

        anvilNetworkConfig = NetworkConfig({
            docTokenAddress: address(mockDocToken),
            mocProxyAddress: address(mockMocProxy),
            lendingTokenAddress: mockLendingTokenAddress
        });
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    // MAINNET CONTRACTS
    // DOC: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db
    // rUSDT: 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96
    // WRBTC: 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d
    // Swap router 02: 0x0B14ff67f0014046b4b99057Aec4509640b3947A
}
