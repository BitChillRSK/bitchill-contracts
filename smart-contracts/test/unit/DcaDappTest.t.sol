//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {DocHandler} from "../../src/DocHandler.sol";
import {DocHandlerMoc} from "../../src/DocHandlerMoc.sol";
import {DocHandlerDex} from "../../src/DocHandlerDex.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
// import {ITestDocHandler} from "../../test/interfaces/ITestDocHandler.sol";
import {AdminOperations} from "../../src/AdminOperations.sol";
import {IAdminOperations} from "../../src/interfaces/IAdminOperations.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import {DexHelperConfig} from "../../script/DexHelperConfig.s.sol";
import {DeployDexSwaps} from "../../script/DeployDexSwaps.s.sol";
import {DeployMocSwaps} from "../../script/DeployMocSwaps.s.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {MockKdocToken} from "../mocks/MockKdocToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";
import {MockWrbtcToken} from "../mocks/MockWrbtcToken.sol";
import {MockSwapRouter02} from "../mocks/MockSwapRouter02.sol";
import "../Constants.sol";
import "./TestsHelper.t.sol";

contract DcaDappTest is Test {
    DcaManager dcaManager;
    MockMocProxy mockMocProxy;
    // DocHandlerMoc docHandlerMoc;
    // DocHandlerDex docHandlerDex;
    // ITestDocHandler docHandler;
    DocHandler docHandler;
    AdminOperations adminOperations;
    MockDocToken mockDocToken;
    MockKdocToken mockKdocToken;
    MockWrbtcToken mockWrBtcToken;
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

    //////////////////////
    // Events ////////////
    //////////////////////

    // DcaManager
    // event DcaManager__TokenDeposited(address indexed user, address indexed token, uint256 amount);
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
    event TokenHandler__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 indexed rBtcBought,
        bytes32 scheduleId,
        uint256 amountSpent
    );
    event TokenHandler__SuccessfulRbtcBatchPurchase(
        address indexed token, uint256 indexed totalPurchasedRbtc, uint256 indexed totalDocAmountSpent
    );

    // AdminOperations
    event AdminOperations__TokenHandlerUpdated(address indexed token, address newHandler);

    //MockMocProxy
    event MockMocProxy__DocRedeemed(address indexed user, uint256 docAmount, uint256 btcAmount);

    //////////////////////
    // Errors ////////////
    //////////////////////
    // Ownable
    error OwnableUnauthorizedAccount(address account);

    /*//////////////////////////////////////////////////////////////
                            UNIT TESTS SETUP (MoC purchases)
    //////////////////////////////////////////////////////////////*/
    function setUp() public virtual {
        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            MocHelperConfig helperConfig;
            DeployMocSwaps deployContracts = new DeployMocSwaps();
            (adminOperations, docHandler, dcaManager, helperConfig) = deployContracts.run();
            // docHandler = DocHandler(docHandler);
            (address docTokenAddress, address mocProxyAddress, address kDocTokenAddress) =
                helperConfig.activeNetworkConfig();

            mockDocToken = MockDocToken(docTokenAddress);
            mockMocProxy = MockMocProxy(mocProxyAddress);
            mockKdocToken = MockKdocToken(kDocTokenAddress);

            // Set roles
            vm.prank(OWNER);
            adminOperations.setAdminRole(ADMIN);
            vm.prank(ADMIN);
            adminOperations.setSwapperRole(SWAPPER);

            // FeeCalculator helper test contract
            feeCalculator = new FeeCalculator();

            // Add tokenHandler
            vm.expectEmit(true, true, false, false);
            emit AdminOperations__TokenHandlerUpdated(docTokenAddress, address(docHandler));
            // vm.prank(OWNER);
            vm.prank(ADMIN);
            adminOperations.assignOrUpdateTokenHandler(docTokenAddress, address(docHandler));

            // Deal rBTC funds to user
            vm.deal(USER, STARTING_RBTC_USER_BALANCE);

            // Give the MoC proxy contract allowance
            mockDocToken.approve(mocProxyAddress, DOC_TO_DEPOSIT);

            // Mint DOC for the user
            if (block.chainid == 31337) {
                // Deal rBTC funds to MoC contract
                vm.deal(mocProxyAddress, 1000 ether);

                // Give the MoC proxy contract allowance to move DOC from docHandler
                // This is necessary for local tests because of how the mock contract works, but not for the live contract
                vm.prank(address(docHandler));

                mockDocToken.approve(mocProxyAddress, type(uint256).max);
                mockDocToken.mint(USER, USER_TOTAL_DOC);
            } else if (block.chainid == 30 || block.chainid == 31) {
                // bytes32 balanceSlot = keccak256(abi.encode(USER, uint256(DOC_BALANCES_SLOT)));
                // vm.store(address(mockDocToken), balanceSlot, bytes32(USER_TOTAL_DOC));
                // bytes32 balance = vm.load(address(mockDocToken), balanceSlot);
                // emit log_uint(uint256(balance));

                vm.prank(USER);
                console.log("Gas provided to mintDoc:", gasleft());
                // mockMocProxy.mintDoc{value: RBTC_TO_MINT_DOC * 11 / 10, gas: gasleft()}(RBTC_TO_MINT_DOC);
                mockMocProxy.mintDoc{value: 0.051 ether}(0.05 ether);
                // mockMocProxy.mintDocVendors{value: 0.051 ether}(0.05 ether, payable(address(0)));
            }

            // The starting point of the tests is that the user has already deposited 1000 DOC (so withdrawals can also be tested without much hassle)
            vm.startPrank(USER);
            mockDocToken.approve(address(docHandler), DOC_TO_DEPOSIT);
            dcaManager.createDcaSchedule(address(mockDocToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
            vm.stopPrank();
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            DexHelperConfig helperConfig;
            DeployDexSwaps deployContracts = new DeployDexSwaps();
            (adminOperations, docHandler, dcaManager, helperConfig) = deployContracts.run();
            // docHandler = DocHandler(docHandlerDex);
            DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

            // MockSwapRouter02 mockSwapRouter02;

            address docTokenAddress = networkConfig.docTokenAddress;
            address kDocTokenAddress = networkConfig.kdocTokenAddress;
            address wrBtcTokenAddress = networkConfig.wrbtcTokenAddress;
            address swapRouter02Address = networkConfig.swapRouter02Address;
            // address[] memory swapIntermediateTokens = networkConfig.swapIntermediateTokens;
            // uint24[] memory swapPoolFeeRates = networkConfig.swapPoolFeeRates;
            // address mocOracle = networkConfig.mocOracleAddress;

            mockDocToken = MockDocToken(docTokenAddress);
            mockKdocToken = MockKdocToken(kDocTokenAddress);
            mockWrBtcToken = MockWrbtcToken(wrBtcTokenAddress);
            // mockSwapRouter02 = MockSwapRouter02(swapRouter02Address);

            // FeeCalculator helper test contract
            feeCalculator = new FeeCalculator();

            // Set roles
            vm.prank(OWNER);
            adminOperations.setAdminRole(ADMIN);
            vm.prank(ADMIN);
            adminOperations.setSwapperRole(SWAPPER);

            // Add tokenHandler
            vm.expectEmit(true, true, false, false);
            emit AdminOperations__TokenHandlerUpdated(docTokenAddress, address(docHandler));
            vm.prank(ADMIN);
            adminOperations.assignOrUpdateTokenHandler(docTokenAddress, address(docHandler));

            // TODO: Think through the setup for DEX swapping tests

            // Mint DOC for the user
            mockDocToken.mint(USER, USER_TOTAL_DOC);
            // Deal 1000 rBTC to the mock SwapRouter02 contract, so that it can deposit rBTC on the mock WRBTC contract
            // to simulate that the DocHandlerDex contract has received WRBTC after calling the `exactInput()` function
            vm.deal(swapRouter02Address, 1000 ether);

            // mockWrBtcToken.deposit{value: 1E18}();

            // The starting point of the tests is that the user has already deposited 1000 DOC (so withdrawals can also be tested without much hassle)
            vm.startPrank(USER);
            mockDocToken.approve(address(docHandler), DOC_TO_DEPOSIT);
            dcaManager.createDcaSchedule(address(mockDocToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
            vm.stopPrank();
        } else {
            revert("Invalid deploy environment");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      UNIT TESTS COMMON FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function depositDoc() internal returns (uint256, uint256) {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        mockDocToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(mockDocToken)).length - 1)
        );
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenDeposited(address(mockDocToken), USER, DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit DcaManager__TokenBalanceUpdated(address(mockDocToken), scheduleId, 2 * DOC_TO_DEPOSIT); // 2 *, since a previous deposit is made in the setup
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        // assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        vm.stopPrank();
        return (userBalanceAfterDeposit, userBalanceBeforeDeposit);
    }

    function withdrawDoc() internal {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenWithdrawn(address(mockDocToken), USER, DOC_TO_DEPOSIT);
        dcaManager.withdrawToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 remainingAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(remainingAmount, 0);
        vm.stopPrank();
    }

    function createSeveralDcaSchedules() internal {
        vm.startPrank(USER);
        mockDocToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
        uint256 purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES;
        // Delete the schedule created in setUp to have all five schedules with the same amounts
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(mockDocToken)).length - 1)
        );
        dcaManager.deleteDcaSchedule(address(mockDocToken), scheduleId);
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = SCHEDULE_INDEX + i;
            uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
            uint256 userBalanceBeforeDeposit;
            if (dcaManager.getMyDcaSchedules(address(mockDocToken)).length > scheduleIndex) {
                userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
            } else {
                userBalanceBeforeDeposit = 0;
            }
            scheduleId = keccak256(
                abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(mockDocToken)).length)
            );
            // console.log("scheduleId is", vm.toString(scheduleId));
            vm.expectEmit(true, true, true, true);
            emit DcaManager__DcaScheduleCreated(
                USER, address(mockDocToken), scheduleId, docToDeposit, purchaseAmount, purchasePeriod
            );
            dcaManager.createDcaSchedule(address(mockDocToken), docToDeposit, purchaseAmount, purchasePeriod);
            uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
            assertEq(docToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
            assertEq(purchaseAmount, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex));
            assertEq(purchasePeriod, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex));
        }
        vm.stopPrank();
    }

    function makeSinglePurchase() internal {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        uint256 RbtcBalanceBeforePurchase = docHandler.getAccumulatedRbtcBalance();
        IDcaManager.DcaDetails[] memory dcaDetails = dcaManager.getMyDcaSchedules(address(mockDocToken));
        vm.stopPrank();

        uint256 fee = feeCalculator.calculateFee(DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        uint256 netPurchaseAmount = DOC_TO_SPEND - fee;

        // vm.expectEmit(true, true, true, false);
        // emit TokenHandler__RbtcBought(
        //     USER,
        //     address(mockDocToken),
        //     netPurchaseAmount / BTC_PRICE,
        //     dcaDetails[SCHEDULE_INDEX].scheduleId,
        //     netPurchaseAmount
        // );
        // vm.prank(OWNER);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX, dcaDetails[SCHEDULE_INDEX].scheduleId);

        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        uint256 RbtcBalanceAfterPurchase = docHandler.getAccumulatedRbtcBalance();
        vm.stopPrank();

        // Check that DOC was substracted and rBTC was added to user's balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, netPurchaseAmount / BTC_PRICE);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase,
                netPurchaseAmount / BTC_PRICE,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }

    function makeSeveralPurchasesWithSeveralSchedules() internal returns (uint256 totalDocSpent) {
        // createSeveralDcaSchedules();

        uint8 numOfPurchases = 5;
        uint256 totalDocRedeemed;

        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            uint256 scheduleIndex = i;
            vm.startPrank(USER);
            uint256 schedulePurchaseAmount = dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex);
            uint256 schedulePurchasePeriod = dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount, schedulePurchasePeriod);
            uint256 netPurchaseAmount = schedulePurchaseAmount - fee;

            for (uint8 j; j < numOfPurchases; ++j) {
                vm.startPrank(USER);
                uint256 docBalanceBeforePurchase =
                    dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
                uint256 RbtcBalanceBeforePurchase = docHandler.getAccumulatedRbtcBalance();
                bytes32 scheduleId = dcaManager.getScheduleId(address(mockDocToken), scheduleIndex);
                vm.stopPrank();
                // vm.prank(OWNER);
                vm.prank(SWAPPER);
                dcaManager.buyRbtc(USER, address(mockDocToken), scheduleIndex, scheduleId);
                vm.startPrank(USER);
                uint256 docBalanceAfterPurchase =
                    dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
                uint256 RbtcBalanceAfterPurchase = docHandler.getAccumulatedRbtcBalance();
                vm.stopPrank();
                // Check that DOC was substracted and rBTC was added to user's balances
                assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, schedulePurchaseAmount);
                // assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, netPurchaseAmount / BTC_PRICE);

                if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
                    assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, netPurchaseAmount / BTC_PRICE);
                } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
                    assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                        RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase,
                        netPurchaseAmount / BTC_PRICE,
                        0.5e16 // Allow a maximum difference of 0.5%
                    );
                }

                totalDocSpent += netPurchaseAmount;
                totalDocRedeemed += schedulePurchaseAmount;
                // console.log("DOC redeemed", schedulePurchaseAmount);

                vm.warp(block.timestamp + schedulePurchasePeriod);
            }
        }
        console.log("Total DOC spent :", totalDocSpent);
        console.log("Total DOC redeemed :", totalDocRedeemed);
        vm.prank(USER);
        // assertEq(docHandler.getAccumulatedRbtcBalance(), totalDocSpent / BTC_PRICE);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            assertEq(docHandler.getAccumulatedRbtcBalance(), totalDocSpent / BTC_PRICE);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                docHandler.getAccumulatedRbtcBalance(),
                totalDocSpent / BTC_PRICE,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }

    function makeBatchPurchasesOneUser() internal {
        // uint256 prevDocHandlerBalance = address(docHandler).balance;

        uint256 prevDocHandlerBalance;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            prevDocHandlerBalance = address(docHandler).balance;
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            prevDocHandlerBalance = mockWrBtcToken.balanceOf(address(docHandler));
        }

        vm.prank(USER);
        uint256 userAccumulatedRbtcPrev = docHandler.getAccumulatedRbtcBalance();
        // vm.prank(OWNER);
        // address user = dcaManager.getUsers()[0]; // Only one user in this test, but several schedules
        // uint256 numOfPurchases = dcaManager.ownerGetUsersDcaSchedules(user, address(mockDocToken)).length;
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
            uint256 schedulePurchaseAmount = dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex);
            uint256 schedulePurchasePeriod = dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount, schedulePurchasePeriod);
            totalNetPurchaseAmount += schedulePurchaseAmount - fee;

            users[i] = USER; // Same user for has 5 schedules due for a purchase in this scenario
            scheduleIndexes[i] = i;
            vm.startPrank(OWNER);
            purchaseAmounts[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(mockDocToken))[i].purchaseAmount;
            purchasePeriods[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(mockDocToken))[i].purchasePeriod;
            scheduleIds[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(mockDocToken))[i].scheduleId;
            vm.stopPrank();
        }
        for (uint8 i; i < NUM_OF_SCHEDULES; ++i) {
            vm.expectEmit(false, false, false, false);
            emit TokenHandler__RbtcBought(USER, address(mockDocToken), 0, scheduleIds[i], 0); // Never mind the actual values on this test
        }

        vm.expectEmit(true, true, true, false);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            emit TokenHandler__SuccessfulRbtcBatchPurchase(
                address(mockDocToken), totalNetPurchaseAmount / BTC_PRICE, totalNetPurchaseAmount
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            emit TokenHandler__SuccessfulRbtcBatchPurchase(
                address(mockDocToken), (totalNetPurchaseAmount * 995) / (1000 * BTC_PRICE), totalNetPurchaseAmount
            );
        }

        // vm.prank(OWNER);
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users, address(mockDocToken), scheduleIndexes, scheduleIds, purchaseAmounts, purchasePeriods
        );

        // The balance of the DOC token handler contract gets incremented in exactly the purchased amount of rBTC
        // assertEq(postDocHandlerBalance - prevDocHandlerBalance, totalNetPurchaseAmount / BTC_PRICE);

        uint256 postDocHandlerBalance;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            postDocHandlerBalance = address(docHandler).balance;
            assertEq(postDocHandlerBalance - prevDocHandlerBalance, totalNetPurchaseAmount / BTC_PRICE);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            postDocHandlerBalance = mockWrBtcToken.balanceOf(address(docHandler));
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                postDocHandlerBalance - prevDocHandlerBalance,
                totalNetPurchaseAmount / BTC_PRICE,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }

        vm.prank(USER);
        uint256 userAccumulatedRbtcPost = docHandler.getAccumulatedRbtcBalance();

        // The user's balance is also equal (since we're batching the purchases of 5 schedules but only one user)
        // assertEq(userAccumulatedRbtcPost - userAccumulatedRbtcPrev, totalNetPurchaseAmount / BTC_PRICE);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            assertEq(userAccumulatedRbtcPost - userAccumulatedRbtcPrev, totalNetPurchaseAmount / BTC_PRICE);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                userAccumulatedRbtcPost - userAccumulatedRbtcPrev,
                totalNetPurchaseAmount / BTC_PRICE,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }

        vm.warp(block.timestamp + 5 weeks); // warp to a time far in the future so all schedules are long due for a new purchase
        // vm.prank(OWNER);
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users, address(mockDocToken), scheduleIndexes, scheduleIds, purchaseAmounts, purchasePeriods
        );
        // uint256 postDocHandlerBalance2 = address(docHandler).balance;

        uint256 postDocHandlerBalance2;

        // After a second purchase, we have the same increment
        // assertEq(postDocHandlerBalance2 - postDocHandlerBalance, totalNetPurchaseAmount / BTC_PRICE);

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            postDocHandlerBalance2 = address(docHandler).balance;
            assertEq(postDocHandlerBalance2 - postDocHandlerBalance, totalNetPurchaseAmount / BTC_PRICE);
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            postDocHandlerBalance2 = mockWrBtcToken.balanceOf(address(docHandler));
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                postDocHandlerBalance2 - postDocHandlerBalance,
                totalNetPurchaseAmount / BTC_PRICE,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }
}
