// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DexHelperConfig} from "./DexHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {DocTokenHandlerDex} from "../src/DocTokenHandlerDex.sol";
import {IDocTokenHandlerDex} from "../src/interfaces/IDocTokenHandlerDex.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
// import {ISwapRouter02} from "../src/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {ITokenHandler} from "../src/interfaces/ITokenHandler.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployDexSwaps is Script {
    address OWNER = makeAddr(OWNER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);

    function run() external returns (AdminOperations, DocTokenHandlerDex, DcaManager, DexHelperConfig) {
        DexHelperConfig helperConfig = new DexHelperConfig();

        DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        address docToken = networkConfig.docTokenAddress;
        address kDocToken = networkConfig.kdocTokenAddress;
        address wrBtcToken = networkConfig.wrbtcTokenAddress;
        address swapRouter02 = networkConfig.swapRouter02Address;
        address[] memory swapIntermediateTokens = networkConfig.swapIntermediateTokens;
        uint24[] memory swapPoolFeeRates = networkConfig.swapPoolFeeRates;
        address mocOracle = networkConfig.mocOracleAddress;

        vm.startBroadcast();
        // After startBroadcast -> "real" tx
        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        DocTokenHandlerDex docTokenHandlerDex = new DocTokenHandlerDex(
            address(dcaManager),
            docToken,
            kDocToken,
            IDocTokenHandlerDex.UniswapSettings({
                wrBtcToken: IWRBTC(wrBtcToken),
                swapRouter02: ISwapRouter02(swapRouter02),
                swapIntermediateTokens: swapIntermediateTokens,
                swapPoolFeeRates: swapPoolFeeRates,
                mocOracle: ICoinPairPrice(mocOracle)
            }),
            MIN_PURCHASE_AMOUNT,
            FEE_COLLECTOR,
            ITokenHandler.FeeSettings({
                minFeeRate: MIN_FEE_RATE,
                maxFeeRate: MAX_FEE_RATE,
                minAnnualAmount: MIN_ANNUAL_AMOUNT,
                maxAnnualAmount: MAX_ANNUAL_AMOUNT
            }),
            DOC_YIELDS_INTEREST
        );

        // For local tests:
        if (block.chainid == 31337) {
            dcaManager.transferOwnership(OWNER); // Only for tests!!!
            adminOperations.transferOwnership(OWNER); // Only for tests!!!
            docTokenHandlerDex.transferOwnership(OWNER); // Only for tests!!!
        }

        // For back-end and front-end devs to test:
        // rbtcDca.transferOwnership(0x8191c3a9DF486A09d8087E99A1b2b6885Cc17214); // Carlos
        // rbtcDca.transferOwnership(0x03B1E454F902771A7071335f44042A3233836BB3); // Pau

        vm.stopBroadcast();
        return (adminOperations, docTokenHandlerDex, dcaManager, helperConfig);
    }
}
