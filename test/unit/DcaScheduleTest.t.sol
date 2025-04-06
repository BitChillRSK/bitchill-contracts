//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import "../Constants.sol";

contract DcaScheduleTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /////////////////////////////////
    /// DcaSchedule tests  //////////
    /////////////////////////////////

    function testCreateDcaSchedule() external {
        vm.startPrank(USER);
        uint256 scheduleIndex = dcaManager.getMyDcaSchedules(address(docToken)).length;
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        vm.expectEmit(true, true, true, true);
        emit DcaManager__DcaScheduleCreated(
            USER, address(docToken), scheduleId, DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD
        );
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        uint256 scheduleBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(docToken), scheduleIndex);
        assertEq(DOC_TO_DEPOSIT, scheduleBalanceAfterDeposit);
        assertEq(DOC_TO_SPEND, dcaManager.getSchedulePurchaseAmount(address(docToken), scheduleIndex));
        assertEq(MIN_PURCHASE_PERIOD, dcaManager.getSchedulePurchasePeriod(address(docToken), scheduleIndex));
        vm.stopPrank();
    }

    function testDcaScheduleIdsDontCollide() external {
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT);
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        console.log("First timestamp", block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit DcaManager__DcaScheduleCreated(
            USER, address(docToken), scheduleId, DOC_TO_DEPOSIT / 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD
        );
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT / 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        bytes32 scheduleId2 =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        console.log("Second timestamp", block.timestamp);
        vm.expectEmit(true, true, true, true);
        emit DcaManager__DcaScheduleCreated(
            USER, address(docToken), scheduleId2, DOC_TO_DEPOSIT / 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD
        );
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT / 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        assert(scheduleId != scheduleId2);
        vm.stopPrank();
    }

    function testUpdateDcaSchedule() external {
        uint256 newPurchaseAmount = DOC_TO_SPEND / 2;
        uint256 newPurchasePeriod = MIN_PURCHASE_PERIOD * 10;
        uint256 extraDocToDeposit = DOC_TO_DEPOSIT / 3;
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        docToken.approve(address(docHandler), extraDocToDeposit);
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length - 1)
        );
        vm.expectEmit(true, true, true, true);
        emit DcaManager__DcaScheduleUpdated(
            USER, address(docToken), scheduleId, extraDocToDeposit, newPurchaseAmount, newPurchasePeriod
        );
        dcaManager.updateDcaSchedule(
            address(docToken), SCHEDULE_INDEX, extraDocToDeposit, newPurchaseAmount, newPurchasePeriod
        );
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX);
        assertEq(extraDocToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        assertEq(newPurchaseAmount, dcaManager.getSchedulePurchaseAmount(address(docToken), SCHEDULE_INDEX));
        assertEq(newPurchasePeriod, dcaManager.getSchedulePurchasePeriod(address(docToken), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testDeleteDcaSchedule() external {
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT * 5);
        // Create two schedules in different blocks
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        vm.warp(block.timestamp + 1 minutes);
        bytes32 scheduleId2 =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 3, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        console.log("scheduleId is", vm.toString(scheduleId));
        console.log("scheduleId2 is", vm.toString(scheduleId2));
        // Delete one
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
        // Check that there are two (the one created in setUp() and the second one created in this test)
        assertEq(dcaManager.getMyDcaSchedules(address(docToken)).length, 2);
        // Check that the deleted one was the first one created in this test and its place was taken by the second one
        assertEq(dcaManager.getMyDcaSchedules(address(docToken))[1].scheduleId, scheduleId2);
        vm.stopPrank();
    }

    function testDeleteTwoDcaSchedules() public {
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT * 5);
        // Create two schedules in different blocks
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        vm.warp(block.timestamp + 1 minutes);
        bytes32 scheduleId2 =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 3, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        console.log("scheduleId is", vm.toString(scheduleId));
        console.log(vm.toString(dcaManager.getMyDcaSchedules(address(docToken))[1].scheduleId));
        console.log("scheduleId 2 is", vm.toString(scheduleId2));
        console.log(vm.toString(dcaManager.getMyDcaSchedules(address(docToken))[2].scheduleId));
        // Delete one
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
        // Delete the second one passing the same index, since the first one was already deleted
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId2);
        // Check only the schedule created in setUp() remains
        assertEq(dcaManager.getMyDcaSchedules(address(docToken)).length, 1);
        vm.stopPrank();
    }

    /**
     * @notice This was just a test to compare options in terms of gas consumption
     */
    function testDeleteSeveraldcaSchedules() external {
        super.createSeveralDcaSchedules();
        vm.startPrank(USER);
        for (int256 i = int256(NUM_OF_SCHEDULES) - 1; i >= 0; --i) {
            bytes32 scheduleId = keccak256(abi.encodePacked(USER, block.timestamp, uint256(i)));
            dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
        }
        vm.stopPrank();
    }

    /**
     * @notice this test shows that a transaction that aims to delete the last schedule in the array after another schedule has been deleted in a previous transaction
     * reverts if both transactions have been included in the same block // this has to be prevented in the front end
     */
    function testCannotDeleteLastDcaScheduleInTheSameBlock() external {
        vm.startPrank(USER);
        docToken.approve(address(docHandler), DOC_TO_DEPOSIT * 5);
        // Create two schedules in different blocks
        bytes32 scheduleId =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        vm.warp(block.timestamp + 1 minutes);
        bytes32 scheduleId2 =
            keccak256(abi.encodePacked(USER, block.timestamp, dcaManager.getMyDcaSchedules(address(docToken)).length));
        dcaManager.createDcaSchedule(
            address(docToken), DOC_TO_DEPOSIT * 3, DOC_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
        );
        console.log("scheduleId is", vm.toString(scheduleId));
        console.log(vm.toString(dcaManager.getMyDcaSchedules(address(docToken))[1].scheduleId));
        console.log("scheduleId 2 is", vm.toString(scheduleId2));
        console.log(vm.toString(dcaManager.getMyDcaSchedules(address(docToken))[2].scheduleId));
        // Delete one
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
        // Deleting the second one fails, because when the first one was deleted, the second one was moved to its index
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId2);
        vm.stopPrank();
    }

    function testCreateSeveralDcaSchedules() external {
        super.createSeveralDcaSchedules();
    }

    function testCannotUpdateInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.depositToken(address(docToken), SCHEDULE_INDEX + 1, DOC_TO_DEPOSIT);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.setPurchaseAmount(address(docToken), SCHEDULE_INDEX + 1, DOC_TO_SPEND);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.setPurchaseAmount(address(docToken), SCHEDULE_INDEX + 1, MIN_PURCHASE_PERIOD);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.updateDcaSchedule(address(docToken), 1, 1, 1, 1);
        vm.stopPrank();
    }

    function testCannotConsultInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleTokenBalance(address(docToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchaseAmount(address(docToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchasePeriod(address(docToken), SCHEDULE_INDEX + 1);
        vm.stopPrank();
    }

    function testCannotDeleteInexistentSchedule() external {
        bytes32 scheduleId = keccak256(
            abi.encodePacked(USER, block.timestamp + 1, dcaManager.getMyDcaSchedules(address(docToken)).length)
        );
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleId.selector);
        vm.prank(USER);
        dcaManager.deleteDcaSchedule(address(docToken), scheduleId);
    }
}
