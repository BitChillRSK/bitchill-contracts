// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {MockDocToken} from "../test/mocks/MockDocToken.sol";
import {MockKdocToken} from "../test/mocks/MockKdocToken.sol";
import {MockIsusdToken} from "../test/mocks/MockIsusdToken.sol";
import {MockMocProxy} from "../test/mocks/MockMocProxy.sol";
import {MockWrbtcToken} from "../test/mocks/MockWrbtcToken.sol";
import {MockSwapRouter02} from "../test/mocks/MockSwapRouter02.sol";
import {MockMocOracle} from "../test/mocks/MockMocOracle.sol";
import "../test/Constants.sol";
import {Script} from "forge-std/Script.sol";

contract DexHelperConfig is Script {
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address mockLendingTokenAddress;
    bool lendingProtocolIsTropykus =
        keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"));
    bool lendingProtocolIsSovryn = keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"));

    struct NetworkConfig {
        address docTokenAddress;
        address kDocAddress;
        address iSusdAddress;
        address wrbtcTokenAddress;
        address swapRouter02Address; // @notice NOT DEPLOYED ON RSK TESTNET!!
        address[] swapIntermediateTokens;
        uint24[] swapPoolFeeRates;
        address mocOracleAddress;
        address mocProxyAddress; // @notice: needed only for fork testing, where we need to call MoC::mintDoc()
        uint256 amountOutMinimumPercent;
        uint256 amountOutMinimumSafetyCheck;
    }

    NetworkConfig internal activeNetworkConfig;

    event HelperConfig__CreatedMockDocToken(address docTokenAddress);
    // event HelperConfig__CreatedMockKdocToken(address kDocAddress);
    event HelperConfig__CreatedMockLendingToken(address lendingTokenAddress);
    event HelperConfig__CreatedMockWrbtc(address wrbtcTokenAddress);
    event HelperConfig__CreatedMockSwapRouter02(address swapRouter02Address);
    event HelperConfig__CreatedMockMocOracle(address mocOracleAddress);
    event HelperConfig__CreatedMockMocProxy(address mocProxyAddress);

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

    // 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab WRBTC - RSK TESTNET
    // 0x4D5aRSK_TESTNET_CHAIN_ID6D23eBE168d8f887b4447bf8DbFA4901CC rUSDT - RSK TESTNET
    function getRootstockTestnetConfig() public pure returns (NetworkConfig memory RootstockTestnetNetworkConfig) {
        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = 0x4d5A316d23EBe168D8f887b4447BF8DBfA4901cc; // Address of the rUSDT token in Rootstock testnet

        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 500;
        poolFeeRates[1] = 500;

        RootstockTestnetNetworkConfig = NetworkConfig({
            docTokenAddress: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0, // Address of the DOC token contract in Rootstock testnet
            kDocAddress: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914, // Address of the kDOC proxy contract in Rootstock testnet
            iSusdAddress: 0x74e00A8CeDdC752074aad367785bFae7034ed89f, // Address of the iSusd proxy contract in Rootstock testnet
            wrbtcTokenAddress: 0x69FE5cEC81D5eF92600c1A0dB1F11986AB3758Ab, // Address of the WRBTC token in Rootstock testnet
            swapRouter02Address: 0x0000000000000000000000000000000000000000, // Uniswap's contracts are not deployed on RSK testnet
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracleAddress: 0x0000000000000000000000000000000000000000,
            mocProxyAddress: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F,
            amountOutMinimumPercent: DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT,
            amountOutMinimumSafetyCheck: DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK
        });
    }

    function getRootstockMainnetConfig() public pure returns (NetworkConfig memory RootstockMainnetNetworkConfig) {
        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96; // Address of the rUSDT token in Rootstock testnet

        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 500;
        poolFeeRates[1] = 500;

        RootstockMainnetNetworkConfig = NetworkConfig({
            docTokenAddress: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // Address of the DOC token contract in Rootstock mainnet
            kDocAddress: 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2, // Address of the kDOC proxy contract in Rootstock mainnet
            iSusdAddress: 0xd8D25f03EBbA94E15Df2eD4d6D38276B595593c1, // Address of the iSusd proxy contract in Rootstock mainnet
            wrbtcTokenAddress: 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d, // Address of the WRBTC token in Rootstock mainnet
            swapRouter02Address: 0x0B14ff67f0014046b4b99057Aec4509640b3947A, 
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracleAddress: 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD,
            mocProxyAddress: 0xf773B590aF754D597770937Fa8ea7AbDf2668370,
            amountOutMinimumPercent: DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT,
            amountOutMinimumSafetyCheck: DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK
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

        if (lendingProtocolIsTropykus) {
            MockKdocToken mockLendingToken = new MockKdocToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else if (lendingProtocolIsSovryn) {
            MockIsusdToken mockLendingToken = new MockIsusdToken(address(mockDocToken));
            mockLendingTokenAddress = address(mockLendingToken);
        } else {
            revert("Invalid lending protocol");
        }

        // MockKdocToken mockKdocToken = new MockKdocToken(address(mockDocToken));
        MockWrbtcToken mockWrbtcToken = new MockWrbtcToken();
        MockSwapRouter02 mockSwapRouter02 = new MockSwapRouter02(mockWrbtcToken, BTC_PRICE);
        MockMocOracle mockMocOracle = new MockMocOracle();
        MockMocProxy mockMocProxy = new MockMocProxy(address(mockDocToken));
        
        // Only stop the broadcast if we started it
        if (!isBroadcasting) {
            vm.stopBroadcast();
        }

        emit HelperConfig__CreatedMockDocToken(address(mockDocToken));
        emit HelperConfig__CreatedMockLendingToken(mockLendingTokenAddress);
        emit HelperConfig__CreatedMockWrbtc(address(mockWrbtcToken));
        emit HelperConfig__CreatedMockSwapRouter02(address(mockSwapRouter02));
        emit HelperConfig__CreatedMockMocOracle(address(mockMocOracle));
        emit HelperConfig__CreatedMockMocProxy(address(mockMocProxy));

        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = makeAddr("rUSDT");

        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 500;
        poolFeeRates[1] = 500;

        if (lendingProtocolIsTropykus) {
            anvilNetworkConfig = NetworkConfig({
                docTokenAddress: address(mockDocToken),
                kDocAddress: mockLendingTokenAddress,
                iSusdAddress: address(0),
                wrbtcTokenAddress: address(mockWrbtcToken),
                swapRouter02Address: address(mockSwapRouter02),
                swapIntermediateTokens: intermediateTokens,
                swapPoolFeeRates: poolFeeRates,
                mocOracleAddress: address(mockMocOracle),
                mocProxyAddress: address(mockMocProxy),
                amountOutMinimumPercent: DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT,
                amountOutMinimumSafetyCheck: DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK
            });
        } else if (lendingProtocolIsSovryn) {
            anvilNetworkConfig = NetworkConfig({
                docTokenAddress: address(mockDocToken),
                kDocAddress: address(0),
                iSusdAddress: mockLendingTokenAddress,
                wrbtcTokenAddress: address(mockWrbtcToken),
                swapRouter02Address: address(mockSwapRouter02),
                swapIntermediateTokens: intermediateTokens,
                swapPoolFeeRates: poolFeeRates,
                mocOracleAddress: address(mockMocOracle),
                mocProxyAddress: address(mockMocProxy),
                amountOutMinimumPercent: DEFAULT_AMOUNT_OUT_MINIMUM_PERCENT,
                amountOutMinimumSafetyCheck: DEFAULT_AMOUNT_OUT_MINIMUM_SAFETY_CHECK
            });
        }
    }

    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    // MAINNET CONTRACTS
    // DOC: 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db
    // rUSDT: 0xef213441A85dF4d7ACbDaE0Cf78004e1E486bB96
    // WRBTC: 0x542fDA317318eBF1d3DEAf76E0b632741A7e677d
}
