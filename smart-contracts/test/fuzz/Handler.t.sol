// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {AdminOperations} from "src/AdminOperations.sol";
import {DocTokenHandler} from "src/DocTokenHandler.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
// import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract Handler is Test {
    AdminOperations public adminOperations;
    DocTokenHandler public docTokenHandler;
    DcaManager public dcaManager;
    MockDocToken public mockDocToken;
    // MockMocProxy public mockMocProxy;
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    address OWNER = makeAddr("owner");
    address USER = makeAddr("user");

    constructor(AdminOperations _adminOperations, DocTokenHandler _docTokenHandler, DcaManager _dcaManager, MockDocToken _mockDocToken /*, MockMocProxy _mockMocProxy*/ ) {
        adminOperations = _adminOperations;
        docTokenHandler = _docTokenHandler;
        dcaManager = _dcaManager;
        mockDocToken = _mockDocToken;
        // mockMocProxy = _mockMocProxy;
    }

    function depositDoc(uint256 scheduleIndex, uint256 depositAmount) public {
        vm.startPrank(USER);
        mockDocToken.mint(USER, USER_TOTAL_DOC);
        depositAmount = bound(depositAmount, 0, USER_TOTAL_DOC);
        if (depositAmount == 0) {
            vm.stopPrank();
            return;
        }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before depositing more DOC 
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, depositAmount, depositAmount / 10, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        // if (usersNumOfSchedules == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        mockDocToken.approve(address(docTokenHandler), depositAmount);
        dcaManager.depositToken(address(mockDocToken), scheduleIndex, depositAmount);
        vm.stopPrank();
    }

    function withdrawDoc(uint256 scheduleIndex, uint256 withdrawalAmount) public {
        vm.startPrank(USER);
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before withdrawing DOC 
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, withdrawalAmount, withdrawalAmount / 10, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        // if (usersNumOfSchedules == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        uint256 maxWithdrawalAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
        withdrawalAmount = bound(withdrawalAmount, 0, maxWithdrawalAmount);
        if (withdrawalAmount == 0) {
            vm.stopPrank();
            return;
        }
        dcaManager.withdrawToken(address(mockDocToken), scheduleIndex, withdrawalAmount);
        vm.stopPrank();
    }

    function setPurchaseAmount(uint256 scheduleIndex, uint256 purchaseAmount) external {
        vm.startPrank(USER);
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before modifying the purchase amount
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, purchaseAmount * 10, purchaseAmount, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        // if (usersNumOfSchedules == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        uint256 maxPurchaseAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex) / 2;
        purchaseAmount = bound(purchaseAmount, 0, maxPurchaseAmount);
        if (purchaseAmount == 0) {
            vm.stopPrank();
            return;
        }
        dcaManager.setPurchaseAmount(address(mockDocToken), scheduleIndex, purchaseAmount);
        vm.stopPrank();
    }

    function setPurchasePeriod(uint256 scheduleIndex, uint256 purchasePeriod) external {
        vm.startPrank(USER);
        if (purchasePeriod == 0) {
            vm.stopPrank();
            return;
        }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before modifying the purchase period
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, 1000, 100, purchasePeriod);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        // if (usersNumOfSchedules == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        dcaManager.setPurchasePeriod(address(mockDocToken), scheduleIndex, purchasePeriod);
        vm.stopPrank();
    }

    function createOrUpdateDcaSchedule(uint256 scheduleIndex, uint256 depositAmount, uint256 purchaseAmount, uint256 purchasePeriod) public {
        vm.startPrank(USER);
        depositAmount = bound(depositAmount, 0, USER_TOTAL_DOC);
        if (depositAmount == 0) {
            vm.stopPrank();
            return;
        }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            vm.stopPrank();
            return;
        }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        if (scheduleIndex > usersNumOfSchedules) {
            vm.stopPrank();
            return;
        }
        uint256 maxPurchaseAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex) / 2;
        purchaseAmount = bound(purchaseAmount, 0, maxPurchaseAmount);
        if (purchaseAmount == 0) {
            vm.stopPrank();
            return;
        }
        if (purchasePeriod == 0) {
            vm.stopPrank();
            return;
        }
        mockDocToken.mint(USER, USER_TOTAL_DOC);
        mockDocToken.approve(address(docTokenHandler), depositAmount);
        dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, depositAmount, purchaseAmount, purchasePeriod);
        vm.stopPrank();
    }

    function buyRbtc(uint256 buyerAddressSeed, uint256 scheduleIndex) public {
        vm.startPrank(USER);
        uint256 usersNumOfSchedules = dcaManager.getMyDcaPositions(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            // We need to create a DCA schedule before purchasing rBTC
            scheduleIndex = 0;
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, 1000, 100, 5);
        }
        vm.stopPrank();
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        vm.startPrank(OWNER);
        address[] memory users = dcaManager.getUsers();
        if (users.length == 0) return;
        address buyer = users[buyerAddressSeed % users.length];
        dcaManager.buyRbtc(buyer, address(mockDocToken), scheduleIndex);
        vm.stopPrank();
    }

    function withdrawRbtc() external {
        vm.startPrank(USER);
        uint256 rbtcBalance = docTokenHandler.getAccumulatedRbtcBalance();
        if (rbtcBalance == 0) {
            vm.stopPrank();
            return;
        }
        dcaManager.withdrawAllAccmulatedRbtc();
        vm.stopPrank();
    }
}
