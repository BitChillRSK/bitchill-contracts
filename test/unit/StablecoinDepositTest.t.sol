//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";

contract StablecoinDepositTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /////////////////////////////////
    /// Stablecoin deposit tests ///
    /////////////////////////////////
    function testStablecoinDeposit() external {
        (uint256 userBalanceAfterDeposit, uint256 userBalanceBeforeDeposit) = super.depositDoc();
        assertEq(AMOUNT_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        assertEq(dcaManager.getIsTokenDepositedByUser(USER, address(stablecoin)), true);
        assertEq(dcaManager.getUsersDepositedTokens(USER).length, 1);
    }

    function testCannotDepositZeroStablecoin() external {
        vm.startPrank(USER);
        stablecoin.approve(address(docHandler), AMOUNT_TO_DEPOSIT);
        vm.expectRevert(IDcaManager.DcaManager__DepositAmountMustBeGreaterThanZero.selector);
        dcaManager.depositToken(address(stablecoin), SCHEDULE_INDEX, 0);
        vm.stopPrank();
    }

    function testDepositRevertsIfStablecoinNotApproved() external {
        vm.startPrank(USER);
        vm.expectRevert();
        dcaManager.depositToken(address(stablecoin), SCHEDULE_INDEX, AMOUNT_TO_DEPOSIT);
        vm.stopPrank();
    }
} 