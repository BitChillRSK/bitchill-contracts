//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import "../../script/Constants.sol";

contract DcaConfigurationTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    ///////////////////////////////
    /// DCA configuration tests ///
    ///////////////////////////////
    function testSetPurchaseAmount() external {
        vm.startPrank(USER);
        dcaManager.setPurchaseAmount(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_SPEND);
        assertEq(AMOUNT_TO_SPEND, dcaManager.getSchedulePurchaseAmount(address(stablecoin), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testSetPurchasePeriod() external {
        vm.startPrank(USER);
        dcaManager.setPurchasePeriod(address(stablecoin), SCHEDULE_INDEX, MIN_PURCHASE_PERIOD);
        assertEq(MIN_PURCHASE_PERIOD, dcaManager.getSchedulePurchasePeriod(address(stablecoin), SCHEDULE_INDEX));
        vm.stopPrank();
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
        vm.expectRevert(IDcaManager.DcaManager__PurchasePeriodMustBeGreaterThanMin.selector);
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
