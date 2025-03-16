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
    bool lendingProtocolIsTropykus =
        keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"));
    bool lendingProtocolIsSovryn = keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"));

    struct NetworkConfig {
        address docTokenAddress;
        address mocProxyAddress;
        // address lendingTokenAddress;
        address kDocAddress;
        address iSusdAddress;
    }

    NetworkConfig public activeNetworkConfig;

    event HelperConfig__CreatedMockDocToken(address docTokenAddress);
    event HelperConfig__CreatedMockMocProxy(address mocProxyAddress);
    event HelperConfig__CreatedMockLendingToken(address lendingTokenAddress);

    constructor() {
        if (block.chainid == RSK_MAINNET_CHAIN_ID) {
            activeNetworkConfig = getRootstockMainnetConfig();
        } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
            activeNetworkConfig = getRootstockTestnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
        // else if Sepolia y RSK
    }

    function getRootstockTestnetConfig() public pure returns (NetworkConfig memory RootstockTestnetNetworkConfig) {
        // if (lendingProtocolIsTropykus) {
        //     RootstockTestnetNetworkConfig = NetworkConfig({
        //         docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
        //         mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
        //         lendingTokenAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914 // Address of the kDOC proxy contract in Rootstock testnet
        //     });
        // } else if (lendingProtocolIsSovryn) {
        //     RootstockTestnetNetworkConfig = NetworkConfig({
        //         docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
        //         mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
        //         lendingTokenAddress: 0x74e00A8CeDdC752074aad367785bFae7034ed89f // Address of the iSUSD proxy contract in Rootstock testnet
        //     });
        // } else {
        //     revert("Invalid lending protocol");
        // }
        RootstockTestnetNetworkConfig = NetworkConfig({
            docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
            mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F, // Address of the MoC proxy contract in Rootstock testnet
            kDocAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914, // Address of the kDOC proxy contract in Rootstock testnet
            iSusdAddress: 0x74e00A8CeDdC752074aad367785bFae7034ed89f // Address of the iSUSD proxy contract in Rootstock testnet
        });
    }

    function getRootstockMainnetConfig() public pure returns (NetworkConfig memory RootstockMainnetNetworkConfig) {
        // if (lendingProtocolIsTropykus) {
        //     RootstockMainnetNetworkConfig = NetworkConfig({
        //         docTokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // Address of the DOC token contract in Rootstock mainnet
        //         mocProxyAddress: 0xf773B590aF754D597770937Fa8ea7AbDf2668370, // Address of the MoC proxy contract in Rootstock mainnet
        //         lendingTokenAddress: 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2 // Address of the kDOC proxy contract in Rootstock mainnet
        //     });
        // } else if (lendingProtocolIsSovryn) {
        //     RootstockMainnetNetworkConfig = NetworkConfig({
        //         docTokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // Address of the DOC token contract in Rootstock mainnet
        //         mocProxyAddress: 0xf773B590aF754D597770937Fa8ea7AbDf2668370, // Address of the MoC proxy contract in Rootstock mainnet
        //         lendingTokenAddress: 0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1 // Address of the iSUSD proxy contract in Rootstock mainnet
        //     });
        // } else {
        //     revert("Invalid lending protocol");
        // }
        RootstockMainnetNetworkConfig = NetworkConfig({
            docTokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // Address of the DOC token contract in Rootstock testnet
            mocProxyAddress: 0xf773B590aF754D597770937Fa8ea7AbDf2668370, // Address of the MoC proxy contract in Rootstock testnet
            kDocAddress: 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2, // Address of the kDOC proxy contract in Rootstock testnet
            iSusdAddress: 0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1 // Address of the iSUSD proxy contract in Rootstock testnet
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        if (activeNetworkConfig.docTokenAddress != address(0)) {
            return activeNetworkConfig;
        }

        // Check if we're already in a broadcast context
        bool isBroadcasting;
        try vm.getNonce(msg.sender) returns (uint64) {
            // If this succeeds, we're already in a broadcast context
            isBroadcasting = true;
        } catch {
            // If it fails, we're not in a broadcast context
            isBroadcasting = false;
        }

        // Only start a broadcast if we're not already in one
        if (!isBroadcasting) {
            vm.startBroadcast();
        }
        
        MockDocToken mockDocToken = new MockDocToken(msg.sender);
        MockMocProxy mocProxy = new MockMocProxy(address(mockDocToken));
        if (lendingProtocolIsTropykus) {
            MockKdocToken mockLendingToken = new MockKdocToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else if (lendingProtocolIsSovryn) {
            MockIsusdToken mockLendingToken = new MockIsusdToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else {
            revert("Invalid lending protocol");
        }
        
        // Only stop the broadcast if we started it
        if (!isBroadcasting) {
            vm.stopBroadcast();
        }

        emit HelperConfig__CreatedMockDocToken(address(mockDocToken));
        emit HelperConfig__CreatedMockMocProxy(address(mocProxy));
        emit HelperConfig__CreatedMockLendingToken(mockLendingTokenAddress);

        if (lendingProtocolIsTropykus) {
            anvilNetworkConfig = NetworkConfig({
                docTokenAddress: address(mockDocToken),
                mocProxyAddress: address(mocProxy),
                kDocAddress: mockLendingTokenAddress,
                iSusdAddress: address(0)
            });
        } else if (lendingProtocolIsSovryn) {
            anvilNetworkConfig = NetworkConfig({
                docTokenAddress: address(mockDocToken),
                mocProxyAddress: address(mocProxy),
                kDocAddress: address(0),
                iSusdAddress: mockLendingTokenAddress
            });
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    // MAINNET CONTRACTS
    // DOC: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db
    // rUSDT: 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96
    // WRBTC: 0x542fDARSK_TESTNET_CHAIN_ID7RSK_TESTNET_CHAIN_ID8eBF1d3DEAf76E0b632741A7e677d
    // Swap router 02: 0x0B14ff67f0014046b4b99057Aec4509640b3947A
}
