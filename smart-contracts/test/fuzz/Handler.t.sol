// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DCAContract} from "../../src/DCAContract.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
// import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract Handler is Test {
    DCAContract public dcaContract;
    MockDocToken public mockDocToken;
    // MockMocProxy public mockMocProxy;
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    address OWNER = makeAddr("owner");

    constructor(DCAContract _dcaContract, MockDocToken _mockDocToken /*, MockMocProxy _mockMocProxy*/ ) {
        dcaContract = _dcaContract;
        mockDocToken = _mockDocToken;
        // mockMocProxy = _mockMocProxy;
    }

    function despositDOC(uint256 depositAmount) public {
        vm.startPrank(msg.sender);
        mockDocToken.mint(msg.sender, USER_TOTAL_DOC);
        depositAmount = bound(depositAmount, 0, USER_TOTAL_DOC);
        if (depositAmount == 0) return;
        mockDocToken.approve(address(dcaContract), depositAmount);
        dcaContract.depositDOC(depositAmount);
        vm.stopPrank();
    }

    function withdrawDOC(uint256 withdrawalAmount) public {
        vm.startPrank(msg.sender);
        uint256 maxWithdrawalAmount = dcaContract.getDocBalance();
        withdrawalAmount = bound(withdrawalAmount, 0, maxWithdrawalAmount);
        if (withdrawalAmount == 0) return;
        dcaContract.withdrawDOC(withdrawalAmount);
        vm.stopPrank();
    }

    function setPurchaseAmount(uint256 purchaseAmount) external {
        vm.startPrank(msg.sender);
        uint256 maxPurchaseAmount = dcaContract.getDocBalance() / 2;
        purchaseAmount = bound(purchaseAmount, 0, maxPurchaseAmount);
        if (purchaseAmount == 0) return;
        dcaContract.setPurchaseAmount(purchaseAmount);
        vm.stopPrank();
    }

    function setPurchasePeriod(uint256 purchasePeriod) external {
        vm.startPrank(msg.sender);
        if (purchasePeriod == 0) return;
        dcaContract.setPurchasePeriod(purchasePeriod);
        vm.stopPrank();
    }

    function buyRbtc(uint256 buyerAddressSeed) public {
        address[] memory users = dcaContract.getUsers();
        if (users.length == 0) return;
        address sender = users[buyerAddressSeed % users.length];
        vm.prank(OWNER);
        dcaContract.buyRbtc(sender);
    }

    function withdrawAccumulatedRbtc() external {
        vm.startPrank(msg.sender);
        uint256 rbtcBalance = dcaContract.getRbtcBalance();
        if (rbtcBalance == 0) return;
        dcaContract.withdrawAccumulatedRbtc();
        vm.stopPrank();
    }
}
