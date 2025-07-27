//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import "../../script/Constants.sol";

contract DcaConfigurationTest is DcaDappTest {
    // Events
    event DcaManager__PurchaseAmountSet(address indexed user, bytes32 indexed scheduleId, uint256 indexed purchaseAmount);
    event DcaManager__PurchasePeriodSet(address indexed user, bytes32 indexed scheduleId, uint256 indexed purchasePeriod);
    event DcaManager__MaxSchedulesPerTokenModified(uint256 indexed maxSchedulesPerToken);

    function setUp() public override {
        super.setUp();
    }

    ///////////////////////////////
    /// DCA configuration tests ///
    ///////////////////////////////
    function testSetPurchaseAmount() external {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true);
        emit DcaManager__PurchaseAmountSet(USER, dcaManager.getMyScheduleId(address(stablecoin), SCHEDULE_INDEX), AMOUNT_TO_SPEND);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_SPEND);
        assertEq(AMOUNT_TO_SPEND, dcaManager.getMySchedulePurchaseAmount(address(stablecoin), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testSetPurchasePeriod() external {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true);
        emit DcaManager__PurchasePeriodSet(USER, dcaManager.getMyScheduleId(address(stablecoin), SCHEDULE_INDEX), MIN_PURCHASE_PERIOD);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_PERIOD);
        assertEq(MIN_PURCHASE_PERIOD, dcaManager.getMySchedulePurchasePeriod(address(stablecoin), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testModifyMaxSchedulesPerToken() external {
        vm.expectEmit(true, true, true, true);
        emit DcaManager__MaxSchedulesPerTokenModified(MAX_SCHEDULES_PER_TOKEN);
        vm.startPrank(OWNER);
        dcaManager.modifyMaxSchedulesPerToken(MAX_SCHEDULES_PER_TOKEN);
        assertEq(MAX_SCHEDULES_PER_TOKEN, dcaManager.getMaxSchedulesPerToken());
    }

    function testPurchaseAmountCannotBeMoreThanHalfBalance() external {
        vm.expectRevert(IDcaManager.DcaManager__PurchaseAmountMustBeLowerThanHalfOfBalance.selector);
        vm.prank(USER);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_DEPOSIT / 2 + 1);
    }

    function testPurchaseAmountMustBeGreaterThanMin() external {
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__PurchaseAmountMustBeGreaterThanMinimum.selector, address(stablecoin)
        );
        vm.expectRevert(encodedRevert);
        vm.prank(USER);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_AMOUNT - 1);
    }

    function testPurchasePeriodMustBeGreaterThanMin() external {
        vm.expectRevert(IDcaManager.DcaManager__PurchasePeriodMustBeGreaterThanMinimum.selector);
        vm.prank(USER);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_PERIOD - 1);
    }

    function testMaxSchedulesPerTokenCannotBeExceeded() external {
        uint256 maxSchedulesPerToken = dcaManager.getMaxSchedulesPerToken();
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__MaxSchedulesPerTokenReached.selector, address(stablecoin)
        );
        for (uint256 i; i < maxSchedulesPerToken; ++i) {
            vm.startPrank(USER);
            stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
            if (i == maxSchedulesPerToken - 1) {
                vm.expectRevert(encodedRevert);
            }
            dcaManager.createDcaSchedule(
                address(stablecoin), AMOUNT_TO_DEPOSIT / 2, AMOUNT_TO_SPEND, MIN_PURCHASE_PERIOD, s_lendingProtocolIndex
            );
            vm.stopPrank();
        }
    }
}
