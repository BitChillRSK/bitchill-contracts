// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployBase} from "./DeployBase.s.sol";
import {UsdrifHelperConfig} from "./UsdrifHelperConfig.s.sol";
import {TropykusErc20HandlerDex} from "../src/TropykusErc20HandlerDex.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IUniswapPurchase} from "../src/interfaces/IUniswapPurchase.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployUsdrifHandler is DeployBase {
    function run(UsdrifHelperConfig existingConfig) external returns (address) {
        // Use the provided config or create a new one if not provided
        UsdrifHelperConfig helperConfig = existingConfig != UsdrifHelperConfig(address(0)) 
            ? existingConfig 
            : new UsdrifHelperConfig();
        
        UsdrifHelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        
        // Validate addresses
        if (networkConfig.adminOperationsAddress == address(0) || networkConfig.dcaManagerAddress == address(0)) {
            revert("AdminOperations and DcaManager addresses must be set in UsdrifHelperConfig");
        }
        
        console.log("AdminOperations address:", networkConfig.adminOperationsAddress);
        console.log("DcaManager address:", networkConfig.dcaManagerAddress);
        
        vm.startBroadcast();
        
        // Get fee collector address
        address feeCollector = getFeeCollector(environment);
        
        // Set up Uniswap settings
        IUniswapPurchase.UniswapSettings memory uniswapSettings = IUniswapPurchase.UniswapSettings({
            wrBtcToken: IWRBTC(networkConfig.wrbtcTokenAddress),
            swapRouter02: ISwapRouter02(networkConfig.swapRouter02Address),
            swapIntermediateTokens: networkConfig.swapIntermediateTokens,
            swapPoolFeeRates: networkConfig.swapPoolFeeRates,
            mocOracle: ICoinPairPrice(networkConfig.mocOracleAddress)
        });
        
        // Set up fee settings
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE,
            minAnnualAmount: MIN_ANNUAL_AMOUNT,
            maxAnnualAmount: MAX_ANNUAL_AMOUNT
        });
        
        // Deploy the USDRIF handler
        TropykusErc20HandlerDex usdrifHandler = new TropykusErc20HandlerDex(
            networkConfig.dcaManagerAddress,
            networkConfig.usdrifTokenAddress,
            networkConfig.kUsdrifTokenAddress,
            uniswapSettings,
            MIN_PURCHASE_AMOUNT,
            feeCollector,
            feeSettings
        );
        
        console.log("USDRIF handler deployed at:", address(usdrifHandler));
        
        // Register the handler with AdminOperations
        AdminOperations adminOperations = AdminOperations(networkConfig.adminOperationsAddress);
        bool isAdmin = adminOperations.hasRole(keccak256("ADMIN"), msg.sender);
        
        if (!isAdmin) {
            console.log("Warning: Deployer is not an admin. Cannot register handler.");
            console.log("Please call adminOperations.assignOrUpdateTokenHandler() manually with an admin account and parameters:");
            console.log("tokenAddress:", networkConfig.usdrifTokenAddress);
            console.log("index:", TROPYKUS_INDEX);
            console.log("handlerAddress:", address(usdrifHandler));
        } else {
            // Register the handler using the existing Tropykus index
            adminOperations.assignOrUpdateTokenHandler(
                networkConfig.usdrifTokenAddress,
                TROPYKUS_INDEX,
                address(usdrifHandler)
            );
            
            console.log("USDRIF handler registered with AdminOperations using Tropykus index", TROPYKUS_INDEX);
        }
        
        // Transfer ownership of the handler to the protocol owner
        address currentOwner = adminOperations.owner();
        usdrifHandler.transferOwnership(currentOwner);
        console.log("Handler ownership transferred to:", currentOwner);
        
        vm.stopBroadcast();
        
        return address(usdrifHandler);
    }
}
