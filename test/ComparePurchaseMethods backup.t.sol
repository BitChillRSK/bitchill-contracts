// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {Test, console2} from "forge-std/Test.sol";
// import {DeployMocAndUniswap} from "../script/DeployMocAndUniswap.s.sol";
// import {DcaManager} from "../src/DcaManager.sol";
// import {AdminOperations} from "../src/AdminOperations.sol";
// import {IDocHandler} from "../src/interfaces/IDocHandler.sol";
// import {IPurchaseRbtc} from "../src/interfaces/IPurchaseRbtc.sol";
// import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
// import {MocHelperConfig} from "../script/MocHelperConfig.s.sol";
// import {DexHelperConfig} from "../script/DexHelperConfig.s.sol";
// import {MockDocToken} from "../test/mocks/MockDocToken.sol";
// import {MockMocProxy} from "../test/mocks/MockMocProxy.sol";
// import {MockWrbtcToken} from "../test/mocks/MockWrbtcToken.sol";
// import "../test/Constants.sol";

// contract ComparePurchaseMethods is Test {
//     // Constants for testing
//     address USER = makeAddr(USER_STRING);
//     address SWAPPER = makeAddr(SWAPPER_STRING);
//     address OWNER = makeAddr(OWNER_STRING);
//     address ADMIN = makeAddr(ADMIN_STRING);
//     address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
//     address DUMMY_COMMISSION_RECEIVER = makeAddr("Dummy commission receiver");
    
//     // Testing constants
//     uint256 constant USER_TOTAL_DOC = 20_000 ether;
//     uint256 constant DOC_TO_DEPOSIT = 2000 ether;
//     uint256 constant DOC_TO_SPEND = 200 ether;
//     uint256 constant MIN_PURCHASE_PERIOD = 1 days;
//     uint256 constant SCHEDULE_INDEX = 0;
//     uint256 constant NUM_OF_SCHEDULES = 5;
//     uint256 constant RBTC_TO_MINT_DOC = 0.2 ether;

//     // Mainnet addresses
//     address constant MOC_ORACLE = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
//     address constant MOC_INRATE = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
    
//     // Deployed contracts
//     DeployMocAndUniswap.DeployedContracts deployedContracts;
    
//     // Common contracts
//     MockDocToken docToken;
    
//     // MoC-specific contracts
//     MockMocProxy mocProxy;
//     ICoinPairPrice mocOracle;
//     DcaManager dcaManMoc;
//     address handlerMoc;
    
//     // Uniswap-specific contracts
//     MockWrbtcToken wrbtcToken;
//     ICoinPairPrice priceOracle;  // Renamed from mocOracle to priceOracle for clarity
//     DcaManager dcaManUni;
//     address handlerUni;
    
//     // Protocol settings
//     uint256 lendingProtocolIndex;
//     uint256 btcPrice = BTC_PRICE;

//     function setUp() public {
//         console2.log("Setting up comparison test");
        
//         // Set lending protocol index based on environment variable
//         string memory lendingProtocol = vm.envString("LENDING_PROTOCOL");
//         if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
//             lendingProtocolIndex = TROPYKUS_INDEX;
//         } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
//             lendingProtocolIndex = SOVRYN_INDEX;
//         } else {
//             revert("Lending protocol not allowed");
//         }

//         // Deploy both implementations
//         DeployMocAndUniswap deployer = new DeployMocAndUniswap();
//         deployedContracts = deployer.run();
        
//         // Store references
//         dcaManMoc = deployedContracts.dcaManMoc;
//         handlerMoc = deployedContracts.handlerMoc;
//         dcaManUni = deployedContracts.dcaManUni;
//         handlerUni = deployedContracts.handlerUni;
        
//         // Get DOC and MoC proxy contracts
//         (address docTokenAddress, address mocProxyAddress,,) = deployedContracts.helpConfMoc.activeNetworkConfig();
//         docToken = MockDocToken(docTokenAddress);
//         mocProxy = MockMocProxy(mocProxyAddress);
        
//         // Get Uniswap-specific contracts
//         DexHelperConfig.NetworkConfig memory uniConfig = deployedContracts.helpConfUni.getActiveNetworkConfig();
//         wrbtcToken = MockWrbtcToken(uniConfig.wrbtcTokenAddress);
//         priceOracle = ICoinPairPrice(MOC_ORACLE);
        
//         // Set up the test environment
//         setupEnvironment();
        
