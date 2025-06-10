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

    function testCannotBuyIfPeriodNotElapsed() external {
        vm.startPrank(USER);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_SPEND);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_PERIOD);
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length - 1)
        );
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

        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length));

        vm.prank(USER);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_PERIOD);
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

    function testRevertPurchasetIfDocRunsOut() external {
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
            IDcaManager.DcaManager__ScheduleBalanceNotEnoughForPurchase.selector, address(stablecoin), 0
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
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        bytes memory encodedRevert = abi.encodeWithSelector(IDcaManager.DcaManager__UnauthorizedSwapper.selector, USER);
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length));
        vm.expectRevert(encodedRevert);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 RbtcBalanceAfterPurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();
        // Check that balances didn't change
        assertEq(docBalanceBeforePurchase, docBalanceAfterPurchase);
        assertEq(RbtcBalanceAfterPurchase, rbtcBalanceBeforePurchase);
    }

    function testOnlyDcaManagerCanPurchase() external {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, address(stablecoin), block.timestamp, dcaManager.getMyDcaSchedules(address(stablecoin)).length - 1)
        );
        vm.expectRevert(IDcaManagerAccessControl.DcaManagerAccessControl__OnlyDcaManagerCanCall.selector);
        IPurchaseRbtc(address(docHandler)).buyRbtc(USER, scheduleId, MIN_PURCHASE_AMOUNT);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
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
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
        uint256 rbtcBalanceBeforePurchase = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        vm.stopPrank();

        vm.expectRevert(IDcaManager.DcaManager__ScheduleIdAndIndexMismatch.selector);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), SCHEDULE_INDEX, scheduleId);

        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(stablecoin), SCHEDULE_INDEX);
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
            uint256 schedulePurchaseAmount = dcaManager.getSchedulePurchaseAmount(address(stablecoin), scheduleIndex);
            vm.stopPrank();
            uint256 fee = feeCalculator.calculateFee(schedulePurchaseAmount);
            totalNetPurchaseAmount += schedulePurchaseAmount - fee;

            users[i] = USER; // Same user for has 5 schedules due for a purchase in this scenario
            scheduleIndexes[i] = i;
            vm.startPrank(OWNER);
            purchaseAmounts[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(stablecoin))[i].purchaseAmount;
            purchasePeriods[i] = dcaManager.ownerGetUsersDcaSchedules(users[0], address(stablecoin))[i].purchasePeriod;
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
}
