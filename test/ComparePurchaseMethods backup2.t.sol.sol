// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

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
//     uint256 constant NUM_OF_USERS = 10; // Can be easily changed to test different scenarios
//     uint256 constant SCALING_FACTOR = 100 ether; // Base purchase amount
//     uint256 constant DEPOSIT_MULTIPLIER = 2; // Deposit is 2x the purchase amount
    
//     address[] users;
//     uint256[] docToSpendArray;
//     uint256[] docToDepositArray;
    
//     address SWAPPER = makeAddr(SWAPPER_STRING);
//     address OWNER = makeAddr(OWNER_STRING);
//     address ADMIN = makeAddr(ADMIN_STRING);
//     address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
//     address DUMMY_COMMISSION_RECEIVER = makeAddr("Dummy commission receiver");
    
//     uint256 constant MIN_PURCHASE_PERIOD = 1 days;
//     uint256 constant SCHEDULE_INDEX = 0;
//     uint256 constant RBTC_TO_MINT_DOC = 1 ether;

//     // Mainnet addresses
//     address constant MOC_ORACLE = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
//     address constant MOC_INRATE = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
    
//     // Deployed contracts
//     DeployMocAndUniswap.DeployedContracts deployedContracts;
    
//     // Common contracts
//     MockDocToken docToken;
    
//     // MoC-specific contracts
//     MockMocProxy mocProxy;
//     DcaManager dcaManMoc;
//     address handlerMoc;
    
//     // Uniswap-specific contracts
//     MockWrbtcToken wrbtcToken;
//     ICoinPairPrice priceOracle;
//     DcaManager dcaManUni;
//     address handlerUni;
    
//     // Protocol settings
//     uint256 lendingProtocolIndex;
//     uint256 btcPrice;

//     function setUp() public {
//         console2.log("Setting up comparison test with %d users", NUM_OF_USERS);
        
//         // Initialize arrays for users and amounts
//         initializeArrays();
        
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
//     }
    
//     function initializeArrays() private {
//         // Create arrays for users and amounts based on NUM_OF_USERS
//         users = new address[](NUM_OF_USERS);
//         docToSpendArray = new uint256[](NUM_OF_USERS);
//         docToDepositArray = new uint256[](NUM_OF_USERS);
        
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             // Generate user addresses with index
//             users[i] = makeAddr(string(abi.encodePacked("User", _uintToString(i+1))));
            
//             // Calculate purchase amount: scale by user index (starting from 1)
//             docToSpendArray[i] = SCALING_FACTOR * (i+1);
            
//             // Calculate deposit amount: 10x the purchase amount
//             docToDepositArray[i] = docToSpendArray[i] * DEPOSIT_MULTIPLIER;
//         }
//     }
    
//     function setupEnvironment() private {
//         // Deal rBTC funds to each user for minting DOC
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.deal(users[i], 10 ether);
//         }
        
//         // Fix the commission splitter address to avoid gas issues in Foundry
//         vm.store(
//             MOC_INRATE,
//             bytes32(uint256(214)),
//             bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//         );
        
//         // Mint DOC by sending rBTC to MoC for each user
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.prank(users[i]);
//             mocProxy.mintDoc{value: RBTC_TO_MINT_DOC}(RBTC_TO_MINT_DOC * 95 / 100); // Account for commission
//         }
        
//         // Get BTC price from oracle for Uniswap implementation
//         btcPrice = priceOracle.getPrice() / 1e18;
//         console2.log("BTC price from mainnet oracle: %d USD", btcPrice);
        
