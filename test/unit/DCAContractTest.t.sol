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
    uint256 constant STARTING_USER_BALANCE = 10 ether; // 10 rBTC
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC
    uint256 constant DOC_TO_DEPOSIT = 1000 ether; // 1000 DOC
    uint256 constant DOC_TO_SPEND = 100 ether; // 100 DOC for periodical purchases

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
        vm.deal(USER, STARTING_USER_BALANCE);

        // Mint 10000 DOC for the user
        mockDockToken.mint(USER, USER_TOTAL_DOC);

        // Make the starting point of the tests is that the user has already deposited 1000 DOC
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        dcaContract.depositDOC(DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

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

    function testCannotDepositWithoutApprovingFirst() external {
        vm.startPrank(USER);
        vm.expectRevert();
        dcaContract.depositDOC(DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

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

    function testWithdrawalAmountCannotExceedBalance() external {
        vm.startPrank(USER);
        vm.expectRevert(DocWithdrawalAmountExceedsBalance.selector);
        dcaContract.withdrawDOC(USER_TOTAL_DOC);
        vm.stopPrank();
    }

    function testSetPurchaseAmount() external {
        vm.startPrank(USER);
        dcaContract.setPurchaseAmount(DOC_TO_SPEND);
        assertEq(DOC_TO_SPEND, dcaContract.getPurchaseAmount());
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

    function testPurchase() external {
        vm.startPrank(USER);
        mockDockToken.approve(address(dcaContract), DOC_TO_DEPOSIT);
        uint256 docBalanceBeforePurchase = dcaContract.getDocBalance();
        dcaContract.setPurchaseAmount(DOC_TO_SPEND);
        vm.stopPrank();
        vm.prank(OWNER);
        // console.log(dcaContract.owner());
        dcaContract.buy(USER);
        vm.prank(USER);
        uint256 docBalanceAfterPurchase = dcaContract.getDocBalance();
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);
    }
}