//         console2.log("Comparison test setup complete");
//         console2.log("MoC handler at:", handlerMoc);
//         console2.log("Uniswap handler at:", handlerUni);
//     }
    
//     function setupEnvironment() private {
//         // Deal rBTC funds to user for minting DOC
//         vm.deal(USER, 10 ether);
        
//         // Fix the commission splitter address to avoid gas issues in Foundry
//         vm.store(
//             MOC_INRATE,
//             bytes32(uint256(214)),
//             bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//         );
        
//         // Mint DOC by sending rBTC to MoC
//         vm.prank(USER);
//         mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
        
//         // Get BTC price from oracle for Uniswap implementation
//         btcPrice = priceOracle.getPrice() / 1e18;
//         console2.log("BTC price from mainnet oracle:", btcPrice);
        
//         console2.log("User DOC balance after minting:", docToken.balanceOf(USER) / 1e18);
        
//         // Set up roles for both implementations
//         vm.startPrank(OWNER);
//         deployedContracts.adOpsMoc.setAdminRole(ADMIN);
//         deployedContracts.adOpsUni.setAdminRole(ADMIN);
//         vm.stopPrank();
        
//         vm.startPrank(ADMIN);
//         deployedContracts.adOpsMoc.setSwapperRole(SWAPPER);
//         deployedContracts.adOpsUni.setSwapperRole(SWAPPER);
//         deployedContracts.adOpsMoc.addOrUpdateLendingProtocol(TROPYKUS_STRING, 1);
//         deployedContracts.adOpsMoc.addOrUpdateLendingProtocol(SOVRYN_STRING, 2);
//         deployedContracts.adOpsUni.addOrUpdateLendingProtocol(TROPYKUS_STRING, 1);
//         deployedContracts.adOpsUni.addOrUpdateLendingProtocol(SOVRYN_STRING, 2);
//         deployedContracts.adOpsMoc.assignOrUpdateTokenHandler(address(docToken), lendingProtocolIndex, deployedContracts.handlerMoc);
//         deployedContracts.adOpsUni.assignOrUpdateTokenHandler(address(docToken), lendingProtocolIndex, deployedContracts.handlerUni);
//         vm.stopPrank();

//         // Create initial DCA schedules
//         vm.startPrank(USER);
//         docToken.approve(handlerMoc, DOC_TO_DEPOSIT);
//         dcaManMoc.createDcaSchedule(
//             address(docToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, lendingProtocolIndex
//         );
        
//         docToken.approve(handlerUni, DOC_TO_DEPOSIT);
//         dcaManUni.createDcaSchedule(
//             address(docToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, lendingProtocolIndex
//         );
//         vm.stopPrank();
        
//         console2.log("Environment setup complete");
//         console2.log("User DOC balance after setup:", docToken.balanceOf(USER) / 1e18);
//     }
    
//     function testCompareSwapMethods() public {
//         // Test 1: Compare single purchase
//         compareSinglePurchase();
        
//         // Test 2: Compare multiple purchases
//         compareMultiplePurchases();
        
//         // Test 3: Compare batch purchases
//         compareBatchPurchases();
        
//         // Print final comparison
//         printFinalComparison();
//     }
    
//     function compareSinglePurchase() private {
//         console2.log("\n=== COMPARING SINGLE PURCHASE ===");
        
//         // Get schedule IDs
//         vm.startPrank(USER);
//         bytes32 mocScheduleId = dcaManMoc.getScheduleId(address(docToken), SCHEDULE_INDEX);
//         bytes32 uniScheduleId = dcaManUni.getScheduleId(address(docToken), SCHEDULE_INDEX);
        
//         // Record balances before purchase
//         uint256 mocDocBalanceBefore = dcaManMoc.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
//         uint256 uniDocBalanceBefore = dcaManUni.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
//         uint256 mocRbtcBalanceBefore = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceBefore = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();
        
//         // Execute MoC purchase
//         uint256 mocGasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManMoc.buyRbtc(USER, address(docToken), SCHEDULE_INDEX, mocScheduleId);
//         uint256 mocGasUsed = mocGasStart - gasleft();
        
//         // Execute Uniswap purchase
//         uint256 uniGasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManUni.buyRbtc(USER, address(docToken), SCHEDULE_INDEX, uniScheduleId);
//         uint256 uniGasUsed = uniGasStart - gasleft();
        