//         // Output DOC balances for verification
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             console2.log("User %s: DOC balance: %d; Purchase amount: %d DOC", 
//                 _uintToString(i+1), 
//                 docToken.balanceOf(users[i]) / 1e18, 
//                 docToSpendArray[i] / 1e18
//             );
//         }
        
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

//         // Create initial DCA schedules for each user
//         createInitialSchedules();
        
//         console2.log("Environment setup complete");
//     }
    
//     function createInitialSchedules() private {
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
            
//             // For MoC implementation
//             docToken.approve(handlerMoc, docToDepositArray[i]);
//             dcaManMoc.createDcaSchedule(
//                 address(docToken), docToDepositArray[i], docToSpendArray[i], MIN_PURCHASE_PERIOD, lendingProtocolIndex
//             );
            
//             // For Uniswap implementation
//             docToken.approve(handlerUni, docToDepositArray[i]);
//             dcaManUni.createDcaSchedule(
//                 address(docToken), docToDepositArray[i], docToSpendArray[i], MIN_PURCHASE_PERIOD, lendingProtocolIndex
//             );
            
//             vm.stopPrank();
//         }
//     }
    
//     function testCompareSwapMethods() public {
//         // Test 1: Compare individual purchases
//         (uint256 mocIndividualGas, uint256 uniIndividualGas) = compareIndividualPurchases();
        
//         // Test 2: Compare batch purchases
//         (uint256 mocBatchGas, uint256 uniBatchGas) = compareBatchPurchases();
        
//         // Print final comparison
//         printFinalComparison(mocIndividualGas, uniIndividualGas, mocBatchGas, uniBatchGas);
//     }
    
//     function compareIndividualPurchases() private returns (uint256, uint256) {
//         console2.log("\n=== COMPARING INDIVIDUAL PURCHASES (ONE PER USER) ===");
        
//         // Execute purchases for MoC
//         (uint256 mocTotalGasUsed, uint256 mocTotalRbtcPurchased) = executeIndividualMocPurchases();
        
//         // Reset time for Uniswap purchases
//         vm.warp(block.timestamp + MIN_PURCHASE_PERIOD);
        
//         // Execute purchases for Uniswap
//         (uint256 uniTotalGasUsed, uint256 uniTotalRbtcPurchased) = executeIndividualUniPurchases();
        
//         // Calculate and print the total DOC spent
//         uint256 totalDocSpent = calculateTotalDocSpent();
//         console2.log("\nTotal DOC spent per method:", totalDocSpent / 1e18);
        
//         // Print rBTC comparison
//         console2.log("MoC rBTC purchased: %s", _formatRbtc(mocTotalRbtcPurchased));
//         console2.log("Uniswap rBTC purchased: %s", _formatRbtc(uniTotalRbtcPurchased));
//         if(mocTotalRbtcPurchased > uniTotalRbtcPurchased) {
//             console2.log("MoC returns more rBTC by: %s rBTC (%s USD)", _formatRbtc(mocTotalRbtcPurchased - uniTotalRbtcPurchased), _formatUsd(mocTotalRbtcPurchased - uniTotalRbtcPurchased, btcPrice));
//         } else if(uniTotalRbtcPurchased > mocTotalRbtcPurchased) {
//             console2.log("Uniswap returns more rBTC by: %s rBTC (%s USD)", _formatRbtc(uniTotalRbtcPurchased - mocTotalRbtcPurchased), _formatUsd(uniTotalRbtcPurchased - mocTotalRbtcPurchased, btcPrice   ));
//         } else {
//             console2.log("Both methods return the same amount of rBTC");
//         }

//         // Print gas comparison
//         printGasComparison(mocTotalGasUsed, uniTotalGasUsed);
        
//         return (mocTotalGasUsed, uniTotalGasUsed);
//     }
    
//     function executeIndividualMocPurchases() private returns (uint256, uint256) {
//         // Get starting balances
//         uint256[] memory startBalances = new uint256[](NUM_OF_USERS);
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             startBalances[i] = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//             vm.stopPrank();
//         }
        
//         // Execute purchases
//         uint256 totalGasUsed = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.prank(users[i]);
//             bytes32 scheduleId = dcaManMoc.getScheduleId(address(docToken), SCHEDULE_INDEX);
            
//             uint256 gasStart = gasleft();
//             vm.prank(SWAPPER);
//             dcaManMoc.buyRbtc(users[i], address(docToken), SCHEDULE_INDEX, scheduleId);
//             totalGasUsed += (gasStart - gasleft());
//         }

//         uint256 totalGasCost = totalGasUsed * tx.gasprice;
        
//         // Get ending balances and calculate rBTC gained
//         uint256 totalRbtcPurchased = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             uint256 endBalance = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//             totalRbtcPurchased += (endBalance - startBalances[i]);
//             vm.stopPrank();
//         }
        
//         // Print results
//         console2.log("MoC Individual Purchases (5 users):");
//         console2.log("  Total Gas used:", totalGasUsed);
//         console2.log("  Total Gas cost: %s rBTC (%d sats, %s USD)", _formatRbtc(totalGasCost), _weiToSats(totalGasCost), _formatUsd(totalGasCost, btcPrice));
//         console2.log("  Total rBTC purchased: %s (%d sats)", _formatRbtc(totalRbtcPurchased), totalRbtcPurchased / 1e10);
        
//         return (totalGasUsed, totalRbtcPurchased);
//     }
    
//     function executeIndividualUniPurchases() private returns (uint256, uint256) {
//         // Get starting balances
//         uint256[] memory startBalances = new uint256[](NUM_OF_USERS);
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             startBalances[i] = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//             vm.stopPrank();
//         }
        
//         // Execute purchases
//         uint256 totalGasUsed = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.prank(users[i]);
//             bytes32 scheduleId = dcaManUni.getScheduleId(address(docToken), SCHEDULE_INDEX);
            
//             uint256 gasStart = gasleft();
//             vm.prank(SWAPPER);
//             dcaManUni.buyRbtc(users[i], address(docToken), SCHEDULE_INDEX, scheduleId);
//             totalGasUsed += (gasStart - gasleft());
//         }
        
//         uint256 totalGasCost = totalGasUsed * tx.gasprice;

//         // Get ending balances and calculate rBTC gained
//         uint256 totalRbtcPurchased = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             uint256 endBalance = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//             totalRbtcPurchased += (endBalance - startBalances[i]);
//             vm.stopPrank();
//         }
        
//         // Print results
//         console2.log("Uniswap Individual Purchases (5 users):");
//         console2.log("  Total Gas used:", totalGasUsed);
//         console2.log("  Total Gas cost: %s rBTC (%d sats, %s USD)", _formatRbtc(totalGasCost), _weiToSats(totalGasCost), _formatUsd(totalGasCost, btcPrice));
//         console2.log("  Total rBTC purchased: %s (%d sats)", _formatRbtc(totalRbtcPurchased), totalRbtcPurchased / 1e10);
        
//         return (totalGasUsed, totalRbtcPurchased);
//     }
    
//     function compareBatchPurchases() private returns (uint256, uint256) {
//         console2.log("\n=== COMPARING BATCH PURCHASES (ALL USERS AT ONCE) ===");
        
//         // Execute MoC batch purchase first and capture results
//         (uint256 mocGasUsed, uint256 mocRbtcPurchased) = executeMocBatchPurchase();
        
//         // Reset time for the next batch
//         vm.warp(block.timestamp + MIN_PURCHASE_PERIOD);
        
//         // Execute Uniswap batch purchase and capture results
//         (uint256 uniGasUsed, uint256 uniRbtcPurchased) = executeUniBatchPurchase();
        
//         // Calculate and print the total DOC spent
//         uint256 totalDocSpent = calculateTotalDocSpent();
//         console2.log("\nTotal DOC spent per method:", totalDocSpent / 1e18);
        
//         // Print rBTC comparison
//         console2.log("MoC rBTC purchased: %s", _formatRbtc(mocRbtcPurchased));
//         console2.log("Uniswap rBTC purchased: %s", _formatRbtc(uniRbtcPurchased));
//         if(mocRbtcPurchased > uniRbtcPurchased) {
//             console2.log("MoC returns more rBTC by: %s rBTC (%s USD)", _formatRbtc(mocRbtcPurchased - uniRbtcPurchased), _formatUsd(mocRbtcPurchased - uniRbtcPurchased, btcPrice));
//         } else if(uniRbtcPurchased > mocRbtcPurchased) {
//             console2.log("Uniswap returns more rBTC by: %s rBTC (%s USD)", _formatRbtc(uniRbtcPurchased - mocRbtcPurchased), _formatUsd(uniRbtcPurchased - mocRbtcPurchased, btcPrice   ));
//         } else {
//             console2.log("Both methods return the same amount of rBTC");
//         }

//         // Print gas comparison
//         printGasComparison(mocGasUsed, uniGasUsed);
        
//         return (mocGasUsed, uniGasUsed);
//     }
    
//     // Break down the batch purchases into separate functions
//     function executeMocBatchPurchase() private returns (uint256, uint256) {
//         // Get starting balances
//         uint256[] memory startBalances = new uint256[](NUM_OF_USERS);
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             startBalances[i] = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//             vm.stopPrank();
//         }
        
//         // Prepare batch data
//         address[] memory userArray = new address[](NUM_OF_USERS);
//         uint256[] memory scheduleIndexes = new uint256[](NUM_OF_USERS);
//         bytes32[] memory scheduleIds = new bytes32[](NUM_OF_USERS);
//         uint256[] memory purchaseAmounts = new uint256[](NUM_OF_USERS);
//         uint256[] memory purchasePeriods = new uint256[](NUM_OF_USERS);
        
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             userArray[i] = users[i];
//             scheduleIndexes[i] = SCHEDULE_INDEX;
            
//             vm.startPrank(users[i]);
//             scheduleIds[i] = dcaManMoc.getScheduleId(address(docToken), SCHEDULE_INDEX);
//             purchaseAmounts[i] = dcaManMoc.getSchedulePurchaseAmount(address(docToken), SCHEDULE_INDEX);
//             purchasePeriods[i] = dcaManMoc.getSchedulePurchasePeriod(address(docToken), SCHEDULE_INDEX);
//             vm.stopPrank();
//         }
        
//         // Execute batch purchase
//         uint256 gasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManMoc.batchBuyRbtc(
//             userArray,
//             address(docToken),
//             scheduleIndexes,
//             scheduleIds,
//             purchaseAmounts,
//             purchasePeriods,
//             lendingProtocolIndex
//         );
//         uint256 gasUsed = gasStart - gasleft();
//         uint256 gasCost = gasUsed * tx.gasprice;
//         // Get ending balances and calculate rBTC gained
//         uint256 totalRbtcPurchased = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             uint256 endBalance = IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//             totalRbtcPurchased += (endBalance - startBalances[i]);
//             vm.stopPrank();
//         }
        
//         // Print results
//         console2.log("MoC Batch Purchase (%d users at once):", NUM_OF_USERS);
//         console2.log("  Gas used:", gasUsed);
//         console2.log("  Gas cost: %s rBTC (%d sats, %s USD)", _formatRbtc(gasCost), _weiToSats(gasCost), _formatUsd(gasCost, btcPrice));
//         console2.log("  Total rBTC purchased: %s (%d sats)", _formatRbtc(totalRbtcPurchased), totalRbtcPurchased / 1e10);
        
//         return (gasUsed, totalRbtcPurchased);
//     }
    
//     function executeUniBatchPurchase() private returns (uint256, uint256) {
//         // Get starting balances
//         uint256[] memory startBalances = new uint256[](NUM_OF_USERS);
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             startBalances[i] = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//             vm.stopPrank();
//         }
        
//         // Prepare batch data
//         address[] memory userArray = new address[](NUM_OF_USERS);
//         uint256[] memory scheduleIndexes = new uint256[](NUM_OF_USERS);
//         bytes32[] memory scheduleIds = new bytes32[](NUM_OF_USERS);
//         uint256[] memory purchaseAmounts = new uint256[](NUM_OF_USERS);
//         uint256[] memory purchasePeriods = new uint256[](NUM_OF_USERS);
        
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             userArray[i] = users[i];
//             scheduleIndexes[i] = SCHEDULE_INDEX;
            
//             vm.startPrank(users[i]);
//             scheduleIds[i] = dcaManUni.getScheduleId(address(docToken), SCHEDULE_INDEX);
//             purchaseAmounts[i] = dcaManUni.getSchedulePurchaseAmount(address(docToken), SCHEDULE_INDEX);
//             purchasePeriods[i] = dcaManUni.getSchedulePurchasePeriod(address(docToken), SCHEDULE_INDEX);
//             vm.stopPrank();
//         }
        
//         // Execute batch purchase
//         uint256 gasStart = gasleft();
//         vm.prank(SWAPPER);
//         dcaManUni.batchBuyRbtc(
//             userArray,
//             address(docToken),
//             scheduleIndexes,
//             scheduleIds,
//             purchaseAmounts,
//             purchasePeriods,
//             lendingProtocolIndex
//         );
//         uint256 gasUsed = gasStart - gasleft();
//         uint256 gasCost = gasUsed * tx.gasprice;
//         // Get ending balances and calculate rBTC gained
//         uint256 totalRbtcPurchased = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             uint256 endBalance = IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//             totalRbtcPurchased += (endBalance - startBalances[i]);
//             vm.stopPrank();
//         }
        
//         // Print results
//         console2.log("Uniswap Batch Purchase (%d users at once):", NUM_OF_USERS);
//         console2.log("  Gas used:", gasUsed);
//         console2.log("  Gas cost: %s rBTC (%d sats, %s USD)", _formatRbtc(gasCost), _weiToSats(gasCost), _formatUsd(gasCost, btcPrice));
//         console2.log("  Total rBTC purchased: %s (%d sats)", _formatRbtc(totalRbtcPurchased), totalRbtcPurchased / 1e10);
        
//         return (gasUsed, totalRbtcPurchased);
//     }
    
//     function printGasComparison(uint256 mocGasUsed, uint256 uniGasUsed) private view {
//         console2.log("\nGas Comparison:");
        
//         if (mocGasUsed > uniGasUsed) {
//             uint256 diff = mocGasUsed - uniGasUsed;
//             uint256 percentage = (diff * 10000) / mocGasUsed;
//             console2.log("Uniswap uses less gas by %d.%d%", percentage / 100, percentage % 100);
//         } else if (uniGasUsed > mocGasUsed) {
//             uint256 diff = uniGasUsed - mocGasUsed;
//             uint256 percentage = (diff * 10000) / uniGasUsed;
//             console2.log("MoC uses less gas by %d.%d%", percentage / 100, percentage % 100);
//         } else {
//             console2.log("Both methods use the same amount of gas");
//         }
        
//         uint256 mocGasCostRbtc = mocGasUsed * tx.gasprice;
//         uint256 uniGasCostRbtc = uniGasUsed * tx.gasprice;
//         if (mocGasCostRbtc > uniGasCostRbtc) {
//             console2.log("MoC is more gas-expensive by: %s rBTC (%d sats, %s USD)", _formatRbtc(mocGasCostRbtc - uniGasCostRbtc), _weiToSats(mocGasCostRbtc - uniGasCostRbtc), _formatUsd(mocGasCostRbtc - uniGasCostRbtc, btcPrice));
//         } else {
//             console2.log("Uniswap is more gas-expensive by: %s rBTC (%d sats, %s USD)", _formatRbtc(uniGasCostRbtc - mocGasCostRbtc), _weiToSats(uniGasCostRbtc - mocGasCostRbtc), _formatUsd(uniGasCostRbtc - mocGasCostRbtc, btcPrice));
//         }
//     }
    
//     function printFinalComparison(
//         uint256 mocIndividualGas, 
//         uint256 uniIndividualGas, 
//         uint256 mocBatchGas, 
//         uint256 uniBatchGas
//     ) private {
//         console2.log("\n=== FINAL COMPARISON ===");
        
//         // Recollect rBTC balances to compare the total purchased
//         uint256 mocTotalRbtc = 0;
//         uint256 uniTotalRbtc = 0;
        
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             vm.startPrank(users[i]);
//             mocTotalRbtc += IPurchaseRbtc(handlerMoc).getAccumulatedRbtcBalance();
//             uniTotalRbtc += IPurchaseRbtc(handlerUni).getAccumulatedRbtcBalance();
//             vm.stopPrank();
//         }
        
//         // Print rBTC comparison
//         console2.log("rBTC Purchase Analysis:");
//         console2.log("  MoC Total rBTC purchased: %s (%d sats)", _formatRbtc(mocTotalRbtc), mocTotalRbtc / 1e10);
//         console2.log("  Uniswap Total rBTC purchased: %s (%d sats)", _formatRbtc(uniTotalRbtc), uniTotalRbtc / 1e10);
        
//         if (mocTotalRbtc > uniTotalRbtc) {
//             uint256 diff = mocTotalRbtc - uniTotalRbtc;
//             console2.log("  MoC provided more rBTC overall by: %s (%d sats, %s USD)", 
//                 _formatRbtc(diff), diff / 1e10, _formatUsd(diff, btcPrice));
//         } else if (uniTotalRbtc > mocTotalRbtc) {
//             uint256 diff = uniTotalRbtc - mocTotalRbtc;
//             console2.log("  Uniswap provided more rBTC overall by: %s (%d sats, %s USD)", 
//                 _formatRbtc(diff), diff / 1e10, _formatUsd(diff, btcPrice));
//         }
        
//         // Gas efficiency analysis
//         console2.log("\nGas Efficiency Analysis:");
//         console2.log("  MoC Individual Total Gas: ", mocIndividualGas);
//         console2.log("  MoC Batch Total Gas: ", mocBatchGas);
//         if (mocIndividualGas > mocBatchGas) {
//             uint256 savings = ((mocIndividualGas - mocBatchGas) * 10000) / mocIndividualGas;
//             console2.log("  MoC Gas Savings with Batch: %d.%d%", savings / 100, savings % 100);
//         }
        
//         console2.log("  Uniswap Individual Total Gas: ", uniIndividualGas);
//         console2.log("  Uniswap Batch Total Gas: ", uniBatchGas);
//         if (uniIndividualGas > uniBatchGas) {
//             uint256 savings = ((uniIndividualGas - uniBatchGas) * 10000) / uniIndividualGas;
//             console2.log("  Uniswap Gas Savings with Batch: %d.%d%", savings / 100, savings % 100);
//         }
        
//         console2.log("\nConclusion:");
//         console2.log("This test demonstrates that batch operations significantly reduce gas costs");
//         console2.log("while maintaining similar or better rBTC returns for users.");
        
//         // Add specific insights based on test results
//         if (mocBatchGas < uniBatchGas) {
//             console2.log("MoC batch purchases are more gas-efficient than Uniswap batch purchases.");
//         } else if (uniBatchGas < mocBatchGas) {
//             console2.log("Uniswap batch purchases are more gas-efficient than MoC batch purchases.");
//         }
        
//         // Final recommendation based on actual test results
//         console2.log("\nRecommendation based on test results:");
        
//         if (mocTotalRbtc > uniTotalRbtc) {
//             console2.log("  - For optimizing purchased rBTC: Use MoC as it provides better returns");
//         } else if (uniTotalRbtc > mocTotalRbtc) {
//             console2.log("  - For optimizing purchased rBTC: Use Uniswap as it provides better returns");
//         } else {
//             console2.log("  - For optimizing purchased rBTC: Both methods provide similar returns");
//         }
        
//         if (mocIndividualGas < uniIndividualGas) {
//             console2.log("  - For individual purchases: MoC is more gas-efficient");
//         } else {
//             console2.log("  - For individual purchases: Uniswap is more gas-efficient");
//         }
        
//         if (mocBatchGas < uniBatchGas) {
//             console2.log("  - For batch operations: MoC is more gas-efficient");
//         } else {
//             console2.log("  - For batch operations: Uniswap is more gas-efficient");
//         }
        
//         console2.log("  - Overall: Batch purchases are significantly more efficient than individual purchases");
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

//     function _weiToSats(uint256 weiAmount) internal pure returns (uint256) {
//         return weiAmount / 1e10;
//     }

//     // Helper to calculate total DOC spent
//     function calculateTotalDocSpent() private view returns (uint256) {
//         uint256 total = 0;
//         for (uint256 i = 0; i < NUM_OF_USERS; i++) {
//             total += docToSpendArray[i];
//         }
//         return total;
//     }
// } 