//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DCAContract} from "../../src/DCAContract.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDca} from "../../script/DeployDca.s.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract DCAContractTest is Test {
    DCAContract dcaContract;
    HelperConfig helperConfig;
    MockDocToken mockDockToken;
    MockMocProxy mockMocProxy;

    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");
    uint256 constant STARTING_RBTC_USER_BALANCE = 10 ether; // 10 rBTC
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    uint256 constant DOC_TO_DEPOSIT = 1000 ether; // 1000 DOC
    uint256 constant DOC_TO_SPEND = 100 ether; // 100 DOC for periodical purchases
    uint256 constant PURCHASE_PERIOD = 5 seconds;
    uint256 constant BTC_PRICE = 40_000;

    //////////////////////
    // Events ////////////
    //////////////////////
    event DocDeposited(address indexed user, uint256 amount);
    event DocWithdrawn(address indexed user, uint256 amount);
    event RbtcBought(address indexed user, uint256 docAmount, uint256 rbtcAmount);
    event rBtcWithdrawn(address indexed user, uint256 rbtcAmount);
    event PurchaseAmountSet(address indexed user, uint256 purchaseAmount);
    event PurchasePeriodSet(address indexed user, uint256 purchasePeriod);

    //////////////////////
    // Errors ////////////
    //////////////////////
    error DepositAmountMustBeGreaterThanZero();
    error DocWithdrawalAmountMustBeGreaterThanZero();
    error DocWithdrawalAmountExceedsBalance();
    error DocDepositFailed();
    error DocWithdrawalFailed();
    error PurchaseAmountMustBeGreaterThanZero();
    error PurchasePeriodMustBeGreaterThanZero();
    error PurchaseAmountMustBeLowerThanHalfOfBalance();
    error RedeemDocRequestFailed();
    error RedeemFreeDocFailed();
    error rBtcWithdrawalFailed();
    error OnlyMocProxyContractCanSendRbtcToDcaContract();
    error CannotBuyIfPurchasePeriodHasNotElapsed();

    function setUp() external {
        DeployDca deployDca = new DeployDca();
        (dcaContract, helperConfig) = deployDca.run();
        // console.log("Test contract", address(this));

        (address docTokenAddress, address mocProxyAddress) = helperConfig.activeNetworkConfig();

        mockDockToken = MockDocToken(docTokenAddress);
        mockMocProxy = MockMocProxy(docTokenAddress);

        // Send rBTC funds to mock contract and user
        vm.deal(mocProxyAddress, 1000 ether);
        vm.deal(USER, STARTING_RBTC_USER_BALANCE);

        // Mint 10000 DOC for the user
        mockDockToken.mint(USER, USER_TOTAL_DOC);

        // Make the starting point of the tests is that the user has already deposited 1000 DOC
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        dcaContract.depositDOC(DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

    /////////////////////////
    /// DOC deposit tests ///
    /////////////////////////
    function testDocDeposit() external {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaContract.getDocBalance();
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, false, false);
        emit DocDeposited(USER, DOC_TO_DEPOSIT);
        dcaContract.depositDOC(DOC_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaContract.getDocBalance();
        assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        vm.stopPrank();
    }

    function testCannotDepositZeroDoc() external {
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        vm.expectRevert(DepositAmountMustBeGreaterThanZero.selector);
        dcaContract.depositDOC(0);
        vm.stopPrank();
    }

    function testDepositRevertsIfDocNotApproved() external {
        vm.startPrank(USER);
        vm.expectRevert();
        dcaContract.depositDOC(DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

    ////////////////////////////
    /// DOC Withdrawal tests ///
    ////////////////////////////
    function testDocWithdrawal() external {
        vm.startPrank(USER);
        vm.expectEmit(true, true, false, false);
        emit DocWithdrawn(USER, DOC_TO_DEPOSIT);
        dcaContract.withdrawDOC(DOC_TO_DEPOSIT);
        uint256 remainingAmount = dcaContract.getDocBalance();
        assertEq(remainingAmount, 0);
        vm.stopPrank();
    }

    function testCannotWithdrawZeroDoc() external {
        vm.startPrank(USER);
        vm.expectRevert(DocWithdrawalAmountMustBeGreaterThanZero.selector);
        dcaContract.withdrawDOC(0);
        vm.stopPrank();
    }

    function testWithdrawalRevertsIfAmountExceedsBalance() external {
        vm.startPrank(USER);
        vm.expectRevert(DocWithdrawalAmountExceedsBalance.selector);
        dcaContract.withdrawDOC(USER_TOTAL_DOC);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// DCA configuration tests ///
    ///////////////////////////////
    function testSetPurchaseAmount() external {
        vm.startPrank(USER);
        dcaContract.setPurchaseAmount(DOC_TO_SPEND);
        assertEq(DOC_TO_SPEND, dcaContract.getPurchaseAmount());
        vm.stopPrank();
    }

    function testSetPurchasePeriod() external {
        vm.startPrank(USER);
        dcaContract.setPurchasePeriod(PURCHASE_PERIOD);
        assertEq(PURCHASE_PERIOD, dcaContract.getPurchasePeriod());
        vm.stopPrank();
    }

    function testPurchaseAmountCannotBeZero() external {
        vm.startPrank(USER);
        vm.expectRevert(PurchaseAmountMustBeGreaterThanZero.selector);
        dcaContract.setPurchaseAmount(0);
        vm.stopPrank();
    }

    function testPurchaseAmountCannotBeMoreThanHalfBalance() external {
        vm.startPrank(USER);
        vm.expectRevert(PurchaseAmountMustBeLowerThanHalfOfBalance.selector);
        dcaContract.setPurchaseAmount(DOC_TO_DEPOSIT / 2 + 1);
        vm.stopPrank();
    }

    //////////////////////
    /// Purchase tests ///
    //////////////////////
    function testSinglePurchase() external {
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        uint256 docBalanceBeforePurchase = dcaContract.getDocBalance();
        uint256 RbtcBalanceBeforePurchase = dcaContract.getRbtcBalance();
        dcaContract.setPurchaseAmount(DOC_TO_SPEND);
        vm.stopPrank();
        vm.prank(OWNER);
        dcaContract.buy(USER);
        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaContract.getDocBalance();
        uint256 RbtcBalanceAfterPurchase = dcaContract.getRbtcBalance();
        vm.stopPrank();
        // Check that DOC was substracted and rBTC was added to user's balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);
        assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, DOC_TO_SPEND / BTC_PRICE);
    }

    function testCannotBuyIfPeriodNotElapsed() external {
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        dcaContract.setPurchaseAmount(DOC_TO_SPEND);
        dcaContract.setPurchasePeriod(PURCHASE_PERIOD);
        vm.stopPrank();
        vm.prank(OWNER);
        dcaContract.buy(USER); // first purchase
        vm.expectRevert(CannotBuyIfPurchasePeriodHasNotElapsed.selector);
        vm.prank(OWNER);
        dcaContract.buy(USER); // second purchase
    }

    function testSeveralPurchases() external {
        uint8 numOfPurchases = 5;
        vm.prank(USER);
        dcaContract.setPurchasePeriod(PURCHASE_PERIOD);
        for (uint8 i; i < numOfPurchases; i++) {
            this.testSinglePurchase();
            vm.warp(block.timestamp + PURCHASE_PERIOD);
        }
        vm.prank(USER);
        assertEq(dcaContract.getRbtcBalance(), (DOC_TO_SPEND / BTC_PRICE) * numOfPurchases);
    }

    /////////////////////////////
    /// rBTC Withdrawal tests ///
    /////////////////////////////

    function testWithdrawRbtc() external {
        this.testSinglePurchase();
        vm.startPrank(USER);
        uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
        dcaContract.withdrawAccumulatedRbtc();
        uint256 rbtcBalanceAfterWithdrawal = USER.balance;
        vm.stopPrank();
        assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, DOC_TO_SPEND / BTC_PRICE);
    }
}