//         // Record balances after purchase
//         vm.startPrank(USER);
//         uint256 mocDocBalanceAfter = dcaManMoc.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
//         uint256 uniDocBalanceAfter = dcaManUni.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
//         uint256 mocRbtcBalanceAfter = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceAfter = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();
//         // Calculate differences
//         uint256 mocDocSpent = mocDocBalanceBefore - mocDocBalanceAfter;
//         uint256 uniDocSpent = uniDocBalanceBefore - uniDocBalanceAfter;
//         uint256 mocRbtcPurchased = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
//         uint256 uniRbtcPurchased = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
//         // Print basic results
//         console2.log("MoC Purchase:");
//         console2.log("  Gas used:", mocGasUsed);
//         console2.log("  DOC spent:", mocDocSpent / 1e18);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(mocRbtcPurchased), mocRbtcPurchased / 1e10);
        
//         console2.log("Uniswap Purchase:");
//         console2.log("  Gas used:", uniGasUsed);
//         console2.log("  DOC spent:", uniDocSpent / 1e18);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(uniRbtcPurchased), uniRbtcPurchased / 1e10);
        
//         console2.log("\nDOC spent per method:", mocDocSpent / 1e18);
        
//         // Operational costs analysis (team perspective)
//         console2.log("\nOperational Costs Analysis (Team Perspective):");
//         console2.log("  Gas price (WEI):", tx.gasprice);
//         uint256 mocGasCostRbtc = mocGasUsed * tx.gasprice;
//         uint256 uniGasCostRbtc = uniGasUsed * tx.gasprice;
        
//         if (mocGasCostRbtc > uniGasCostRbtc) {
//             uint256 extraCostRbtc = mocGasCostRbtc - uniGasCostRbtc;
//             console2.log("MoC is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else if (uniGasCostRbtc > mocGasCostRbtc) {
//             uint256 extraCostRbtc = uniGasCostRbtc - mocGasCostRbtc;
//             console2.log("Uniswap is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else {
//             console2.log("Both methods have equal operational costs");
//         }

//         // User benefits analysis (user perspective)
//         console2.log("\nUser Benefits Analysis (User Perspective):");
//         if (mocRbtcPurchased > uniRbtcPurchased) {
//             uint256 extraRbtc = mocRbtcPurchased - uniRbtcPurchased;
//             console2.log("MoC provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else if (uniRbtcPurchased > mocRbtcPurchased) {
//             uint256 extraRbtc = uniRbtcPurchased - mocRbtcPurchased;
//             console2.log("Uniswap provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else {
//             console2.log("Both methods provide equal returns");
//         }
//     }
    
//     function compareMultiplePurchases() private {
//         console2.log("\n=== COMPARING MULTIPLE PURCHASES ===");
        
//         // Create multiple schedules for both implementations
//         createMultipleSchedules(dcaManMoc, handlerMoc);
//         createMultipleSchedules(dcaManUni, handlerUni);
        
//         // Record balances before purchases
//         vm.startPrank(USER);
//         uint256 mocRbtcBalanceBefore = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceBefore = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();

//         // Execute multiple purchases for MoC
//         uint256 mocGasStart = gasleft();
//         executeMultiplePurchases(dcaManMoc);
//         uint256 mocGasUsed = mocGasStart - gasleft();
        
//         // Execute multiple purchases for Uniswap
//         uint256 uniGasStart = gasleft();
//         executeMultiplePurchases(dcaManUni);
//         uint256 uniGasUsed = uniGasStart - gasleft();
        
//         // Record balances after purchases
//         vm.startPrank(USER);
//         uint256 mocRbtcBalanceAfter = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceAfter = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();
        
//         // Calculate differences
//         uint256 mocRbtcPurchased = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
//         uint256 uniRbtcPurchased = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
//         // Calculate actual DOC spent
//         uint256 docPerSchedule = DOC_TO_SPEND / NUM_OF_SCHEDULES;
//         uint256 totalDocSpent = docPerSchedule * NUM_OF_SCHEDULES;
//         console2.log("\nDOC spent per method:", totalDocSpent / 1e18);
        
//         // Print basic results
//         console2.log("MoC Multiple Purchases:");
//         console2.log("  Gas used:", mocGasUsed);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(mocRbtcPurchased), mocRbtcPurchased / 1e10);
        
//         console2.log("Uniswap Multiple Purchases:");
//         console2.log("  Gas used:", uniGasUsed);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(uniRbtcPurchased), uniRbtcPurchased / 1e10);
        
