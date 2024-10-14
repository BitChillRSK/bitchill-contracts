//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";

contract DcaScheduleTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /////////////////////////////////
    /// DcaSchedule tests  //////////
    /////////////////////////////////

    function testCreateDcaSchedule() external {
        vm.startPrank(USER);
        uint256 scheduleIndex = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        bytes32 scheduleId = keccak256(abi.encodePacked(USER, block.timestamp));
        vm.expectEmit(true, true, true, true);
        emit DcaManager__DcaScheduleCreated(
            USER, address(mockDocToken), scheduleId, DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD
        );
        dcaManager.createDcaSchedule(address(mockDocToken), DOC_TO_DEPOSIT, DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        uint256 scheduleBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
        assertEq(DOC_TO_DEPOSIT, scheduleBalanceAfterDeposit);
        assertEq(DOC_TO_SPEND, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex));
        assertEq(MIN_PURCHASE_PERIOD, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex));
        vm.stopPrank();
    }

    function testUpdateDcaSchedule() external {
        uint256 newPurchaseAmount = DOC_TO_SPEND / 2;
        uint256 newPurchasePeriod = MIN_PURCHASE_PERIOD * 10;
        uint256 extraDocToDeposit = DOC_TO_DEPOSIT / 3;
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        mockDocToken.approve(address(docTokenHandler), extraDocToDeposit);
        vm.expectEmit(true, true, true, true);
        bytes32 scheduleId = keccak256(abi.encodePacked(USER, block.timestamp));
        emit DcaManager__DcaScheduleUpdated(
            USER, address(mockDocToken), scheduleId, extraDocToDeposit, newPurchaseAmount, newPurchasePeriod
        );
        dcaManager.updateDcaSchedule(
            address(mockDocToken), SCHEDULE_INDEX, extraDocToDeposit, newPurchaseAmount, newPurchasePeriod
        );
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(extraDocToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        assertEq(newPurchaseAmount, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), SCHEDULE_INDEX));
        assertEq(newPurchasePeriod, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testDeleteDcaSchedule() external {
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT * 5);
        // Create two schedules
        dcaManager.createDcaSchedule(address(mockDocToken), DOC_TO_DEPOSIT * 2, DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        dcaManager.createDcaSchedule(address(mockDocToken), DOC_TO_DEPOSIT * 3, DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        bytes32 scheduleId = keccak256(abi.encodePacked(USER, block.timestamp));
        console.log("scheduleId is", vm.toString(scheduleId));
        // Delete one
        dcaManager.deleteDcaSchedule(address(mockDocToken), 1, scheduleId);
        // Check that there are two (the one created in setUp() and one of the two created in this test)
        assertEq(dcaManager.getMyDcaSchedules(address(mockDocToken)).length, 2);
        // Check that the deleted one was the first one created in this test
        assertEq(dcaManager.getMyDcaSchedules(address(mockDocToken))[1].tokenBalance, DOC_TO_DEPOSIT * 3);
        vm.stopPrank();
    }

    function testDeleteTwoDcaSchedules() external {
        this.testDeleteDcaSchedule();
        this.testDeleteDcaSchedule();
    }

    function testCreateSeveralDcaSchedules() external {
        // vm.startPrank(USER);
        // mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        // uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
        // uint256 purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES;
        // for (uint256 i = 1; i < NUM_OF_SCHEDULES; ++i) { // Start from 1 since schedule 0 is created in setUp
        //     uint256 scheduleIndex = SCHEDULE_INDEX + i;
        //     uint256 purchasePeriod = MIN_PURCHASE_PERIOD + i * 5 days;
        //     uint256 userBalanceBeforeDeposit;
        //     if (dcaManager.getMyDcaSchedules(address(mockDocToken)).length > scheduleIndex) {
        //         userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
        //     } else {
        //         userBalanceBeforeDeposit = 0;
        //     }
        //     vm.expectEmit(true, true, true, true);
        //     emit DcaManager__DcaScheduleCreated(
        //         USER, address(mockDocToken), scheduleIndex, docToDeposit, purchaseAmount, purchasePeriod
        //     );
        //     dcaManager.createDcaSchedule(
        //         address(mockDocToken), docToDeposit, purchaseAmount, purchasePeriod
        //     );
        //     uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
        //     assertEq(docToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        //     assertEq(purchaseAmount, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex));
        //     assertEq(purchasePeriod, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex));
        // }
        // vm.stopPrank();

        super.createSeveralDcaSchedules();
    }

    function testCannotUpdateInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX + 1, DOC_TO_DEPOSIT);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1, DOC_TO_SPEND);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1, MIN_PURCHASE_PERIOD);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.updateDcaSchedule(address(mockDocToken), 1, 1, 1, 1);
        vm.stopPrank();
    }

    function testCannotConsultInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchasePeriod(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.stopPrank();
    }

    function testCannotDeleteInexistentSchedule() external {
        bytes32 scheduleId = keccak256(abi.encodePacked(USER, block.timestamp));
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        vm.prank(USER);
        dcaManager.deleteDcaSchedule(address(mockDocToken), 1, scheduleId);
    }

    function testScheduleIndexAndIdMismatchReverts() external {
        bytes32 scheduleId = keccak256(abi.encodePacked("dummyStuff", block.timestamp));
        vm.expectRevert(IDcaManager.DcaManager__ScheduleIdAndIndexMismatch.selector);
        vm.prank(USER);
        dcaManager.deleteDcaSchedule(address(mockDocToken), 0, scheduleId);
    }
}
