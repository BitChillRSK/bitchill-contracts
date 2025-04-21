//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {DcaManagerAccessControl} from "../../src/DcaManagerAccessControl.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {IDocHandler} from "../../src/interfaces/IDocHandler.sol";
import {ICoinPairPrice} from "../../src/interfaces/ICoinPairPrice.sol";
import {TropykusDocHandlerMoc} from "../../src/TropykusDocHandlerMoc.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {AdminOperations} from "../../src/AdminOperations.sol";
import {IAdminOperations} from "../../src/interfaces/IAdminOperations.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import {DexHelperConfig} from "../../script/DexHelperConfig.s.sol";
import {DeployDexSwaps} from "../../script/DeployDexSwaps.s.sol";
import {DeployMocSwaps} from "../../script/DeployMocSwaps.s.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {ILendingToken} from "../interfaces/ILendingToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";
import {MockWrbtcToken} from "../mocks/MockWrbtcToken.sol";
import {MockSwapRouter02} from "../mocks/MockSwapRouter02.sol";
import "../Constants.sol";
import "./TestsHelper.t.sol";

contract DcaDappTest is Test {
    DcaManager dcaManager;
    MockMocProxy mocProxy;
    IDocHandler docHandler;
    AdminOperations adminOperations;
    MockDocToken docToken;
    ILendingToken lendingToken;
    MockWrbtcToken wrBtcToken;
    FeeCalculator feeCalculator;

    address USER = makeAddr(USER_STRING);
    address OWNER = makeAddr(OWNER_STRING);
    address ADMIN = makeAddr(ADMIN_STRING);
    address SWAPPER = makeAddr(SWAPPER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    uint256 constant STARTING_RBTC_USER_BALANCE = 10 ether; // 10 rBTC
    uint256 constant USER_TOTAL_DOC = 20_000 ether; // 20000 DOC owned by the user in total
    uint256 constant DOC_TO_DEPOSIT = 2000 ether; // 2000 DOC
    uint256 constant DOC_TO_SPEND = 200 ether; // 200 DOC for periodical purchases
    uint256 constant MIN_PURCHASE_PERIOD = 1 days; // at most one purchase every day
    uint256 constant SCHEDULE_INDEX = 0;
    uint256 constant NUM_OF_SCHEDULES = 5;
    uint256 constant RBTC_TO_MINT_DOC = 0.2 ether; // 1 BTC
    string swapType = vm.envString("SWAP_TYPE");
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address docHandlerAddress;
    uint256 s_lendingProtocolIndex;
    uint256 s_btcPrice;
    ICoinPairPrice mocOracle;
    address constant MOC_ORACLE_MAINNET = 0xe2927A0620b82A66D67F678FC9b826B0E01B1bFD;
    address constant MOC_ORACLE_TESTNET = 0xbffBD993FF1d229B0FfE55668F2009d20d4F7C5f;
    address constant MOC_IN_RATE_MAINNET = 0xc0f9B54c41E3d0587Ce0F7540738d8d649b0A3F3;
    address constant MOC_IN_RATE_TESTNET = 0x76790f846FAAf44cf1B2D717d0A6c5f6f5152B60;
    address DUMMY_COMMISSION_RECEIVER = makeAddr("Dummy commission receiver");
    address kDocAddress;
    address iSusdAddress;

    //////////////////////
    // Events ////////////
    //////////////////////

    // DcaManager
    event DcaManager__TokenBalanceUpdated(address indexed token, bytes32 indexed scheduleId, uint256 indexed amount);
    event DcaManager__DcaScheduleCreated(
        address indexed user,
        address indexed token,
        bytes32 indexed scheduleId,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );
    event DcaManager__DcaScheduleUpdated(
        address indexed user,
        address indexed token,
        bytes32 indexed scheduleId,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );

    // TokenHandler
    event TokenHandler__TokenDeposited(address indexed token, address indexed user, uint256 indexed amount);
    event TokenHandler__TokenWithdrawn(address indexed token, address indexed user, uint256 indexed amount);

    // IPurchaseRbtc
    event PurchaseRbtc__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 rBtcBought,
        bytes32 indexed scheduleId,
        uint256 amountSpent
    );
    event PurchaseRbtc__SuccessfulRbtcBatchPurchase(
        address indexed token, uint256 indexed totalPurchasedRbtc, uint256 indexed totalDocAmountSpent
    );

    // AdminOperations
    event AdminOperations__TokenHandlerUpdated(
        address indexed token, uint256 indexed lendinProtocolIndex, address indexed newHandler
    );

    //MockMocProxy
    event MockMocProxy__DocRedeemed(address indexed user, uint256 docAmount, uint256 btcAmount);

    //TokenLending
    event TokenLending__WithdrawalAmountAdjusted(
        address indexed user, uint256 indexed originalAmount, uint256 indexed adjustedAmount
    );

    /*//////////////////////////////////////////////////////////////
                            UNIT TESTS SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            s_lendingProtocolIndex = TROPYKUS_INDEX;
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            s_lendingProtocolIndex = SOVRYN_INDEX;
        } else {
            revert("Lending protocol not allowed");
        }

        // Deal rBTC funds to user
        vm.deal(USER, STARTING_RBTC_USER_BALANCE);
        s_btcPrice = BTC_PRICE;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            MocHelperConfig helperConfig;
            DeployMocSwaps deployContracts = new DeployMocSwaps();
            (adminOperations, docHandlerAddress, dcaManager, helperConfig) = deployContracts.run();
            docHandler = IDocHandler(docHandlerAddress);
            MocHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

            address docTokenAddress = networkConfig.docTokenAddress;
            address mocProxyAddress = networkConfig.mocProxyAddress;
            kDocAddress = networkConfig.kDocAddress;
            iSusdAddress = networkConfig.iSusdAddress;

            docToken = MockDocToken(docTokenAddress);
            mocProxy = MockMocProxy(mocProxyAddress);

            // Give the MoC proxy contract allowance
            docToken.approve(mocProxyAddress, DOC_TO_DEPOSIT);

            // Mint DOC for the user
            if (block.chainid == ANVIL_CHAIN_ID) {
                // Local tests
                // Deal rBTC funds to MoC contract
                vm.deal(mocProxyAddress, 1000 ether);

                // Give the MoC proxy contract allowance to move DOC from docHandler
                // This is necessary for local tests because of how the mock contract works, but not for the live contract
                vm.prank(address(docHandler));
                docToken.approve(mocProxyAddress, type(uint256).max);
                docToken.mint(USER, USER_TOTAL_DOC);
            } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
                // Fork tests
                // bytes32 balanceSlot = keccak256(abi.encode(USER, uint256(DOC_BALANCES_SLOT)));
                // vm.store(address(mockDocToken), balanceSlot, bytes32(USER_TOTAL_DOC));
                // bytes32 balance = vm.load(address(mockDocToken), balanceSlot);
                // emit log_uint(uint256(balance));

                // Foundry's EVM handles gas slightly differently from how RSK's does it,
                // causing an OutOfGas error due to hitting transfer() function's 2300 cap when rBTC is transferred to a proxy contract
                // Thus, we need to change for these tests the address to which the rBTC gets sent to an EOA, e.g., the null address or a dummy address
                // Slot in MocInrate where the address of ComissionSplitter is stored: 214
                vm.store(
                    MOC_IN_RATE_MAINNET,
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );
                vm.prank(USER);
                mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
                mocOracle = ICoinPairPrice(MOC_ORACLE_MAINNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
                vm.store(
                    address(MOC_IN_RATE_TESTNET),
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );
                vm.prank(USER);
                mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);

                mocOracle = ICoinPairPrice(MOC_ORACLE_TESTNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            }
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            DexHelperConfig helperConfig;
            DeployDexSwaps deployContracts = new DeployDexSwaps();
            (adminOperations, docHandlerAddress, dcaManager, helperConfig) = deployContracts.run();
            docHandler = IDocHandler(docHandlerAddress);
            DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

            address docTokenAddress = networkConfig.docTokenAddress;
            kDocAddress = networkConfig.kDocAddress;
            iSusdAddress = networkConfig.iSusdAddress;
            address wrBtcTokenAddress = networkConfig.wrbtcTokenAddress;
            address swapRouter02Address = networkConfig.swapRouter02Address;
            address mocProxyAddress = networkConfig.mocProxyAddress;

            docToken = MockDocToken(docTokenAddress);
            wrBtcToken = MockWrbtcToken(wrBtcTokenAddress);
            mocProxy = MockMocProxy(mocProxyAddress);

            // Mint DOC for the user
            if (block.chainid == ANVIL_CHAIN_ID) {
                // Local tests
                docToken.mint(USER, USER_TOTAL_DOC);
                // Deal 1000 rBTC to the mock SwapRouter02 contract, so that it can deposit rBTC on the mock WRBTC contract
                // to simulate that the DocHandlerDex contract has received WRBTC after calling the `exactInput()` function
                vm.deal(swapRouter02Address, 1000 ether);
            } else if (block.chainid == RSK_MAINNET_CHAIN_ID) {
                vm.store(
                    address(MOC_IN_RATE_MAINNET),
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );
                vm.prank(USER);
                mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);
                console.log("DOC minted by user:", docToken.balanceOf(USER) / 1e18);
                mocOracle = ICoinPairPrice(MOC_ORACLE_MAINNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            } else if (block.chainid == RSK_TESTNET_CHAIN_ID) {
                vm.store(
                    address(MOC_IN_RATE_TESTNET),
                    bytes32(uint256(214)),
                    bytes32(uint256(uint160(DUMMY_COMMISSION_RECEIVER)))
                );
                vm.prank(USER);
                mocProxy.mintDoc{value: 0.21 ether}(0.2 ether);

                mocOracle = ICoinPairPrice(MOC_ORACLE_TESTNET);
                s_btcPrice = mocOracle.getPrice() / 1e18;
            }
        } else {
            revert("Invalid deploy environment");
        }

        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            lendingToken = ILendingToken(kDocAddress);
        } else if (s_lendingProtocolIndex == SOVRYN_INDEX) {
            lendingToken = ILendingToken(iSusdAddress);
        } else {
            revert("Lending protocol not allowed");
        }

        // FeeCalculator helper test contract
        feeCalculator = new FeeCalculator();

        // Set roles
        vm.prank(OWNER);
        adminOperations.setAdminRole(ADMIN);
        vm.startPrank(ADMIN);
        adminOperations.setSwapperRole(SWAPPER);
        // Add Troypkus and Sovryn as allowed lending protocols
        adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, 1);
        adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, 2);
        vm.stopPrank();

        // Add tokenHandler
        vm.expectEmit(true, true, true, false);
        emit AdminOperations__TokenHandlerUpdated(address(docToken), s_lendingProtocolIndex, address(docHandler));
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(docToken), s_lendingProtocolIndex, address(docHandler));

        // The starting point of the tests is that the user has already deposited 1000 DOC (so withdrawals can also be tested without much hassle)
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      UNIT TESTS COMMON FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositDoc() internal returns (uint256, uint256) {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length - 1)
        );
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenDeposited(address(docToken), USER, DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit DcaManager__TokenBalanceUpdated(address(docToken), scheduleId, 2 * DOC_TO_DEPOSIT); // 2 *, since a previous deposit is made in the setup
        dcaManager.depositToken(address(docToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        vm.stopPrank();
        return (userBalanceAfterDeposit, userBalanceBeforeDeposit);
    }

    function withdrawDoc() internal {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false); // Amounts may not match to the last wei, so third parameter is false
        emit TokenHandler__TokenWithdrawn(address(docToken), USER, DOC_TO_DEPOSIT);
        dcaManager.withdrawToken(address(docToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 remainingAmount = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        assertEq(remainingAmount, 0);
        vm.stopPrank();
    }

    function createSeveralDcaSchedules() internal {
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
        uint256 purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES;
        // Delete the schedule created in setUp to have all five schedules with the same amounts
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length - 1)
        );
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = SCHEDULE_INDEX + i;
            uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
            uint256 userBalanceBeforeDeposit;
            if (dcaManager.getMyDcaSchedules(address(docToken)).length > scheduleIndex) {
                userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(docToken), scheduleIndex);
            } else {
                userBalanceBeforeDeposit = 0;
            }
            scheduleId = keccak256(
                abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length)
            );
            vm.expectEmit(true, true, true, true);
            emit DcaManager__DcaScheduleCreated(
                USER, address(docToken), scheduleId, docToDeposit, purchaseAmount, purchasePeriod
            );
            dcaManager.createDcaSchedule(
                address(docToken), docToDeposit, purchaseAmount, purchasePeriod, s_lendingProtocolIndex
            );
            uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(docToken), scheduleIndex);
            assertEq(docToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
            assertEq(purchaseAmount, dcaManager.getSchedulePurchaseAmount(address(docToken), scheduleIndex));
            assertEq(purchasePeriod, dcaManager.getSchedulePurchasePeriod(address(docToken), scheduleIndex));
        }
        vm.stopPrank();
    }

    function makeSinglePurchase() internal {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        IDcaManager.DcaDetails[] memory dcaDetails = dcaManager.getMyDcaSchedules(address(docToken));
        vm.stopPrank();

        uint256 fee = feeCalculator.calculateFee(DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        uint256 netPurchaseAmount = DOC_TO_SPEND - fee;

        if (block.chainid == ANVIL_CHAIN_ID) {
            vm.expectEmit(true, true, true, true);
        } else {
            vm.expectEmit(true, true, true, false); // Amounts may not match to the last wei on fork tests
        }
        emit PurchaseRbtc__RbtcBought(
            USER,
            address(docToken),
            netPurchaseAmount / s_btcPrice,
            dcaDetails[SCHEDULE_INDEX].scheduleId,
            netPurchaseAmount
        );
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(docToken), SCHEDULE_INDEX, dcaDetails[SCHEDULE_INDEX].scheduleId);

        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        uint256 rbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();

        // Check that DOC was subtracted and rBTC was added to user's balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(rbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase, netPurchaseAmount / s_btcPrice);
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            rbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase,
            netPurchaseAmount / s_btcPrice,
            0.5e16 // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
        );
        // }
    }

    function makeSeveralPurchasesWithSeveralSchedules() internal returns (uint256 totalDocSpent) {
        // createSeveralDcaSchedules();

        uint8 numOfPurchases = 5;
        uint256 totalDocRedeemed;

        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = i;
            vm.startPrank(USER);
            uint256 schedulePurchaseAmount = dcaManager.getSchedulePurchaseAmount(address(docToken), scheduleIndex);
            uint256 schedulePurchasePeriod = dcaManager.getSchedulePurchasePeriod(address(docToken), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount, schedulePurchasePeriod);
            uint256 netPurchaseAmount = schedulePurchaseAmount - fee;

            for (uint8 j; j < numOfPurchases; ++j) {
                vm.startPrank(USER);
                uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(docToken), scheduleIndex);
                uint256 RbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
                bytes32 scheduleId = dcaManager.getScheduleId(address(docToken), scheduleIndex);
                vm.stopPrank();
                console.log("Lending token balance of DOC handler", lendingToken.balanceOf(address(docHandler)));
                vm.prank(SWAPPER);
                dcaManager.buyRbtc(USER, address(docToken), scheduleIndex, scheduleId);
                vm.startPrank(USER);
                uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(docToken), scheduleIndex);
                uint256 RbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
                vm.stopPrank();
                // Check that DOC was substracted and rBTC was added to user's balances
                assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, schedulePurchaseAmount);
                // assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, netPurchaseAmount / s_btcPrice);

                // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
                //     assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, netPurchaseAmount / s_btcPrice);
                // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
                assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                    RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase,
                    netPurchaseAmount / s_btcPrice,
                    0.75e16 // Allow a maximum difference of 0.75% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
                );
                // }

                totalDocSpent += netPurchaseAmount;
                totalDocRedeemed += schedulePurchaseAmount;
                // console.log("DOC redeemed", schedulePurchaseAmount);

                vm.warp(block.timestamp + schedulePurchasePeriod);
                // updateExchangeRate(schedulePurchasePeriod);
            }
        }
        console.log("Total DOC spent :", totalDocSpent);
        console.log("Total DOC redeemed :", totalDocRedeemed);
        vm.prank(USER);
        // assertEq(docHandler.getAccumulatedRbtcBalance(), totalDocSpent / s_btcPrice);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(), totalDocSpent / s_btcPrice);
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(),
            totalDocSpent / s_btcPrice,
            0.75e16 // Allow a maximum difference of 0.75% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
        );
        // }
    }

    function makeBatchPurchasesOneUser() internal {
        // uint256 prevDocHandlerBalance = address(docHandler).balance;

        uint256 prevDocHandlerBalance;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            prevDocHandlerBalance = address(docHandler).balance;
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            prevDocHandlerBalance = wrBtcToken.balanceOf(address(docHandler));
        }

        vm.prank(USER);
        uint256 userAccumulatedRbtcPrev = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        address[] memory users = new address[](NUM_OF_SCHEDULES);
        uint256[] memory scheduleIndexes = new uint256[](NUM_OF_SCHEDULES);
        uint256[] memory purchaseAmounts = new uint256[](NUM_OF_SCHEDULES);
        uint256[] memory purchasePeriods = new uint256[](NUM_OF_SCHEDULES);
        bytes32[] memory scheduleIds = new bytes32[](NUM_OF_SCHEDULES);

        uint256 totalNetPurchaseAmount;

        // Create the arrays for the batch purchase (in production, this is done in the back end)
        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = i;
            vm.startPrank(USER);
            uint256 schedulePurchaseAmount = dcaManager.getSchedulePurchaseAmount(address(docToken), scheduleIndex);
            uint256 schedulePurchasePeriod = dcaManager.getSchedulePurchasePeriod(address(docToken), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount, schedulePurchasePeriod);
            totalNetPurchaseAmount += schedulePurchaseAmount - fee;

            users[i] = USER; // Same user for has 5 schedules due for a purchase in this scenario
            scheduleIndexes[i] = i;
            vm.startPrank(OWNER);
            purchaseAmounts[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(docToken))[i].purchaseAmount;
            purchasePeriods[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(docToken))[i].purchasePeriod;
            scheduleIds[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(docToken))[i].scheduleId;
            vm.stopPrank();
        }
        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            vm.expectEmit(false, false, false, false);
            emit PurchaseRbtc__RbtcBought(USER, address(docToken), 0, scheduleIds[i], 0); // Never mind the actual values on this test
        }

        vm.expectEmit(true, false, false, false); // the amount of rBTC purchased won't match exactly neither the amount of DOC spent in the case of Sovryn due to rounding errors

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(docToken), totalNetPurchaseAmount / s_btcPrice, totalNetPurchaseAmount
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(docToken), (totalNetPurchaseAmount * 995) / (1000 * s_btcPrice), totalNetPurchaseAmount
            );
        }

        console.log("DOC balance of handler before calling batchBuyRbtc():", docToken.balanceOf(address(docHandler)));
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(docToken),
            scheduleIndexes,
            scheduleIds,
            purchaseAmounts,
            purchasePeriods,
            s_lendingProtocolIndex
        );

        // The balance of the DOC token handler contract gets incremented in exactly the purchased amount of rBTC
        // assertEq(postDocHandlerBalance - prevDocHandlerBalance, totalNetPurchaseAmount / s_btcPrice);

        uint256 postDocHandlerBalance;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            postDocHandlerBalance = address(docHandler).balance;
            // assertEq(postDocHandlerBalance - prevDocHandlerBalance, totalNetPurchaseAmount / s_btcPrice);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            postDocHandlerBalance = wrBtcToken.balanceOf(address(docHandler));
            // assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            //     postDocHandlerBalance - prevDocHandlerBalance,
            //     totalNetPurchaseAmount / s_btcPrice,
            //     0.5e16 // Allow a maximum difference of 0.5%
            // );
        }

        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            postDocHandlerBalance - prevDocHandlerBalance,
            totalNetPurchaseAmount / s_btcPrice,
            0.5e16 // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );

        vm.prank(USER);
        uint256 userAccumulatedRbtcPost = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();

        // The user's balance is also equal (since we're batching the purchases of 5 schedules but only one user)
        // assertEq(userAccumulatedRbtcPost - userAccumulatedRbtcPrev, totalNetPurchaseAmount / s_btcPrice);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(userAccumulatedRbtcPost - userAccumulatedRbtcPrev, totalNetPurchaseAmount / s_btcPrice);
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            userAccumulatedRbtcPost - userAccumulatedRbtcPrev,
            totalNetPurchaseAmount / s_btcPrice,
            0.5e16 // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );
        // }

        vm.warp(block.timestamp + 5 weeks); // warp to a time far in the future so all schedules are long due for a new purchase
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(docToken),
            scheduleIndexes,
            scheduleIds,
            purchaseAmounts,
            purchasePeriods,
            s_lendingProtocolIndex
        );
        // uint256 postDocHandlerBalance2 = address(docHandler).balance;

        uint256 postDocHandlerBalance2;

        // After a second purchase, we have the same increment
        // assertEq(postDocHandlerBalance2 - postDocHandlerBalance, totalNetPurchaseAmount / s_btcPrice);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            postDocHandlerBalance2 = address(docHandler).balance;
            // assertEq(postDocHandlerBalance2 - postDocHandlerBalance, totalNetPurchaseAmount / s_btcPrice);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            postDocHandlerBalance2 = wrBtcToken.balanceOf(address(docHandler));
            // assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            //     postDocHandlerBalance2 - postDocHandlerBalance,
            //     totalNetPurchaseAmount / s_btcPrice,
            //     0.5e16 // Allow a maximum difference of 0.5%
            // );
        }

        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            postDocHandlerBalance2 - postDocHandlerBalance,
            totalNetPurchaseAmount / s_btcPrice,
            0.5e16 // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );
    }

    function updateExchangeRate(uint256 daysPassed) internal {
        vm.roll(block.number + 2880 * daysPassed); // Jump to daysPassed days (2880 blocks per day) into the future so that some interest has been generated.
        vm.warp(block.timestamp + 2880 * daysPassed * 30);

        address newUser = makeAddr("Lending protocol new user");

        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            vm.prank(USER);
            docToken.transfer(newUser, 100 ether);
            vm.startPrank(newUser);
            docToken.approve(address(lendingToken), 100 ether);
            console.log("Exchange rate before DOC deposit:", lendingToken.exchangeRateStored());
            lendingToken.mint(100 ether);
            console.log("Exchange rate after DOC deposit:", lendingToken.exchangeRateStored());
            vm.stopPrank();
        } // else if (s_lendingProtocolIndex == SOVRYN_INDEX) {
            //     vm.prank(USER);
            //     docToken.transfer(newUser, 100 ether);
            //     vm.startPrank(newUser);
            //     docToken.approve(address(lendingToken), 100 ether);
            //     console.log("Exchange rate before DOC deposit:", lendingToken.tokenPrice());
            //     lendingToken.mint(newUser, 100 ether);
            //     console.log("Exchange rate after DOC deposit:", lendingToken.tokenPrice());
            //     vm.stopPrank();
            // }
    }
}