//         // Operational costs analysis (team perspective)
//         console2.log("\nOperational Costs Analysis (Team Perspective):");
//         console2.log("  Gas price (WEI):", tx.gasprice);
//         uint256 mocGasCostRbtc = mocGasUsed * tx.gasprice;
//         uint256 uniGasCostRbtc = uniGasUsed * tx.gasprice;
        
//         if (mocGasCostRbtc > uniGasCostRbtc) {
//             uint256 extraCostRbtc = mocGasCostRbtc - uniGasCostRbtc;
//             console2.log("MoC is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else if (uniGasCostRbtc > mocGasCostRbtc) {
//             uint256 extraCostRbtc = uniGasCostRbtc - mocGasCostRbtc;
//             console2.log("Uniswap is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else {
//             console2.log("Both methods have equal operational costs");
//         }

//         // User benefits analysis (user perspective)
//         console2.log("\nUser Benefits Analysis (User Perspective):");
//         if (mocRbtcPurchased > uniRbtcPurchased) {
//             uint256 extraRbtc = mocRbtcPurchased - uniRbtcPurchased;
//             console2.log("MoC provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else if (uniRbtcPurchased > mocRbtcPurchased) {
//             uint256 extraRbtc = uniRbtcPurchased - mocRbtcPurchased;
//             console2.log("Uniswap provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else {
//             console2.log("Both methods provide equal returns");
//         }
//     }
    
//     function compareBatchPurchases() private {
//         console2.log("\n=== COMPARING BATCH PURCHASES ===");
        
//         // Create multiple schedules for both implementations
//         createMultipleSchedules(dcaManMoc, handlerMoc);
//         createMultipleSchedules(dcaManUni, handlerUni);
        
//         // Prepare batch purchase data
//         address[] memory users = new address[](NUM_OF_SCHEDULES);
//         uint256[] memory scheduleIndexes = new uint256[](NUM_OF_SCHEDULES);
//         bytes32[] memory mocScheduleIds = new bytes32[](NUM_OF_SCHEDULES);
//         bytes32[] memory uniScheduleIds = new bytes32[](NUM_OF_SCHEDULES);
//         uint256[] memory purchaseAmounts = new uint256[](NUM_OF_SCHEDULES);
//         uint256[] memory purchasePeriods = new uint256[](NUM_OF_SCHEDULES);
        
//         // Fill arrays with correct data
//         for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
//             users[i] = USER;
//             scheduleIndexes[i] = i;
            
//             vm.startPrank(USER);
//             mocScheduleIds[i] = dcaManMoc.getScheduleId(address(docToken), i);
//             purchaseAmounts[i] = dcaManMoc.getSchedulePurchaseAmount(address(docToken), i);
//             purchasePeriods[i] = dcaManMoc.getSchedulePurchasePeriod(address(docToken), i);
//             uniScheduleIds[i] = dcaManUni.getScheduleId(address(docToken), i);
//             vm.stopPrank();
//         }
        
//         // Record balances before batch purchases
//         vm.startPrank(USER);
//         uint256 mocRbtcBalanceBefore = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceBefore = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();

//         // Execute MoC batch purchase
//         uint256 mocGasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManMoc.batchBuyRbtc(
//             users,
//             address(docToken),
//             scheduleIndexes,
//             mocScheduleIds,
//             purchaseAmounts,
//             purchasePeriods,
//             lendingProtocolIndex
//         );
//         uint256 mocGasUsed = mocGasStart - gasleft();
        
//         // Execute Uniswap batch purchase
//         uint256 uniGasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManUni.batchBuyRbtc(
//             users,
//             address(docToken),
//             scheduleIndexes,
//             uniScheduleIds,
//             purchaseAmounts,
//             purchasePeriods,
//             lendingProtocolIndex
//         );
//         uint256 uniGasUsed = uniGasStart - gasleft();
        
//         // Record balances after batch purchases
//         vm.startPrank(USER);
//         uint256 mocRbtcBalanceAfter = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalanceAfter = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();
        
//         // Calculate differences
//         uint256 mocRbtcPurchased = mocRbtcBalanceAfter - mocRbtcBalanceBefore;
//         uint256 uniRbtcPurchased = uniRbtcBalanceAfter - uniRbtcBalanceBefore;
        
//         // Print basic results
//         console2.log("MoC Batch Purchase:");
//         console2.log("  Gas used:", mocGasUsed);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(mocRbtcPurchased), mocRbtcPurchased / 1e10);
        
