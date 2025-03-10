// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {DeployMocSwaps} from "./DeployMocSwaps.s.sol";
// import {DeployDexSwaps} from "./DeployDexSwaps.s.sol";

// contract ComparePurchaseMethods is Script {
//     function setUp() public virtual {
//         if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
//             s_lendingProtocolIndex = TROPYKUS_INDEX;
//         } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
//             s_lendingProtocolIndex = SOVRYN_INDEX;
//         } else {
//             revert("Lending protocol not allowed");
//         }

//         // Deal rBTC funds to user
//         vm.deal(USER, STARTING_RBTC_USER_BALANCE);
//         s_btcPrice = BTC_PRICE;

//         if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
//             MocHelperConfig helperConfig;
//             DeployMocSwaps deployMocSwapContracts = new DeployMocSwaps();
//             (adminOperations, docHandlerAddress, dcaManager, helperConfig) = deployMocSwapContracts.run();
//             docHandler = IDocHandler(docHandlerAddress);
//             MocHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();
//             // (address docTokenAddress, address mocProxyAddress, kDocAddress, iSusdAddress) =
//             //     helperConfig.activeNetworkConfig();

//             address docTokenAddress = networkConfig.docTokenAddress;
//             address mocProxyAddress = networkConfig.mocProxyAddress;
//             kDocAddress = networkConfig.kDocAddress;
//             iSusdAddress = networkConfig.iSusdAddress;

//             docToken = MockDocToken(docTokenAddress);
//             mocProxy = MockMocProxy(mocProxyAddress);

//             // Give the MoC proxy contract allowance
//             docToken.approve(mocProxyAddress, DOC_TO_DEPOSIT);

//             // Mint DOC for the user
//             if (block.chainid == ANVIL_CHAIN_ID) {
//                 // Local tests
//                 // Deal rBTC funds to MoC contract
//                 vm.deal(mocProxyAddress, 1000 ether);

//                 // Give the MoC proxy contract allowance to move DOC from docHandler
//                 // This is necessary for local tests because of how the mock contract works, but not for the live contract
//                 vm.prank(address(docHandler));
//                 docToken.approve(mocProxyAddress, type(uint256).max);
//                 docToken.mint(USER, USER_TOTAL_DOC);
//             } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
//                 // Fork tests
//                 // bytes32 balanceSlot = keccak256(abi.encode(USER, uint256(DOC_BALANCES_SLOT)));
//                 // vm.store(address(mockDocToken), balanceSlot, bytes32(USER_TOTAL_DOC));
//                 // bytes32 balance = vm.load(address(mockDocToken), balanceSlot);
//                 // emit log_uint(uint256(balance));

//                 // Foundry's EVM handles gas slightly differently from how RSK's does it,
//                 // causing an OutOfGas error due to hitting transfer() function's 2300 cap when rBTC is transferred to a proxy contract
//                 // Thus, we need to change for these tests the address to which the rBTC gets sent to an EOA, e.g., the null address or a dummy address
//                 // Slot in MocInrate where the address of ComissionSplitter is stored: 214
//                 vm.store(
//                     address(mocInRateMainnet),
//                     bytes32(uint256(214)),
//                     bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//                 );
//                 // vm.pauseGasMetering();
//                 // mocProxy.mintDoc{value: RBTC_TO_MINT_DOC * 11 / 10, gas: gasleft()}(RBTC_TO_MINT_DOC);
//                 vm.prank(USER);
//                 mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
//                 // vm.resumeGasMetering();
//                 // mocProxy.mintDocVendors{value: 0.051 ether}(0.05 ether, payable(address(0)));
//                 mocOracle = ICoinPairPrice(mocOracleMainnet);
//                 s_btcPrice = mocOracle.getPrice() / 1e18;
//             } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
//                 vm.store(
//                     address(mocInRateTestnet),
//                     bytes32(uint256(214)),
//                     bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//                 );
//                 vm.prank(USER);
//                 mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);

