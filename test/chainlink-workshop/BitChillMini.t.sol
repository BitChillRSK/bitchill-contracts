// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BitChillMini} from "src/chainlink-workshop/BitChillMini.sol";
import {MockStablecoin} from "test/mocks/MockStablecoin.sol";
import {MockKdocToken} from "test/mocks/MockKdocToken.sol";
import {MockMocProxy} from "test/mocks/MockMocProxy.sol";

contract BitChillMiniTest is Test {
    BitChillMini internal mini;
    MockStablecoin internal doc;
    MockKdocToken internal kdoc;
    MockMocProxy internal moc;

    address internal feeCollector = address(0xFEE);

    receive() external payable {}

    function setUp() public {
        // Deploy mocks
        doc = new MockStablecoin(address(this));
        kdoc = new MockKdocToken(address(doc));
        moc = new MockMocProxy(address(doc));

        // Deploy contract under test
        mini = new BitChillMini(address(doc), address(kdoc), address(moc), feeCollector);

        // Fund MoC proxy with RBTC so it can pay out on redeem
        vm.deal(address(moc), 10 ether);
    }

    function testDepositBuyWithdraw() public {
        // Arrange: mint DOC to test contract and approve BitChillMini
        uint256 depositAmount = 100 ether;
        uint256 buyAmount = 50 ether;

        doc.mint(address(this), depositAmount);
        doc.approve(address(mini), depositAmount);

        // Act: create schedule + deposit DOC -> lends to kDOC
        mini.createDcaSchedule(depositAmount, buyAmount, 30 days);

        // Assert: user has some kDOC tracked
        uint256 kdocTracked = mini.getUserKDocBalance(address(this));
        assertGt(kdocTracked, 0, "kDOC not tracked after deposit");

        // Act: buy rBTC
        uint256 rbtcBefore = address(this).balance;
        mini.buyRbtc(buyAmount);

        // Assert: accumulated rBTC increased
        uint256 accumulated = mini.getUserAccumulatedRbtc(address(this));
        assertGt(accumulated, 0, "No accumulated rBTC after buy");

        // Act: withdraw accumulated rBTC
        mini.withdrawAccumulatedRbtc();

        // Assert: rBTC (native) balance increased
        uint256 rbtcAfter = address(this).balance;
        assertGt(rbtcAfter, rbtcBefore, "rBTC was not withdrawn");
    }

    function testDcaOverMonthsAndWithdrawInterest() public {
        // Arrange
        uint256 depositAmount = 300 ether;
        uint256 purchaseAmount = 50 ether; // per month
        uint256 months = 3;

        // Fund user with DOC and approve
        doc.mint(address(this), depositAmount);
        doc.approve(address(mini), depositAmount);

        // Create simple schedule + deposit
        mini.createDcaSchedule(depositAmount, purchaseAmount, 30 days);

        // Ensure MoC has rBTC to pay out
        vm.deal(address(moc), 2 ether);

        // Simulate 3 monthly purchases
        for (uint256 i; i < months; ++i) {
            vm.warp(block.timestamp + 30 days);
            mini.buyRbtc(purchaseAmount);
        }

        // Withdraw interest only (uses schedule's tokenBalance internally)
        uint256 userDocBefore = doc.balanceOf(address(this));
        mini.withdrawInterest();
        uint256 userDocAfter = doc.balanceOf(address(this));
        assertGt(userDocAfter, userDocBefore, "No interest withdrawn");

        // Withdraw accumulated rBTC
        uint256 rbtcBefore = address(this).balance;
        uint256 accumulated = mini.getUserAccumulatedRbtc(address(this));
        assertGt(accumulated, 0, "No accumulated rBTC after periodic buys");
        mini.withdrawAccumulatedRbtc();
        uint256 rbtcAfter = address(this).balance;
        assertGt(rbtcAfter, rbtcBefore, "rBTC was not withdrawn after DCA");
    }
}


