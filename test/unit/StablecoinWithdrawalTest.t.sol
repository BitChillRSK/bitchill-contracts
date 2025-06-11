//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";

contract StablecoinWithdrawalTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////////////
    /// Stablecoin Withdrawal tests ///
    ////////////////////////////////////
    function testStablecoinWithdrawal() external {
        super.withdrawDoc();
    }

    function testCannotWithdrawZeroStablecoin() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__WithdrawalAmountMustBeGreaterThanZero.selector);
        dcaManager.withdrawToken(address(stablecoin), SCHEDULE_INDEX, 0);
        vm.stopPrank();
    }

    function testTokenWithdrawalRevertsIfAmountExceedsBalance() external {
        vm.startPrank(USER);
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__WithdrawalAmountExceedsBalance.selector,
            address(stablecoin),
            USER_TOTAL_AMOUNT,
            AMOUNT_TO_DEPOSIT
        );
        vm.expectRevert(encodedRevert);
        dcaManager.withdrawToken(address(stablecoin), SCHEDULE_INDEX, USER_TOTAL_AMOUNT);
        vm.stopPrank();
    }
} 