//                 mocOracle = ICoinPairPrice(mocOracleTestnet);
//                 s_btcPrice = mocOracle.getPrice() / 1e18;
//             }
//         } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
//             DexHelperConfig helperConfig;
//             DeployDexSwaps deployContracts = new DeployDexSwaps();
//             (adminOperations, docHandlerAddress, dcaManager, helperConfig) = deployContracts.run();
//             docHandler = IDocHandler(docHandlerAddress);
//             // docHandler = DocHandler(docHandlerDex);
//             DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

//             // MockSwapRouter02 mockSwapRouter02;

//             address docTokenAddress = networkConfig.docTokenAddress;
//             kDocAddress = networkConfig.kDocAddress;
//             iSusdAddress = networkConfig.iSusdAddress;
//             // address lendingTokenAddress = networkConfig.kdocTokenAddress;
//             address wrBtcTokenAddress = networkConfig.wrbtcTokenAddress;
//             address swapRouter02Address = networkConfig.swapRouter02Address;
//             address mocProxyAddress = networkConfig.mocProxyAddress;

//             docToken = MockDocToken(docTokenAddress);
//             // lendingToken = ILendingToken(lendingTokenAddress);
//             wrBtcToken = MockWrbtcToken(wrBtcTokenAddress);
//             mocProxy = MockMocProxy(mocProxyAddress);

//             // Mint DOC for the user
//             if (block.chainid == ANVIL_CHAIN_ID) {
//                 // Local tests
//                 docToken.mint(USER, USER_TOTAL_DOC);
//                 // Deal 1000 rBTC to the mock SwapRouter02 contract, so that it can deposit rBTC on the mock WRBTC contract
//                 // to simulate that the DocHandlerDex contract has received WRBTC after calling the `exactInput()` function
//                 vm.deal(swapRouter02Address, 1000 ether);
//             } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
//                 vm.store(
//                     address(mocInRateMainnet),
//                     bytes32(uint256(214)),
//                     bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//                 );
//                 vm.prank(USER);
//                 mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
//                 console.log("DOC minted by user:", docToken.balanceOf(USER) / 1e18);
//                 mocOracle = ICoinPairPrice(mocOracleMainnet);
//                 s_btcPrice = mocOracle.getPrice() / 1e18;
//             } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
//                 vm.store(
//                     address(mocInRateTestnet),
//                     bytes32(uint256(214)),
//                     bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
//                 );
//                 vm.prank(USER);
//                 mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);

//                 mocOracle = ICoinPairPrice(mocOracleTestnet);
//                 s_btcPrice = mocOracle.getPrice() / 1e18;
//             }
//         } else {
//             revert("Invalid deploy environment");
//         }

//         if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
//             lendingToken = ILendingToken(kDocAddress);
//         } else if (s_lendingProtocolIndex == SOVRYN_INDEX) {
//             lendingToken = ILendingToken(iSusdAddress);
//         } else {
//             revert("Lending protocol not allowed");
//         }

//         // FeeCalculator helper test contract
//         feeCalculator = new FeeCalculator();

//         // Set roles
//         vm.prank(OWNER);
//         adminOperations.setAdminRole(ADMIN);
//         vm.startPrank(ADMIN);
//         adminOperations.setSwapperRole(SWAPPER);
//         // Add Troypkus and Sovryn as allowed lending protocols
//         adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, 1);
//         adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, 2);
//         vm.stopPrank();

//         // Add tokenHandler
//         vm.expectEmit(true, true, true, false);
//         emit AdminOperations__TokenHandlerUpdated(address(docToken), s_lendingProtocolIndex, address(docHandler));
//         vm.prank(ADMIN);
//         adminOperations.assignOrUpdateTokenHandler(address(docToken), s_lendingProtocolIndex, address(docHandler));

//         // The starting point of the tests is that the user has already deposited 1000 DOC (so withdrawals can also be tested without much hassle)
//         vm.startPrank(USER);
//         docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
//         dcaManager.createDcaSchedule(
//             address(docToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
//         );
//         vm.stopPrank();
//     }

//     function run() external {}
// }
