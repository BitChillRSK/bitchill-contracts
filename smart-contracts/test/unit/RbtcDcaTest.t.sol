//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {DocTokenHandler} from "../../src/DocTokenHandler.sol";
import {AdminOperations} from "../../src/AdminOperations.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract RbtcDcaTest is Test {
    DcaManager dcaManager;
    DocTokenHandler docTokenHandler;
    AdminOperations adminOperations;
    HelperConfig helperConfig;
    MockDocToken mockDocToken;
    MockMocProxy mockMocProxy;

    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");
    uint256 constant STARTING_RBTC_USER_BALANCE = 10 ether; // 10 rBTC
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    uint256 constant DOC_TO_DEPOSIT = 1000 ether; // 1000 DOC
    uint256 constant DOC_TO_SPEND = 100 ether; // 100 DOC for periodical purchases
    uint256 constant PURCHASE_PERIOD = 5 seconds;
    uint256 constant BTC_PRICE = 50_000;
    uint256 SCHEDULE_INDEX = 0;

    //////////////////////
    // Events ////////////
    //////////////////////
    event DcaManager__TokenDeposited(address indexed user, address indexed token, uint256 amount);

    //////////////////////
    // Errors ////////////
    //////////////////////

    function setUp() external {
        DeployContracts deployContracts = new DeployContracts();
        (adminOperations, docTokenHandler, dcaManager, helperConfig) = deployContracts.run();
        // console.log("Test contract", address(this));

        (address docTokenAddress, address mocProxyAddress, address kdocToken) = helperConfig.activeNetworkConfig();

        mockDocToken = MockDocToken(docTokenAddress);
        mockMocProxy = MockMocProxy(docTokenAddress);

        // Add tokenHandler
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(docTokenAddress, address(docTokenHandler));

        // Send rBTC funds to mock contract and user
        vm.deal(mocProxyAddress, 1000 ether);
        vm.deal(USER, STARTING_RBTC_USER_BALANCE);

        // Mint 10000 DOC for the user
        mockDocToken.mint(USER, USER_TOTAL_DOC);

        // Make the starting point of the tests is that the user has already deposited 1000 DOC
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

    // /////////////////////////
    // /// DOC deposit tests ///
    // /////////////////////////
    function testDocDeposit() external {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit DcaManager__TokenDeposited(USER, address(mockDocToken), DOC_TO_DEPOSIT);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        vm.stopPrank();
    }

    // function testCannotDepositZeroDoc() external {
    //     vm.startPrank(USER);
    //     mockDocToken.approve(address(rbtcDca), DOC_TO_DEPOSIT);
    //     vm.expectRevert(RbtcDca__DepositAmountMustBeGreaterThanZero.selector);
    //     rbtcDca.depositDOC(0);
    //     vm.stopPrank();
    // }

    // function testDepositRevertsIfDocNotApproved() external {
    //     vm.startPrank(USER);
    //     vm.expectRevert(RbtcDca__NotEnoughDocAllowanceForDcaContract.selector);
    //     rbtcDca.depositDOC(DOC_TO_DEPOSIT);
    //     vm.stopPrank();
    // }

    // ////////////////////////////
    // /// DOC Withdrawal tests ///
    // ////////////////////////////
    // function testDocWithdrawal() external {
    //     vm.startPrank(USER);
    //     vm.expectEmit(true, true, false, false);
    //     emit DocWithdrawn(USER, DOC_TO_DEPOSIT);
    //     rbtcDca.withdrawDOC(DOC_TO_DEPOSIT);
    //     uint256 remainingAmount = rbtcDca.getDocBalance();
    //     assertEq(remainingAmount, 0);
    //     vm.stopPrank();
    // }

    // function testCannotWithdrawZeroDoc() external {
    //     vm.startPrank(USER);
    //     vm.expectRevert(RbtcDca__DocWithdrawalAmountMustBeGreaterThanZero.selector);
    //     rbtcDca.withdrawDOC(0);
    //     vm.stopPrank();
    // }

    // function testWithdrawalRevertsIfAmountExceedsBalance() external {
    //     vm.startPrank(USER);
    //     vm.expectRevert(RbtcDca__DocWithdrawalAmountExceedsBalance.selector);
    //     rbtcDca.withdrawDOC(USER_TOTAL_DOC);
    //     vm.stopPrank();
    // }

    // ///////////////////////////////
    // /// DCA configuration tests ///
    // ///////////////////////////////
    // function testSetPurchaseAmount() external {
    //     vm.startPrank(USER);
    //     rbtcDca.setPurchaseAmount(DOC_TO_SPEND);
    //     assertEq(DOC_TO_SPEND, rbtcDca.getPurchaseAmount());
    //     vm.stopPrank();
    // }

    // function testSetPurchasePeriod() external {
    //     vm.startPrank(USER);
    //     rbtcDca.setPurchasePeriod(PURCHASE_PERIOD);
    //     assertEq(PURCHASE_PERIOD, rbtcDca.getPurchasePeriod());
    //     vm.stopPrank();
    // }

    // function testPurchaseAmountCannotBeZero() external {
    //     vm.startPrank(USER);
    //     vm.expectRevert(RbtcDca__PurchaseAmountMustBeGreaterThanZero.selector);
    //     rbtcDca.setPurchaseAmount(0);
    //     vm.stopPrank();
    // }

    // function testPurchaseAmountCannotBeMoreThanHalfBalance() external {
    //     vm.startPrank(USER);
    //     vm.expectRevert(RbtcDca__PurchaseAmountMustBeLowerThanHalfOfBalance.selector);
    //     rbtcDca.setPurchaseAmount(DOC_TO_DEPOSIT / 2 + 1);
    //     vm.stopPrank();
    // }

    // //////////////////////
    // /// Purchase tests ///
    // //////////////////////
    // function testSinglePurchase() external {
    //     vm.startPrank(USER);
    //     mockDocToken.approve(address(rbtcDca), DOC_TO_DEPOSIT);
    //     uint256 docBalanceBeforePurchase = rbtcDca.getDocBalance();
    //     uint256 RbtcBalanceBeforePurchase = rbtcDca.getRbtcBalance();
    //     rbtcDca.setPurchaseAmount(DOC_TO_SPEND);
    //     vm.stopPrank();
    //     vm.prank(OWNER);
    //     rbtcDca.buyRbtc(USER);
    //     vm.startPrank(USER);
    //     uint256 docBalanceAfterPurchase = rbtcDca.getDocBalance();
    //     uint256 RbtcBalanceAfterPurchase = rbtcDca.getRbtcBalance();
    //     vm.stopPrank();
    //     // Check that DOC was substracted and rBTC was added to user's balances
    //     assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);
    //     assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, DOC_TO_SPEND / BTC_PRICE);
    // }

    // function testCannotBuyIfPeriodNotElapsed() external {
    //     vm.startPrank(USER);
    //     mockDocToken.approve(address(rbtcDca), DOC_TO_DEPOSIT);
    //     rbtcDca.setPurchaseAmount(DOC_TO_SPEND);
    //     rbtcDca.setPurchasePeriod(PURCHASE_PERIOD);
    //     vm.stopPrank();
    //     vm.prank(OWNER);
    //     rbtcDca.buyRbtc(USER); // first purchase
    //     vm.expectRevert(RbtcDca__CannotBuyIfPurchasePeriodHasNotElapsed.selector);
    //     vm.prank(OWNER);
    //     rbtcDca.buyRbtc(USER); // second purchase
    // }

    // function testSeveralPurchases() external {
    //     uint8 numOfPurchases = 5;
    //     vm.prank(USER);
    //     rbtcDca.setPurchasePeriod(PURCHASE_PERIOD);
    //     for (uint8 i; i < numOfPurchases; i++) {
    //         this.testSinglePurchase();
    //         vm.warp(block.timestamp + PURCHASE_PERIOD);
    //     }
    //     vm.prank(USER);
    //     assertEq(rbtcDca.getRbtcBalance(), (DOC_TO_SPEND / BTC_PRICE) * numOfPurchases);
    // }

    // /////////////////////////////
    // /// rBTC Withdrawal tests ///
    // /////////////////////////////

    // function testWithdrawRbtc() external {
    //     this.testSinglePurchase();
    //     vm.startPrank(USER);
    //     uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
    //     rbtcDca.withdrawAccumulatedRbtc();
    //     uint256 rbtcBalanceAfterWithdrawal = USER.balance;
    //     vm.stopPrank();
    //     assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, DOC_TO_SPEND / BTC_PRICE);
    // }

    // /////////////////////////////////
    // /// createDcaSchedule tests  ////
    // /////////////////////////////////

    // function testCreateDcaSchedule() external {
    //     vm.startPrank(USER);
    //     uint256 userBalanceBeforeDeposit = rbtcDca.getDocBalance();
    //     mockDocToken.approve(address(rbtcDca), DOC_TO_DEPOSIT);
    //     vm.expectEmit(true, true, true, true);
    //     emit newDcaScheduleCreated(USER, DOC_TO_DEPOSIT, DOC_TO_SPEND, PURCHASE_PERIOD);
    //     rbtcDca.createDcaSchedule(DOC_TO_DEPOSIT, DOC_TO_SPEND, PURCHASE_PERIOD);
    //     uint256 userBalanceAfterDeposit = rbtcDca.getDocBalance();
    //     assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
    //     assertEq(DOC_TO_SPEND, rbtcDca.getPurchaseAmount());
    //     assertEq(PURCHASE_PERIOD, rbtcDca.getPurchasePeriod());
    //     vm.stopPrank();
    // }
}
