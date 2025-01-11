// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DexHelperConfig} from "./DexHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
// import {TropykusDocHandlerDex} from "../src/TropykusDocHandlerDex.sol";
// import {SovrynDocHandlerDex} from "../src/SovrynDocHandlerDex.sol";
import {IUniswapPurchase} from "../src/interfaces/IUniswapPurchase.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
// import {ISwapRouter02} from "../src/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {ITokenHandler} from "../src/interfaces/ITokenHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployDexSwaps is Script {
    address OWNER = makeAddr(OWNER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address docHandlerDexAddress;

    function run() external returns (AdminOperations, address, DcaManager, DexHelperConfig) {
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
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            // TropykusDocHandlerDex docHandlerDex = new TropykusDocHandlerDex(
            //     address(dcaManager),
            //     docToken,
            //     kDocToken,
            //     IUniswapPurchase.UniswapSettings({
            //         wrBtcToken: IWRBTC(wrBtcToken),
            //         swapRouter02: ISwapRouter02(swapRouter02),
            //         swapIntermediateTokens: swapIntermediateTokens,
            //         swapPoolFeeRates: swapPoolFeeRates,
            //         mocOracle: ICoinPairPrice(mocOracle)
            //     }),
            //     MIN_PURCHASE_AMOUNT,
            //     FEE_COLLECTOR,
            //     ITokenHandler.FeeSettings({
            //         minFeeRate: MIN_FEE_RATE,
            //         maxFeeRate: MAX_FEE_RATE,
            //         minAnnualAmount: MIN_ANNUAL_AMOUNT,
            //         maxAnnualAmount: MAX_ANNUAL_AMOUNT
            //     }),
            //     DOC_YIELDS_INTEREST // TODO: remove this paramter!!
            // );
            // docHandlerDexAddress = address(docHandlerDex);
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            // SovrynDocHandlerDex docHandlerDex = new SovrynDocHandlerDex(
            //     address(dcaManager),
            //     docToken,
            //     kDocToken,
            //     IUniswapPurchase.UniswapSettings({
            //         wrBtcToken: IWRBTC(wrBtcToken),
            //         swapRouter02: ISwapRouter02(swapRouter02),
            //         swapIntermediateTokens: swapIntermediateTokens,
            //         swapPoolFeeRates: swapPoolFeeRates,
            //         mocOracle: ICoinPairPrice(mocOracle)
            //     }),
            //     MIN_PURCHASE_AMOUNT,
            //     FEE_COLLECTOR,
            //     ITokenHandler.FeeSettings({
            //         minFeeRate: MIN_FEE_RATE,
            //         maxFeeRate: MAX_FEE_RATE,
            //         minAnnualAmount: MIN_ANNUAL_AMOUNT,
            //         maxAnnualAmount: MAX_ANNUAL_AMOUNT
            //     }),
            //     DOC_YIELDS_INTEREST // TODO: remove this paramter!!
            // );
            // docHandlerDexAddress = address(docHandlerDex);
        } else {
            revert("Invalid lending protocol");
        }

        // For local tests:
        if (block.chainid == 31337) {
            dcaManager.transferOwnership(OWNER); // Only for tests!!!
            adminOperations.transferOwnership(OWNER); // Only for tests!!!
            Ownable(docHandlerDexAddress).transferOwnership(OWNER); // Only for tests!!!
        }

        // For back-end and front-end devs to test:
        // rbtcDca.transferOwnership(0x8191c3a9DF486A09d8087E99A1b2b6885Cc17214); // Carlos
        // rbtcDca.transferOwnership(0x03B1E454F902771A7071335f44042A3233836BB3); // Pau

        vm.stopBroadcast();
        return (adminOperations, docHandlerDexAddress, dcaManager, helperConfig);
    }
}
