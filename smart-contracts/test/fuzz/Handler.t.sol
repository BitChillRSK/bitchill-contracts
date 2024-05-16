// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
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
    uint256 constant MIN_PURCHASE_AMOUNT = 10 ether; // at least 10 DOC in each periodic purchase
    uint256 constant MAX_PURCHASE_PERIOD = 520 weeks; // at least one purchase every 10 years
    uint256 constant MIN_PURCHASE_PERIOD = 1 days; // at most one purchase every day
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
        if (depositAmount < 2 * MIN_PURCHASE_AMOUNT) {
            vm.stopPrank();
            return;
        }
        depositAmount = bound(depositAmount, 2 * MIN_PURCHASE_AMOUNT, USER_TOTAL_DOC);
        // if (depositAmount == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before depositing more DOC 
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, depositAmount, depositAmount / 10, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
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
        uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before withdrawing DOC 
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, withdrawalAmount, withdrawalAmount / 10, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
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
        uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before modifying the purchase amount
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, purchaseAmount * 10, purchaseAmount, 5);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        // if (usersNumOfSchedules == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);
        uint256 maxPurchaseAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex) / 2;
        if(maxPurchaseAmount < MIN_PURCHASE_AMOUNT) { // This can happen if the DOC balance left is less than 2 DOC
            vm.stopPrank();
            return;
        }
        purchaseAmount = bound(purchaseAmount, MIN_PURCHASE_AMOUNT, maxPurchaseAmount);
        if (purchaseAmount == 0) {
            vm.stopPrank();
            return;
        }
        dcaManager.setPurchaseAmount(address(mockDocToken), scheduleIndex, purchaseAmount);
        vm.stopPrank();
    }

    function setPurchasePeriod(uint256 scheduleIndex, uint256 purchasePeriod) external {
        vm.startPrank(USER);
        purchasePeriod = bound(purchasePeriod, MIN_PURCHASE_PERIOD, MAX_PURCHASE_PERIOD);
        // if (purchasePeriod == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
        if (usersNumOfSchedules == 0) {
            scheduleIndex = 0;
            // We need to create a DCA schedule before modifying the purchase period
            dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, 1000, 100, purchasePeriod);
        }
        // uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
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
        if (depositAmount < 2 * MIN_PURCHASE_AMOUNT) {
            vm.stopPrank();
            return;
        }
        depositAmount = bound(depositAmount, 2 * MIN_PURCHASE_AMOUNT, USER_TOTAL_DOC);
        // if (depositAmount == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        uint256 usersNumOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
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
        if(maxPurchaseAmount < MIN_PURCHASE_AMOUNT) { // This can happen if the DOC balance left is less than 2 DOC
            vm.stopPrank();
            return;
        }
        purchaseAmount = bound(purchaseAmount, MIN_PURCHASE_AMOUNT, maxPurchaseAmount);
        if (purchaseAmount == 0) {
            vm.stopPrank();
            return;
        }
        purchasePeriod = bound(purchasePeriod, MIN_PURCHASE_PERIOD, MAX_PURCHASE_PERIOD);
        // if (purchasePeriod == 0) {
        //     vm.stopPrank();
        //     return;
        // }
        mockDocToken.mint(USER, USER_TOTAL_DOC);
        mockDocToken.approve(address(docTokenHandler), depositAmount);
        dcaManager.createOrUpdateDcaSchedule(address(mockDocToken), scheduleIndex, depositAmount, purchaseAmount, purchasePeriod);
        vm.stopPrank();
    }

    function buyRbtc(uint256 buyerAddressSeed, uint256 scheduleIndex) public {
        vm.prank(OWNER);
        address[] memory users = dcaManager.getUsers();
        if (users.length == 0) return;
        address buyer = users[buyerAddressSeed % users.length];

        vm.prank(buyer);
        IDcaManager.DcaDetails[] memory dcaDetails = dcaManager.getMyDcaSchedules(address(mockDocToken));
        uint256 usersNumOfSchedules = dcaDetails.length;
        scheduleIndex = bound(scheduleIndex, 0, usersNumOfSchedules - 1);

        if(dcaDetails[scheduleIndex].tokenBalance < dcaDetails[scheduleIndex].purchaseAmount) return;
        if(block.timestamp < dcaDetails[scheduleIndex].lastPurchaseTimestamp + dcaDetails[scheduleIndex].purchasePeriod) return;  

        vm.prank(OWNER);
        dcaManager.buyRbtc(buyer, address(mockDocToken), scheduleIndex);
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