//         console2.log("Uniswap Batch Purchase:");
//         console2.log("  Gas used:", uniGasUsed);
//         console2.log("  rBTC purchased: %s (%d sats)", _formatRbtc(uniRbtcPurchased), uniRbtcPurchased / 1e10);
        
//         // Calculate actual DOC spent
//         uint256 docPerSchedule = DOC_TO_SPEND / NUM_OF_SCHEDULES;
//         uint256 totalDocSpent = docPerSchedule * NUM_OF_SCHEDULES;
//         console2.log("\nDOC spent per method:", totalDocSpent / 1e18);
        
//         // Operational costs analysis (team perspective)
//         console2.log("\nOperational Costs Analysis (Team Perspective):");
//         console2.log("  Gas price (WEI):", tx.gasprice);
//         uint256 mocGasCostRbtc = mocGasUsed * tx.gasprice;
//         uint256 uniGasCostRbtc = uniGasUsed * tx.gasprice;
        
//         if (mocGasCostRbtc > uniGasCostRbtc) {
//             uint256 extraCostRbtc = mocGasCostRbtc - uniGasCostRbtc;
//             console2.log("MoC is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else if (uniGasCostRbtc > mocGasCostRbtc) {
//             uint256 extraCostRbtc = uniGasCostRbtc - mocGasCostRbtc;
//             console2.log("Uniswap is more expensive to operate:");
//             console2.log("  Extra cost in rBTC: %s (%d sats)", _formatRbtc(extraCostRbtc), extraCostRbtc / 1e10);
//             console2.log("  Extra cost in USD: %s", _formatUsd(extraCostRbtc, btcPrice));
//         } else {
//             console2.log("Both methods have equal operational costs");
//         }

//         // User benefits analysis (user perspective)
//         console2.log("\nUser Benefits Analysis (User Perspective):");
//         if (mocRbtcPurchased > uniRbtcPurchased) {
//             uint256 extraRbtc = mocRbtcPurchased - uniRbtcPurchased;
//             console2.log("MoC provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else if (uniRbtcPurchased > mocRbtcPurchased) {
//             uint256 extraRbtc = uniRbtcPurchased - mocRbtcPurchased;
//             console2.log("Uniswap provides better returns:");
//             console2.log("  Extra rBTC gained: %s (%d sats)", _formatRbtc(extraRbtc), extraRbtc / 1e10);
//             console2.log("  Extra value in USD: %s", _formatUsd(extraRbtc, btcPrice));
//         } else {
//             console2.log("Both methods provide equal returns");
//         }
//     }
    
//     function createMultipleSchedules(DcaManager dcaManager, address handler) private {
//         // Delete all existing schedules first
//         vm.startPrank(USER);
//         DcaManager.DcaDetails[] memory existingSchedules = dcaManager.getMyDcaSchedules(address(docToken));
//         for (uint256 i = 0; i < existingSchedules.length; i++) {
//             dcaManager.deleteDcaSchedule(address(docToken), existingSchedules[i].scheduleId);
//         }
//         vm.stopPrank();

//         // Create multiple schedules with different parameters
//         for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
//             uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
//             uint256 purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES;
//             uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
            
//             vm.startPrank(USER);
//             docToken.approve(handler, docToDeposit);
//             dcaManager.createDcaSchedule(
//                 address(docToken), docToDeposit, purchaseAmount, purchasePeriod, lendingProtocolIndex
//             );
//             vm.stopPrank();
//         }
//     }
    
//     function executeMultiplePurchases(DcaManager dcaManager) private {
//         // Execute purchases for each schedule
//         for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
//             vm.prank(USER);
//             bytes32 scheduleId = dcaManager.getScheduleId(address(docToken), i);
//             vm.prank(SWAPPER);
//             dcaManager.buyRbtc(USER, address(docToken), i, scheduleId);
            
//             // Advance time for the next purchase
//             vm.warp(block.timestamp + MIN_PURCHASE_PERIOD);
//         }
//     }
    
//     function printFinalComparison() private {
//         console2.log("\n=== FINAL COMPARISON ===");
//         vm.startPrank(USER);
//         uint256 mocRbtcBalance = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//         uint256 uniRbtcBalance = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//         vm.stopPrank();
        
//         console2.log("MoC final rBTC balance: %s (%d sats)", _formatRbtc(mocRbtcBalance), mocRbtcBalance / 1e10);
//         console2.log("Uniswap final rBTC balance: %s (%d sats)", _formatRbtc(uniRbtcBalance), uniRbtcBalance / 1e10);
        
