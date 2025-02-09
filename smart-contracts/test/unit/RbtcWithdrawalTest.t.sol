//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import "../Constants.sol";

contract RbtcWithdrawalTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /////////////////////////////
    /// rBTC Withdrawal tests ///
    /////////////////////////////

    function testWithdrawRbtcAfterOnePurchase() external {
        // TODO: test this for multiple stablecoins/schedules

        uint256 fee = feeCalculator.calculateFee(DOC_TO_SPEND, MIN_PURCHASE_PERIOD);
        uint256 netPurchaseAmount = DOC_TO_SPEND - fee;

        vm.prank(USER);
        IDcaManager.DcaDetails[] memory dcaDetails = dcaManager.getMyDcaSchedules(address(docToken));

        // vm.prank(OWNER);
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(docToken), SCHEDULE_INDEX, dcaDetails[SCHEDULE_INDEX].scheduleId);

        uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
        vm.prank(USER);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = s_lendingProtocolIndex;
        dcaManager.withdrawAllAccumulatedRbtc(lendingProtocolIndexes);
        uint256 rbtcBalanceAfterWithdrawal = USER.balance;

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            // assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, netPurchaseAmount / s_btcPrice);
            assertApproxEqRel( // MoC takes some commission so strict equality us not possible
                rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal,
                netPurchaseAmount / s_btcPrice,
                0.25e16 // Allow a maximum difference of 0.25%
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal,
                netPurchaseAmount / s_btcPrice,
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }

    function testWithdrawRbtcAfterSeveralPurchases() external {
        super.createSeveralDcaSchedules();
        uint256 totalDocSpent = super.makeSeveralPurchasesWithSeveralSchedules(); // 5 purchases
        uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
        vm.prank(USER);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = s_lendingProtocolIndex;
        dcaManager.withdrawAllAccumulatedRbtc(lendingProtocolIndexes);
        uint256 rbtcBalanceAfterWithdrawal = USER.balance;
        // assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, totalDocSpent / s_btcPrice);

        // if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
        //     assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, totalDocSpent / s_btcPrice);
        // } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
        assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
            rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal,
            totalDocSpent / s_btcPrice,
            0.5e16 // Allow a maximum difference of 0.5% (on fork tests we saw this was necessary for both MoC and Uniswap swaps)
        );
        // }
    }

    function testCannotWithdrawBeforePurchasing() external {
        uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
        vm.expectRevert(IPurchaseRbtc.PurchaseRbtc__NoAccumulatedRbtcToWithdraw.selector);
        vm.prank(USER);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = s_lendingProtocolIndex;
        dcaManager.withdrawAllAccumulatedRbtc(lendingProtocolIndexes);
        uint256 rbtcBalanceAfterWithdrawal = USER.balance;
        assertEq(rbtcBalanceAfterWithdrawal, rbtcBalanceBeforeWithdrawal);
    }
}
