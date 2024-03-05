// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RbtcDca} from "../../src/RbtcDca.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
// import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract Handler is Test {
    RbtcDca public rbtcDca;
    MockDocToken public mockDocToken;
    // MockMocProxy public mockMocProxy;
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    address OWNER = makeAddr("owner");

    constructor(RbtcDca _rbtcDca, MockDocToken _mockDocToken /*, MockMocProxy _mockMocProxy*/ ) {
        rbtcDca = _rbtcDca;
        mockDocToken = _mockDocToken;
        // mockMocProxy = _mockMocProxy;
    }

    function despositDOC(uint256 depositAmount) public {
        vm.startPrank(msg.sender);
        mockDocToken.mint(msg.sender, USER_TOTAL_DOC);
        depositAmount = bound(depositAmount, 0, USER_TOTAL_DOC);
        if (depositAmount == 0) return;
        mockDocToken.approve(address(rbtcDca), depositAmount);
        rbtcDca.depositDOC(depositAmount);
        vm.stopPrank();
    }

    function withdrawDOC(uint256 withdrawalAmount) public {
        vm.startPrank(msg.sender);
        uint256 maxWithdrawalAmount = rbtcDca.getDocBalance();
        withdrawalAmount = bound(withdrawalAmount, 0, maxWithdrawalAmount);
        if (withdrawalAmount == 0) return;
        rbtcDca.withdrawDOC(withdrawalAmount);
        vm.stopPrank();
    }

    function setPurchaseAmount(uint256 purchaseAmount) external {
        vm.startPrank(msg.sender);
        uint256 maxPurchaseAmount = rbtcDca.getDocBalance() / 2;
        purchaseAmount = bound(purchaseAmount, 0, maxPurchaseAmount);
        if (purchaseAmount == 0) return;
        rbtcDca.setPurchaseAmount(purchaseAmount);
        vm.stopPrank();
    }

    function setPurchasePeriod(uint256 purchasePeriod) external {
        vm.startPrank(msg.sender);
        if (purchasePeriod == 0) return;
        rbtcDca.setPurchasePeriod(purchasePeriod);
        vm.stopPrank();
    }

    function createDcaSchedule(uint256 depositAmount, uint256 purchaseAmount, uint256 purchasePeriod) public {
        vm.startPrank(msg.sender);
        depositAmount = bound(depositAmount, 0, USER_TOTAL_DOC);
        if (depositAmount == 0) return;
        uint256 maxPurchaseAmount = rbtcDca.getDocBalance() / 2;
        purchaseAmount = bound(purchaseAmount, 0, maxPurchaseAmount);
        if (purchaseAmount == 0) return;
        if (purchasePeriod == 0) return;
        mockDocToken.mint(msg.sender, USER_TOTAL_DOC);
        mockDocToken.approve(address(rbtcDca), depositAmount);
        rbtcDca.createDcaSchedule(depositAmount, purchaseAmount, purchasePeriod);
        vm.stopPrank();
    }

    function buyRbtc(uint256 buyerAddressSeed) public {
        vm.startPrank(OWNER);
        address[] memory users = rbtcDca.getUsers();
        if (users.length == 0) return;
        address sender = users[buyerAddressSeed % users.length];
        rbtcDca.buyRbtc(sender);
        vm.stopPrank();
    }

    function withdrawAccumulatedRbtc() external {
        vm.startPrank(msg.sender);
        uint256 rbtcBalance = rbtcDca.getRbtcBalance();
        if (rbtcBalance == 0) return;
        rbtcDca.withdrawAccumulatedRbtc();
        vm.stopPrank();
    }
}
