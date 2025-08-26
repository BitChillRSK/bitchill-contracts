//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
// import {RbtcBaseTest} from "./RbtcBaseTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {IDcaManagerAccessControl} from "../../src/interfaces/IDcaManagerAccessControl.sol";
import "../../script/Constants.sol";

contract RbtcPurchaseTest is DcaDappTest {

    event PurchaseRbtc__rBtcRescued(address indexed stuckUserContract, address indexed rescueAddress, uint256 amount);

    function setUp() public override {
        super.setUp();
    }

    //////////////////////
    /// Purchase tests ///
    //////////////////////
    function testSinglePurchase() external {
        super.makeSinglePurchase();
    }

    function testCannotBuyIfScheduleIdAndIndexMismatch() external {
        bytes32 wrongScheduleId = keccak256(abi.encodePacked(USER, address(stablecoin), block.timestamp, uint256(999)));
        vm.expectRevert(IDcaManager.DcaManager__ScheduleIdAndIndexMismatch.selector);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, wrongScheduleId);
    }

    function testCannotBuyIfInexistentSchedule() external {
        bytes32 scheduleId = dcaManager.getScheduleId(USER, address(stablecoin), SCHEDULE_INDEX);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX + 1, scheduleId);
    }

    function testCannotBuyIfPeriodNotElapsed() external {
        vm.startPrank(USER);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        bytes32 scheduleId = dcaManager.getMyScheduleId(address(stablecoin), SCHEDULE_INDEX);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, scheduleId, AMOUNT_TO_SPEND);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, scheduleId, MIN_PURCHASE_PERIOD);
        vm.stopPrank();
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId); // first purchase
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__CannotBuyIfPurchasePeriodHasNotElapsed.selector,
            block.timestamp + MIN_PURCHASE_PERIOD - block.timestamp
        );
        vm.expectRevert(encodedRevert);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId); // second purchase
    }

    function testSeveralPurchasesOneSchedule() external {
        uint256 numOfPurchases = 5;

        uint256 fee = feeCalculator.calculateFee(AMOUNT_TO_SPEND);
        uint256 netPurchaseAmount = AMOUNT_TO_SPEND - fee;

        bytes32 scheduleId = dcaManager.getScheduleId(USER, address(stablecoin), SCHEDULE_INDEX);
        vm.prank(USER);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, scheduleId, MIN_PURCHASE_PERIOD);
        for (uint256 i; i < numOfPurchases; ++i) {
            vm.prank(SWAPPER);
            dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);
            vm.warp(vm.getBlockTimestamp() + MIN_PURCHASE_PERIOD);
        }
        vm.prank(USER);
        // assertEq(docHandler.getAccumulatedRbtcBalance(), (netPurchaseAmount / s_btcPrice) * numOfPurchases);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(
        //         IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(),
        //         (netPurchaseAmount / s_btcPrice) * numOfPurchases
        //     );
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(),
            (netPurchaseAmount / s_btcPrice) * numOfPurchases,
            MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap purchases)
        );
        // }
    }

    function testRevertPurchasetIfStablecoinRunsOut() external {
        uint256 numOfPurchases = AMOUNT_TO_DEPOSIT / AMOUNT_TO_SPEND;
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length));
        for (uint256 i; i < numOfPurchases; ++i) {
            // vm.prank(OWNER);
            vm.prank(SWAPPER);
            dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);
            vm.warp(vm.getBlockTimestamp() + MIN_PURCHASE_PERIOD);
        }
        // Attempt to purchase once more
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__ScheduleBalanceNotEnoughForPurchase.selector, SCHEDULE_INDEX, scheduleId, address(stablecoin), 0
        );
        vm.expectRevert(encodedRevert);
        // vm.prank(OWNER);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);
    }

    function testSeveralPurchasesWithSeveralSchedules() external {
        super.createSeveralDcaSchedules();
        super.makeSeveralPurchasesWithSeveralSchedules();
    }

    function testOnlySwapperCanCallDcaManagerToPurchase() external {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        bytes memory encodedRevert = abi.encodeWithSelector(IDcaManager.DcaManager__UnauthorizedSwapper.selector, USER);
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length));
        vm.expectRevert(encodedRevert);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);
        uint256 docBalanceAfterPurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 RbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();
        // Check that balances didn't change
        assertEq(docBalanceBeforePurchase, docBalanceAfterPurchase);
        assertEq(RbtcBalanceAfterPurchase, rbtcBalanceBeforePurchase);
    }

    function testOnlyDcaManagerCanPurchase() external {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length - 1)
        );
        vm.expectRevert(IDcaManagerAccessControl.DcaManagerAccessControl__OnlyDcaManagerCanCall.selector);
        IPurchaseRbtc(address(docHandler)).buyRbtc(USER, scheduleId, MIN_PURCHASE_AMOUNT);
        uint256 docBalanceAfterPurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 RbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();
        // Check that balances didn't change
        assertEq(docBalanceBeforePurchase, docBalanceAfterPurchase);
        assertEq(RbtcBalanceAfterPurchase, rbtcBalanceBeforePurchase);
    }

    function testBatchPurchasesOneUser() external {
        super.createSeveralDcaSchedules();
        super.makeBatchPurchasesOneUser();
    }

    function testBatchPurchaseFailsIfArraysEmpty() external {
        address[] memory emptyAddressArray;
        uint256[] memory emptyUintArray;
        bytes32[] memory emptyBytes32Array;
        vm.expectRevert(IDcaManager.DcaManager__EmptyBatchPurchaseArrays.selector);
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            emptyAddressArray,
            address(stablecoin),
            emptyUintArray,
            emptyBytes32Array,
            emptyUintArray,
            s_lendingProtocolIndex
        );
    }

    function testBatchPurchaseFailsIfArraysHaveDifferentLenghts() external {
        address[] memory users = new address[](1);
        uint256[] memory dummyUintArray = new uint256[](3);
        bytes32[] memory dummyBytes32Array = new bytes32[](3);
        vm.expectRevert(IDcaManager.DcaManager__BatchPurchaseArraysLengthMismatch.selector);
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(stablecoin),
            dummyUintArray,
            dummyBytes32Array,
            dummyUintArray,
            s_lendingProtocolIndex
        );
    }

    function testPurchaseFailsIfIdAndIndexDontMatch() external {
        bytes32 scheduleId = keccak256(
            abi.encodePacked("dummyStuff", address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length)
        );

        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();

        vm.expectRevert(IDcaManager.DcaManager__ScheduleIdAndIndexMismatch.selector);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);

        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getMyScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();

        // Check that there are no changes in balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, 0);
        assertEq(rbtcBalanceAfterPurchase - rbtcBalanceBeforePurchase, 0);
    }

    function testBatchPurchaseFailsIfIdAndIndexDontMatch() external {
        super.createSeveralDcaSchedules();

        bytes32 scheduleId = keccak256(
            abi.encodePacked("dummyStuff", address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length)
        );

        uint256 prevDocHandlerMocBalance = address(docHandler).balance;
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
            uint256 schedulePurchaseAmount = dcaManager.getMySchedulePurchaseAmount(address(stablecoin), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount);
            totalNetPurchaseAmount += schedulePurchaseAmount - fee;

            users[i] = USER; // Same user for has 5 schedules due for a purchase in this scenario
            scheduleIndexes[i] = i;
            vm.startPrank(OWNER);
            purchaseAmounts[i] = dcaManager.getDcaSchedules(users[0], address(stablecoin))[i].purchaseAmount;
            purchasePeriods[i] = dcaManager.getDcaSchedules(users[0], address(stablecoin))[i].purchasePeriod;
            scheduleIds[i] = scheduleId;
            vm.stopPrank();
        }
        vm.expectRevert(IDcaManager.DcaManager__ScheduleIdAndIndexMismatch.selector);
        vm.prank(SWAPPER);
        dcaManager.batchBuyRbtc(
            users,
            address(stablecoin),
            scheduleIndexes,
            scheduleIds,
            purchaseAmounts,
            s_lendingProtocolIndex
        );

        uint256 postDocHandlerMocBalance = address(docHandler).balance;

        // The balance of the token handler contract gets incremented in exactly the purchased amount of rBTC
        assertEq(postDocHandlerMocBalance - prevDocHandlerMocBalance, 0);

        vm.prank(USER);
        uint256 userAccumulatedRbtcPost = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        // The user's balance is also equal (since we're batching the purchases of 5 schedules but only one user)
        assertEq(userAccumulatedRbtcPost - userAccumulatedRbtcPrev, 0);
    }
    
    function testRescueRbtcFromStuckContract() external {
        // First do a purchase to accumulate some rBTC on the handler contract
        super.makeSinglePurchase();

        address stuckContract = USER;
        // Deploy bytecode that reverts when receiving rBTC to the user address to test the rescue function
        vm.etch(stuckContract, hex"60006000fd"); // simplest bytecode to always revert
        
        // Verify the balance was set correctly
        vm.prank(stuckContract);
        uint256 stuckContractBalance = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        assertGt(stuckContractBalance, 0);

        address rescueAddress = makeAddr("rescueAddress");
        
        // Try to rescue the funds
        vm.expectEmit(true, true, true, true);
        emit PurchaseRbtc__rBtcRescued(stuckContract, rescueAddress, stuckContractBalance);
        vm.prank(OWNER);
        IPurchaseRbtc(address(docHandler)).withdrawStuckRbtc(stuckContract, rescueAddress);
        
        // Verify rBTC was correctly sent to the rescue address
        assertGt(rescueAddress.balance, 0);
        
        // Verify the stuck contract's accumulated rBTC is now 0
        vm.prank(stuckContract);
        assertEq(IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(), 0);
    }

    function testCannotRescueIfNoAccumulatedRbtc() external {
        // Create a mock contract address 
        address stuckContract = makeAddr("stuckContract");
        address rescueAddress = makeAddr("rescueAddress");
        
        // Set up the revert expectation
        vm.expectRevert(IPurchaseRbtc.PurchaseRbtc__NoAccumulatedRbtcToWithdraw.selector);
        
        // Try to rescue the funds when there are none
        vm.prank(OWNER);
        IPurchaseRbtc(address(docHandler)).withdrawStuckRbtc(stuckContract, rescueAddress);
    }

    function testOnlyUserCanWithdrawRbtc() external {
        vm.expectRevert();
        vm.prank(makeAddr("notUser"));
        IPurchaseRbtc(address(docHandler)).withdrawAccumulatedRbtc(USER);
    }

    // New test: exhaust handler balance across multiple users and schedules without revert
    // @notice: this test won't pass for Tropykus on forked chains because updating
    // the exchange rate requires to roll to a future block, which makes the MoC oracle
    // throw an "Oracle have no Bitcoin Price" error.
    function testDepleteHandlerBalanceDoesNotRevert() external {
        // Prepare a second user
        address SECOND_USER = makeAddr("SECOND_USER");

        // Fund SECOND_USER with rBTC for gas
        vm.deal(SECOND_USER, 10 ether);

        // Give SECOND_USER enough stablecoin
        uint256 secondUserInitialStable = USER_TOTAL_AMOUNT;
        if (block.chainid == ANVIL_CHAIN_ID) {
            // Local tests – mint directly
            stablecoin.mint(SECOND_USER, secondUserInitialStable);
        } else {
            // On forked chains we transfer from USER (who already owns tokens)
            vm.startPrank(USER);
            stablecoin.transfer(SECOND_USER, secondUserInitialStable);
            vm.stopPrank();
        }

        // Define how many schedules each user will have
        uint256 SCHEDULES_PER_USER = 3;

        // USER already has 1 schedule from setUp → create 2 more so both users end up with 3 each
        _createAdditionalSchedules(USER, SCHEDULES_PER_USER - 1);
        // Create 3 schedules for SECOND_USER
        _createAdditionalSchedules(SECOND_USER, SCHEDULES_PER_USER);

        // Total number of schedules in batch operations
        uint256 totalSchedules = SCHEDULES_PER_USER * 2;

        // Each schedule can execute AMOUNT_TO_DEPOSIT / AMOUNT_TO_SPEND purchases before running out of balance
        uint256 purchasesPerSchedule = AMOUNT_TO_DEPOSIT / AMOUNT_TO_SPEND;

        // Store initial interest accrued (should be 0 initially)
        uint256 initialInterestUser = dcaManager.getInterestAccrued(USER, address(stablecoin), s_lendingProtocolIndex);
        uint256 initialInterestSecondUser = dcaManager.getInterestAccrued(SECOND_USER, address(stablecoin), s_lendingProtocolIndex);
        
        // Both users should have 0 interest initially
        assertEq(initialInterestUser, 0, "USER should have 0 interest initially");
        assertEq(initialInterestSecondUser, 0, "SECOND_USER should have 0 interest initially");

        // Perform the required number of purchase rounds
        for (uint256 round; round < purchasesPerSchedule; ++round) {
            // Build batch arrays
            address[] memory buyers = new address[](totalSchedules);
            uint256[] memory scheduleIndexes = new uint256[](totalSchedules);
            bytes32[] memory scheduleIds = new bytes32[](totalSchedules);
            uint256[] memory purchaseAmounts = new uint256[](totalSchedules);

            uint256 idx;
            // Fill arrays for USER
            for (uint256 i; i < SCHEDULES_PER_USER; ++i) {
                buyers[idx] = USER;
                scheduleIndexes[idx] = i;
                purchaseAmounts[idx] = AMOUNT_TO_SPEND;
                scheduleIds[idx] = dcaManager.getScheduleId(USER, address(stablecoin), i);
                ++idx;
            }
            // Fill arrays for SECOND_USER
            for (uint256 i; i < SCHEDULES_PER_USER; ++i) {
                buyers[idx] = SECOND_USER;
                scheduleIndexes[idx] = i;
                purchaseAmounts[idx] = AMOUNT_TO_SPEND;
                scheduleIds[idx] = dcaManager.getScheduleId(SECOND_USER, address(stablecoin), i);
                ++idx;
            }

            // Execute batch purchase as SWAPPER
            vm.prank(SWAPPER);
            dcaManager.batchBuyRbtc(
                buyers,
                address(stablecoin),
                scheduleIndexes,
                scheduleIds,
                purchaseAmounts,
                s_lendingProtocolIndex
            );

            // Advance time and update exchange rate so future purchases are allowed and interest accrues
            updateExchangeRate(MIN_PURCHASE_PERIOD);
        }

        // After time has passed and multiple purchase rounds, check that interest has accrued
        uint256 finalInterestUser = dcaManager.getInterestAccrued(USER, address(stablecoin), s_lendingProtocolIndex);
        uint256 finalInterestSecondUser = dcaManager.getInterestAccrued(SECOND_USER, address(stablecoin), s_lendingProtocolIndex);
        
        // Both users should have accrued some interest during the test
        assertGt(finalInterestUser, initialInterestUser, "USER should have accrued interest during the test");
        assertGt(finalInterestSecondUser, initialInterestSecondUser, "SECOND_USER should have accrued interest during the test");
        
        // The interest should be positive (greater than 0) since time has passed
        assertGt(finalInterestUser, 0, "USER should have positive interest after time passage");
        assertGt(finalInterestSecondUser, 0, "SECOND_USER should have positive interest after time passage");

        // After depletion all schedule balances should be zero
        for (uint256 i; i < SCHEDULES_PER_USER; ++i) {
            assertEq(dcaManager.getScheduleTokenBalance(USER, address(stablecoin), i), 0);
            assertEq(dcaManager.getScheduleTokenBalance(SECOND_USER, address(stablecoin), i), 0);
        }

        // Handler must hold no DOC (stablecoin) after final purchase
        assertEq(stablecoin.balanceOf(address(docHandler)), 0);

        // Withdrawing interest should not revert
        address[] memory tokens = new address[](1);
        tokens[0] = address(stablecoin);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = s_lendingProtocolIndex;
        vm.prank(USER);
        dcaManager.withdrawAllAccumulatedInterest(tokens, lendingProtocolIndexes);

        // Withdrawing interest should not revert
        vm.prank(SECOND_USER);
        dcaManager.withdrawAllAccumulatedInterest(tokens, lendingProtocolIndexes);
    }

    /// @dev helper to create additional schedules for a user
    function _createAdditionalSchedules(address user, uint256 num) internal {
        if (num == 0) return;
        vm.startPrank(user);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT * num);
        for (uint256 i; i < num; ++i) {
            dcaManager.createDcaSchedule(
                address(stablecoin),
                AMOUNT_TO_DEPOSIT,
                AMOUNT_TO_SPEND,
                MIN_PURCHASE_PERIOD,
                s_lendingProtocolIndex
            );
        }
        vm.stopPrank();
    }
}
