// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DeployMocAndUniswap} from "./DeployMocAndUniswap.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IDocHandler} from "../src/interfaces/IDocHandler.sol";
import {IPurchaseRbtc} from "../src/interfaces/IPurchaseRbtc.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DexHelperConfig} from "./DexHelperConfig.s.sol";
import {MockStablecoin} from "../test/mocks/MockStablecoin.sol";
import {MockMocProxy} from "../test/mocks/MockMocProxy.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract ComparePurchaseMethods is Script {
    // Constants for testing
    address USER = makeAddr(USER_STRING);
    address SWAPPER = makeAddr(SWAPPER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    address DUMMY_COMMISSION_RECEIVER = makeAddr("Dummy commission receiver");
    
    uint256 constant USER_TOTAL_AMOUNT = 20_000 ether; // 20000 DOC owned by the user in total
    uint256 constant AMOUNT_TO_DEPOSIT = 2000 ether; // 2000 DOC
    uint256 constant AMOUNT_TO_SPEND = 200 ether; // 200 DOC for periodical purchases
    uint256 constant MIN_PURCHASE_PERIOD = 1 days; // at most one purchase every day
    uint256 constant SCHEDULE_INDEX = 0;
    uint256 constant NUM_OF_SCHEDULES = 5;
    uint256 constant RBTC_TO_MINT_DOC = 0.2 ether; // Amount of rBTC to mint DOC

    // Mainnet addresses
    address mocOracleMainnet = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
    address mocInRateMainnet = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
    
    // Testnet addresses
    address mocOracleTestnet = 0xbffBD993FF1d229B0FfE55668F2009d20d4F7C5f;
    address mocInRateTestnet = 0x76790f846FAAf44cf1B2D717d0A6c5f6f5152B60;

    // Deployed contracts
    DeployMocAndUniswap.DeployedContracts deployedContracts;
    MockStablecoin stablecoin;
    MockMocProxy mocProxy;
    ICoinPairPrice mocOracle;
    uint256 btcPrice = BTC_PRICE;
    string stablecoinType;

    function run() external {
        console.log("Comparing MoC and Uniswap purchase methods");
        
        // Get stablecoin type (or use default if not specified)
        try vm.envString("STABLECOIN_TYPE") returns (string memory coinType) {
            stablecoinType = coinType;
        } catch {
            stablecoinType = DEFAULT_STABLECOIN;
        }
        
        // Deploy both implementations
        DeployMocAndUniswap deployer = new DeployMocAndUniswap();
        deployedContracts = deployer.run();
        
        // Get the network configuration
        MocHelperConfig.NetworkConfig memory networkConfig = deployedContracts.helpConfMoc.getActiveNetworkConfig();
        
        // Get the DOC token address
        address docTokenAddress = networkConfig.docTokenAddress;
        stablecoin = MockStablecoin(docTokenAddress);
        mocProxy = MockMocProxy(networkConfig.mocProxyAddress);
        
        // Setup: Mint stablecoin for the user and set roles
        setupEnvironment(networkConfig.mocProxyAddress);
        
        // Test 1: Compare single purchase
        compareSinglePurchase();
        
        // Test 2: Compare multiple purchases
        compareMultiplePurchases();
        
        // Test 3: Compare batch purchases
        compareBatchPurchases();
        
        // Print final comparison
        printFinalComparison();
    }
    
    function setupEnvironment(address mocProxyAddress) private {
        vm.startBroadcast();
        
        // Deal rBTC funds to user for minting stablecoin
        vm.deal(USER, 10 ether);
        
        // Mint stablecoin for the user based on the current environment
        if (block.chainid == ANVIL_CHAIN_ID) {
            // Local tests - use mock contracts
            console.log("Setting up local environment");
            
            // Deal rBTC funds to MoC contract
            vm.deal(mocProxyAddress, 1000 ether);
            
            // Mint stablecoin directly for the user
            stablecoin.mint(USER, USER_TOTAL_AMOUNT);
            
            // Give the MoC proxy contract allowance to move stablecoin from handlers
            vm.prank(deployedContracts.handlerMoc);
            stablecoin.approve(mocProxyAddress, type(uint256).max);
            
            vm.prank(deployedContracts.handlerUni);
            stablecoin.approve(mocProxyAddress, type(uint256).max);
            
        } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
            // Mainnet fork tests
            console.log("Setting up mainnet fork environment");
            
            // Fix the commission splitter address to avoid gas issues in Foundry
            vm.store(
                mocInRateMainnet,
                bytes32(uint256(214)),
                bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
            );
            
            // Mint stablecoin by sending rBTC to MoC
            vm.prank(USER);
            mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
            
            // Get BTC price from oracle
            mocOracle = ICoinPairPrice(mocOracleMainnet);
            btcPrice = mocOracle.getPrice() / 1e18;
            console.log("BTC price from mainnet oracle:", btcPrice);
            
        } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
            // Testnet fork tests
            console.log("Setting up testnet fork environment");
            
            // Fix the commission splitter address to avoid gas issues in Foundry
            vm.store(
                mocInRateTestnet,
                bytes32(uint256(214)),
                bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
            );
            
            // Mint stablecoin by sending rBTC to MoC
            vm.prank(USER);
            mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
            
            // Get BTC price from oracle
            mocOracle = ICoinPairPrice(mocOracleTestnet);
            btcPrice = mocOracle.getPrice() / 1e18;
            console.log("BTC price from testnet oracle:", btcPrice);
        }
        
        console.log("User stablecoin balance after minting:", stablecoin.balanceOf(USER) / 1e18);
        
        // Set up roles for both implementations
        deployedContracts.adOpsMoc.setSwapperRole(SWAPPER);
        deployedContracts.adOpsUni.setSwapperRole(SWAPPER);
        
        // Create DCA schedules for MoC implementation
        vm.startPrank(USER);
        stablecoin.approve(deployedContracts.handlerMoc, AMOUNT_TO_DEPOSIT);
        deployedContracts.dcaManMoc.createDcaSchedule(
            address(stablecoin), AMOUNT_TO_DEPOSIT, AMOUNT_TO_SPEND, MIN_PURCHASE_PERIOD, TROPYKUS_INDEX
        );
        vm.stopPrank();
        
        // Create DCA schedules for Uniswap implementation
        vm.startPrank(USER);
        stablecoin.approve(deployedContracts.handlerUni, AMOUNT_TO_DEPOSIT);
        deployedContracts.dcaManUni.createDcaSchedule(
            address(stablecoin), AMOUNT_TO_DEPOSIT, AMOUNT_TO_SPEND, MIN_PURCHASE_PERIOD, TROPYKUS_INDEX
        );
        vm.stopPrank();
        
        vm.stopBroadcast();
        
        console.log("Environment setup complete");
        console.log("User stablecoin balance after setup:", stablecoin.balanceOf(USER) / 1e18);
    }
    
    function compareSinglePurchase() private {
        console.log("\n=== COMPARING SINGLE PURCHASE ===");
        
        // Get schedule IDs
        bytes32 mocScheduleId = deployedContracts.dcaManMoc.getScheduleId(address(stablecoin), SCHEDULE_INDEX);
        bytes32 uniScheduleId = deployedContracts.dcaManUni.getScheduleId(address(stablecoin), SCHEDULE_INDEX);
        
        // Record balances before purchase
        uint256 mocDocBalanceBefore = deployedContracts.dcaManMoc.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 uniDocBalanceBefore = deployedContracts.dcaManUni.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 mocRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Execute MoC purchase
        uint256 mocGasStart = gasleft();
        vm.prank(SWAPPER);
        deployedContracts.dcaManMoc.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, mocScheduleId);
        uint256 mocGasUsed = mocGasStart - gasleft();
        
        // Execute Uniswap purchase
        uint256 uniGasStart = gasleft();
        vm.prank(SWAPPER);
        deployedContracts.dcaManUni.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, uniScheduleId);
        uint256 uniGasUsed = uniGasStart - gasleft();
        
        // Record balances after purchase
        uint256 mocDocBalanceAfter = deployedContracts.dcaManMoc.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 uniDocBalanceAfter = deployedContracts.dcaManUni.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 mocRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Calculate differences
        uint256 mocDocSpent = mocDocBalanceBefore - mocDocBalanceAfter;
        uint256 uniDocSpent = uniDocBalanceBefore - uniDocBalanceAfter;
        uint256 mocRbtcGained = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
        uint256 uniRbtcGained = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
        // Print results
        console.log("MoC Purchase:");
        console.log("  Gas used:", mocGasUsed);
        console.log("  Stablecoin spent:", mocDocSpent / 1e18);
        console.log("  rBTC gained:", mocRbtcGained / 1e18, ".", (mocRbtcGained % 1e18) / 1e15);
        
        console.log("Uniswap Purchase:");
        console.log("  Gas used:", uniGasUsed);
        console.log("  Stablecoin spent:", uniDocSpent / 1e18);
        console.log("  rBTC gained:", uniRbtcGained / 1e18, ".", (uniRbtcGained % 1e18) / 1e15);
        
        // Compare efficiency
        if (mocRbtcGained > uniRbtcGained) {
            console.log("MoC is more efficient by", ((mocRbtcGained - uniRbtcGained) * 100) / uniRbtcGained, "% in rBTC returns");
        } else if (uniRbtcGained > mocRbtcGained) {
            console.log("Uniswap is more efficient by", ((uniRbtcGained - mocRbtcGained) * 100) / mocRbtcGained, "% in rBTC returns");
        } else {
            console.log("Both methods have equal efficiency in rBTC returns");
        }
        
        if (mocGasUsed < uniGasUsed) {
            console.log("MoC uses less gas by", ((uniGasUsed - mocGasUsed) * 100) / uniGasUsed, "%");
        } else if (uniGasUsed < mocGasUsed) {
            console.log("Uniswap uses less gas by", ((mocGasUsed - uniGasUsed) * 100) / mocGasUsed, "%");
        } else {
            console.log("Both methods use the same amount of gas");
        }
    }
    
    function compareMultiplePurchases() private {
        console.log("\n=== COMPARING MULTIPLE PURCHASES ===");
        
        // Create multiple schedules for both implementations
        createMultipleSchedules(deployedContracts.dcaManMoc, deployedContracts.handlerMoc);
        createMultipleSchedules(deployedContracts.dcaManUni, deployedContracts.handlerUni);
        
        // Record balances before purchases
        uint256 mocRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Execute multiple purchases for MoC
        uint256 mocGasStart = gasleft();
        executeMultiplePurchases(deployedContracts.dcaManMoc);
        uint256 mocGasUsed = mocGasStart - gasleft();
        
        // Execute multiple purchases for Uniswap
        uint256 uniGasStart = gasleft();
        executeMultiplePurchases(deployedContracts.dcaManUni);
        uint256 uniGasUsed = uniGasStart - gasleft();
        
        // Record balances after purchases
        uint256 mocRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Calculate differences
        uint256 mocRbtcGained = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
        uint256 uniRbtcGained = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
        // Print results
        console.log("MoC Multiple Purchases:");
        console.log("  Total gas used:", mocGasUsed);
        console.log("  Total rBTC gained:", mocRbtcGained / 1e18, ".", (mocRbtcGained % 1e18) / 1e15);
        
        console.log("Uniswap Multiple Purchases:");
        console.log("  Total gas used:", uniGasUsed);
        console.log("  Total rBTC gained:", uniRbtcGained / 1e18, ".", (uniRbtcGained % 1e18) / 1e15);
        
        // Compare efficiency
        if (mocRbtcGained > uniRbtcGained) {
            console.log("MoC is more efficient by", ((mocRbtcGained - uniRbtcGained) * 100) / uniRbtcGained, "% in rBTC returns");
        } else if (uniRbtcGained > mocRbtcGained) {
            console.log("Uniswap is more efficient by", ((uniRbtcGained - mocRbtcGained) * 100) / mocRbtcGained, "% in rBTC returns");
        } else {
            console.log("Both methods have equal efficiency in rBTC returns");
        }
        
        if (mocGasUsed < uniGasUsed) {
            console.log("MoC uses less gas by", ((uniGasUsed - mocGasUsed) * 100) / uniGasUsed, "%");
        } else if (uniGasUsed < mocGasUsed) {
            console.log("Uniswap uses less gas by", ((mocGasUsed - uniGasUsed) * 100) / mocGasUsed, "%");
        } else {
            console.log("Both methods use the same amount of gas");
        }
    }
    
    function compareBatchPurchases() private {
        console.log("\n=== COMPARING BATCH PURCHASES ===");
        
        // Prepare batch purchase data
        address[] memory users = new address[](NUM_OF_SCHEDULES);
        uint256[] memory scheduleIndexes = new uint256[](NUM_OF_SCHEDULES);
        bytes32[] memory mocScheduleIds = new bytes32[](NUM_OF_SCHEDULES);
        bytes32[] memory uniScheduleIds = new bytes32[](NUM_OF_SCHEDULES);
        uint256[] memory purchaseAmounts = new uint256[](NUM_OF_SCHEDULES);
        uint256[] memory purchasePeriods = new uint256[](NUM_OF_SCHEDULES);
        
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
            users[i] = USER;
            scheduleIndexes[i] = i;
            mocScheduleIds[i] = deployedContracts.dcaManMoc.getScheduleId(address(stablecoin), i);
            uniScheduleIds[i] = deployedContracts.dcaManUni.getScheduleId(address(stablecoin), i);
            purchaseAmounts[i] = AMOUNT_TO_SPEND / NUM_OF_SCHEDULES;
            purchasePeriods[i] = MIN_PURCHASE_PERIOD + i * 5 days;
        }
        
        // Record balances before batch purchases
        uint256 mocRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceBefore = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Execute MoC batch purchase
        uint256 mocGasStart = gasleft();
        vm.prank(SWAPPER);
        deployedContracts.dcaManMoc.batchBuyRbtc(
            users,
            address(stablecoin),
            scheduleIndexes,
            mocScheduleIds,
            purchaseAmounts,
            TROPYKUS_INDEX
        );
        uint256 mocGasUsed = mocGasStart - gasleft();
        
        // Execute Uniswap batch purchase
        uint256 uniGasStart = gasleft();
        vm.prank(SWAPPER);
        deployedContracts.dcaManUni.batchBuyRbtc(
            users,
            address(stablecoin),
            scheduleIndexes,
            uniScheduleIds,
            purchaseAmounts,
            TROPYKUS_INDEX
        );
        uint256 uniGasUsed = uniGasStart - gasleft();
        
        // Record balances after batch purchases
        uint256 mocRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalanceAfter = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        // Calculate differences
        uint256 mocRbtcGained = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
        uint256 uniRbtcGained = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
        // Print results
        console.log("MoC Batch Purchase:");
        console.log("  Gas used:", mocGasUsed);
        console.log("  rBTC gained:", mocRbtcGained / 1e18, ".", (mocRbtcGained % 1e18) / 1e15);
        
        console.log("Uniswap Batch Purchase:");
        console.log("  Gas used:", uniGasUsed);
        console.log("  rBTC gained:", uniRbtcGained / 1e18, ".", (uniRbtcGained % 1e18) / 1e15);
        
        // Compare efficiency
        if (mocRbtcGained > uniRbtcGained) {
            console.log("MoC is more efficient by", ((mocRbtcGained - uniRbtcGained) * 100) / uniRbtcGained, "% in rBTC returns");
        } else if (uniRbtcGained > mocRbtcGained) {
            console.log("Uniswap is more efficient by", ((uniRbtcGained - mocRbtcGained) * 100) / mocRbtcGained, "% in rBTC returns");
        } else {
            console.log("Both methods have equal efficiency in rBTC returns");
        }
        
        if (mocGasUsed < uniGasUsed) {
            console.log("MoC uses less gas by", ((uniGasUsed - mocGasUsed) * 100) / uniGasUsed, "%");
        } else if (uniGasUsed < mocGasUsed) {
            console.log("Uniswap uses less gas by", ((mocGasUsed - uniGasUsed) * 100) / mocGasUsed, "%");
        } else {
            console.log("Both methods use the same amount of gas");
        }
    }
    
    function createMultipleSchedules(DcaManager dcaManager, address handler) private {
        vm.startBroadcast();
        
        // Delete the initial schedule to start fresh
        bytes32 initialScheduleId = dcaManager.getScheduleId(address(stablecoin), SCHEDULE_INDEX);
        vm.prank(USER);
        dcaManager.deleteDcaSchedule(address(stablecoin), initialScheduleId);
        
        // Create multiple schedules with different parameters
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
            uint256 docToDeposit = AMOUNT_TO_DEPOSIT / NUM_OF_SCHEDULES;
            uint256 purchaseAmount = AMOUNT_TO_SPEND / NUM_OF_SCHEDULES;
            uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
            
            vm.startPrank(USER);
            stablecoin.approve(handler, docToDeposit);
            dcaManager.createDcaSchedule(
                address(stablecoin), docToDeposit, purchaseAmount, purchasePeriod, TROPYKUS_INDEX
            );
            vm.stopPrank();
        }
        
        vm.stopBroadcast();
    }
    
    function executeMultiplePurchases(DcaManager dcaManager) private {
        vm.startBroadcast();
        
        // Execute purchases for each schedule
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
            bytes32 scheduleId = dcaManager.getScheduleId(address(stablecoin), i);
            vm.prank(SWAPPER);
            dcaManager.buyRbtc(USER, address(stablecoin), i, scheduleId);
            
            // Advance time for the next purchase
            vm.warp(block.timestamp + MIN_PURCHASE_PERIOD);
        }
        
        vm.stopBroadcast();
    }
    
    function printFinalComparison() private view {
        console.log("\n=== FINAL COMPARISON ===");
        console.log("MoC final rBTC balance:", IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance() / 1e18);
        console.log("Uniswap final rBTC balance:", IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance() / 1e18);
        
        uint256 mocRbtcBalance = IPurchaseRbtc(deployedContracts.handlerMoc).getAccumulatedRbtcBalance();
        uint256 uniRbtcBalance = IPurchaseRbtc(deployedContracts.handlerUni).getAccumulatedRbtcBalance();
        
        if (mocRbtcBalance > uniRbtcBalance) {
            console.log("Overall, MoC provided better returns by", 
                ((mocRbtcBalance - uniRbtcBalance) * 100) / uniRbtcBalance, "%");
        } else if (uniRbtcBalance > mocRbtcBalance) {
            console.log("Overall, Uniswap provided better returns by", 
                ((uniRbtcBalance - mocRbtcBalance) * 100) / mocRbtcBalance, "%");
        } else {
            console.log("Both methods provided equal returns");
        }
    }
}
