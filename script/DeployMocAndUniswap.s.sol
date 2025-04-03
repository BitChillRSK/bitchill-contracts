// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployBase} from "./DeployBase.s.sol";
import {DeployMocSwaps} from "./DeployMocSwaps.s.sol";
import {DeployDexSwaps} from "./DeployDexSwaps.s.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DexHelperConfig} from "./DexHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {IUniswapPurchase} from "../src/interfaces/IUniswapPurchase.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployMocAndUniswap is DeployBase {
    // Define a struct to hold all deployment results
    struct DeployedContracts {
        // MoC contracts
        AdminOperations adOpsMoc;
        address handlerMoc;
        DcaManager dcaManMoc;
        MocHelperConfig helpConfMoc;
        
        // Uniswap contracts
        AdminOperations adOpsUni;
        address handlerUni;
        DcaManager dcaManUni;
        DexHelperConfig helpConfUni;
    }
    
    // Split the deployment into smaller functions to avoid stack too deep errors
    function deployMocContracts() 
        private 
        returns (
            AdminOperations adOpsMoc,
            address handlerMoc,
            DcaManager dcaManMoc,
            MocHelperConfig helpConfMoc
        ) 
    {
        helpConfMoc = new MocHelperConfig();
        (address docToken, address mocProxy, address kDocToken, address iSusdToken) = helpConfMoc.activeNetworkConfig();
        
        vm.startBroadcast();
        // Deploy admin operations and DCA manager
        adOpsMoc = new AdminOperations();
        dcaManMoc = new DcaManager(address(adOpsMoc));
        
        // Get fee collector address
        address feeCollector = getFeeCollector(environment);
        
        // Select lending token based on protocol
        address lendingToken = protocol == Protocol.TROPYKUS ? kDocToken : iSusdToken;

        vm.stopBroadcast();

        // Deploy MoC handler
        DeployMocSwaps deployMocSwapContracts = new DeployMocSwaps();
        handlerMoc = deployMocSwapContracts.deployDocHandlerMoc(
            protocol, address(dcaManMoc), docToken, lendingToken, mocProxy, feeCollector
        );
        console.log("MoC handler deployed at:", handlerMoc);
        
        // Get owner address based on environment
        address owner = adminAddresses[environment];
        
        vm.startBroadcast();

        // Transfer ownership of contracts
        adOpsMoc.transferOwnership(owner);
        dcaManMoc.transferOwnership(owner);
        
        vm.stopBroadcast();
    }
    
    function deployUniswapContracts() 
        private 
        returns (
            AdminOperations adOpsUni,
            address handlerUni,
            DcaManager dcaManUni,
            DexHelperConfig helpConfUni
        ) 
    {
        helpConfUni = new DexHelperConfig();
        DexHelperConfig.NetworkConfig memory networkConfig = helpConfUni.getActiveNetworkConfig();
        
        vm.startBroadcast();
        // Deploy admin operations and DCA manager
        adOpsUni = new AdminOperations();
        dcaManUni = new DcaManager(address(adOpsUni));
        
        // Get fee collector address
        address feeCollector = getFeeCollector(environment);
        
        // Select lending token based on protocol
        address docToken = networkConfig.docTokenAddress;
        address lendingToken = protocol == Protocol.TROPYKUS ? networkConfig.kDocAddress : networkConfig.iSusdAddress;
        
        // Create Uniswap settings from the network config
        IUniswapPurchase.UniswapSettings memory uniswapSettings = IUniswapPurchase.UniswapSettings({
            wrBtcToken: IWRBTC(networkConfig.wrbtcTokenAddress),
            swapRouter02: ISwapRouter02(networkConfig.swapRouter02Address),
            swapIntermediateTokens: networkConfig.swapIntermediateTokens,
            swapPoolFeeRates: networkConfig.swapPoolFeeRates,
            mocOracle: ICoinPairPrice(networkConfig.mocOracleAddress)
        });
        
        vm.stopBroadcast();

        // Deploy Uniswap handler
        DeployDexSwaps deployDexSwapContracts = new DeployDexSwaps();
        handlerUni = deployDexSwapContracts.deployDocHandlerDex(
            protocol, 
            address(dcaManUni), 
            docToken, 
            lendingToken, 
            uniswapSettings, 
            feeCollector
        );
        console.log("Uniswap handler deployed at:", handlerUni);
        
        // Get owner address based on environment
        address owner = adminAddresses[environment];
        
        vm.startBroadcast();

        // Transfer ownership of contracts
        adOpsUni.transferOwnership(owner);
        dcaManUni.transferOwnership(owner);
        
        vm.stopBroadcast();
    }

    function run()
        external
        returns (DeployedContracts memory contracts)
    {
        console.log("Deploying both MoC and Uniswap handlers for comparison");
        
        // Deploy MoC contracts
        (contracts.adOpsMoc, contracts.handlerMoc, contracts.dcaManMoc, contracts.helpConfMoc) = deployMocContracts();
        
        // Deploy Uniswap contracts
        (contracts.adOpsUni, contracts.handlerUni, contracts.dcaManUni, contracts.helpConfUni) = deployUniswapContracts();
        
        return contracts;
    }
}