//         if (mocRbtcBalance > uniRbtcBalance) {
//             if (uniRbtcBalance > 0) {
//                 // Calculate with higher precision to avoid division issues
//                 uint256 percentage = ((mocRbtcBalance - uniRbtcBalance) * 1000000) / uniRbtcBalance;
//                 console2.log("Overall, MoC provided better returns by %d.%d%", 
//                     percentage / 10000, 
//                     percentage % 10000);
//             } else {
//                 console2.log("Overall, MoC provided better returns (Uniswap had 0 returns)");
//             }
//         } else if (uniRbtcBalance > mocRbtcBalance) {
//             if (mocRbtcBalance > 0) {
//                 // Calculate with higher precision to avoid division issues
//                 uint256 percentage = ((uniRbtcBalance - mocRbtcBalance) * 1000000) / mocRbtcBalance;
//                 console2.log("Overall, Uniswap provided better returns by %d.%d%", 
//                     percentage / 10000, 
//                     percentage % 10000);
//             } else {
//                 console2.log("Overall, Uniswap provided better returns (MoC had 0 returns)");
//             }
//         } else {
//             if (mocRbtcBalance == 0 && uniRbtcBalance == 0) {
//                 console2.log("Both methods provided zero returns");
//             } else {
//                 console2.log("Both methods provided equal returns");
//             }
//         }
        
//         // Also show the absolute difference in USD terms
//         if (mocRbtcBalance != uniRbtcBalance) {
//             uint256 diffRbtc = mocRbtcBalance > uniRbtcBalance ? 
//                                mocRbtcBalance - uniRbtcBalance : 
//                                uniRbtcBalance - mocRbtcBalance;
//             console2.log("Absolute difference in USD: %s", _formatUsd(diffRbtc, btcPrice));
//         }
//     }

//     // Helper functions for formatting rBTC values with proper decimal places
//     function _formatRbtc(uint256 amount) internal pure returns (string memory) {
//         uint256 whole = amount / 1e18;
//         uint256 fraction = amount % 1e18;
//         return string(abi.encodePacked(_uintToString(whole), ".", _formatFractional(fraction)));
//     }
    
//     function _formatFractional(uint256 fraction) internal pure returns (string memory) {
//         // Convert fraction to a string with leading zeros
//         string memory fractionStr = _uintToString(fraction);
//         uint256 numZeros = 18 - bytes(fractionStr).length;

//         // Prepend leading zeros
//         string memory leadingZeros = "";
//         for (uint256 i = 0; i < numZeros; i++) {
//             leadingZeros = string(abi.encodePacked(leadingZeros, "0"));
//         }

//         return string(abi.encodePacked(leadingZeros, fractionStr));
//     }

//     function _uintToString(uint256 num) internal pure returns (string memory) {
//         if (num == 0) return "0";
//         uint256 temp = num;
//         uint256 digits;
//         while (temp != 0) {
//             digits++;
//             temp /= 10;
//         }
//         bytes memory buffer = new bytes(digits);
//         while (num != 0) {
//             digits -= 1;
//             buffer[digits] = bytes1(uint8(48 + num % 10));
//             num /= 10;
//         }
//         return string(buffer);
//     }

//     // Helper function to format USD values with proper decimal places
//     function _formatUsd(uint256 rbtcAmount, uint256 btcPriceInUsd) internal pure returns (string memory) {
//         // Calculate USD with higher precision to avoid losing small values
//         uint256 usdValueRaw = (rbtcAmount * btcPriceInUsd);
        
//         // Format with 6 decimal places (division by 1e12 instead of 1e18)
//         uint256 usdWhole = usdValueRaw / 1e18;
//         uint256 usdFraction = (usdValueRaw % 1e18) / 1e12; // 6 decimal places
        
//         // Convert to string with proper formatting
//         string memory usdWholeStr = _uintToString(usdWhole);
//         string memory usdFractionStr = _uintToString(usdFraction);
        
//         // Add leading zeros to fraction if needed
//         uint256 numZeros = 6 - bytes(usdFractionStr).length;
//         string memory leadingZeros = "";
//         for (uint256 i = 0; i < numZeros; i++) {
//             leadingZeros = string(abi.encodePacked(leadingZeros, "0"));
//         }
        
//         return string(abi.encodePacked(usdWholeStr, ".", leadingZeros, usdFractionStr));
//     }
// } 