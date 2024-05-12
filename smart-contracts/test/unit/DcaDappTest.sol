//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {DocTokenHandler} from "../../src/DocTokenHandler.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {AdminOperations} from "../../src/AdminOperations.sol";
import {IAdminOperations} from "../../src/interfaces/IAdminOperations.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";

contract DcaDappTest is Test {
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
    uint256 NUM_OF_SCHEDULES = 5;

    //////////////////////
    // Events ////////////
    //////////////////////

    // DcaManager
    // event DcaManager__TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event DcaManager__TokenBalanceUpdated(address indexed token, uint256 indexed scheduleIndex, uint256 indexed amount);
    event DcaManager__newDcaScheduleCreated(
        address indexed user,
        address indexed token,
        uint256 indexed scheduleIndex,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );

    // TokenHandler
    event TokenHandler__TokenDeposited(address indexed token, address indexed user, uint256 indexed amount);
    event TokenHandler__TokenWithdrawn(address indexed token, address indexed user, uint256 indexed amount);

    // AdminOperations
    event AdminOperations__TokenHandlerUpdated(address indexed token, address newHandler);

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
        vm.expectEmit(true, true, false, false);
        emit AdminOperations__TokenHandlerUpdated(docTokenAddress, address(docTokenHandler));
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(docTokenAddress, address(docTokenHandler));

        // Send rBTC funds to mock contract and user
        vm.deal(mocProxyAddress, 1000 ether);
        vm.deal(USER, STARTING_RBTC_USER_BALANCE);

        // Mint 10000 DOC for the user
        mockDocToken.mint(USER, USER_TOTAL_DOC);

        // Make the starting point of the tests is that the user has already deposited 1000 DOC (so withdrawals can also be tested without much hassle)
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        dcaManager.createOrUpdateDcaSchedule(
            address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT, DOC_TO_SPEND, PURCHASE_PERIOD
        );
        vm.stopPrank();
    }

    /////////////////////////
    /// DOC deposit tests ///
    /////////////////////////
    function testDocDeposit() external {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenDeposited(address(mockDocToken), USER, DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, false);
        emit DcaManager__TokenBalanceUpdated(address(mockDocToken), SCHEDULE_INDEX, 2 * DOC_TO_DEPOSIT); // 2 *, since a previous deposit is made in the setup
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        vm.stopPrank();
    }

    function testCannotDepositZeroDoc() external {
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        vm.expectRevert(ITokenHandler.TokenHandler__DepositAmountMustBeGreaterThanZero.selector);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, 0);
        vm.stopPrank();
    }

    function testDepositRevertsIfDocNotApproved() external {
        vm.startPrank(USER);
        bytes memory encodedRevert = abi.encodeWithSelector(
            ITokenHandler.TokenHandler__InsufficientTokenAllowance.selector, address(mockDocToken)
        );
        vm.expectRevert(encodedRevert);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        vm.stopPrank();
    }

    ////////////////////////////
    /// DOC Withdrawal tests ///
    ////////////////////////////
    function testDocWithdrawal() external {
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, false);
        emit TokenHandler__TokenWithdrawn(address(mockDocToken), USER, DOC_TO_DEPOSIT);
        dcaManager.withdrawToken(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT);
        uint256 remainingAmount = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(remainingAmount, 0);
        vm.stopPrank();
    }

    function testCannotWithdrawZeroDoc() external {
        vm.startPrank(USER);
        vm.expectRevert(ITokenHandler.TokenHandler__WithdrawalAmountMustBeGreaterThanZero.selector);
        dcaManager.withdrawToken(address(mockDocToken), SCHEDULE_INDEX, 0);
        vm.stopPrank();
    }

    function testTokenWithdrawalRevertsIfAmountExceedsBalance() external {
        vm.startPrank(USER);
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__WithdrawalAmountExceedsBalance.selector,
            address(mockDocToken),
            USER_TOTAL_DOC,
            DOC_TO_DEPOSIT
        );
        vm.expectRevert(encodedRevert);
        dcaManager.withdrawToken(address(mockDocToken), SCHEDULE_INDEX, USER_TOTAL_DOC);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// DCA configuration tests ///
    ///////////////////////////////
    function testSetPurchaseAmount() external {
        vm.startPrank(USER);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_SPEND);
        assertEq(DOC_TO_SPEND, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testSetPurchasePeriod() external {
        vm.startPrank(USER);
        dcaManager.setPurchasePeriod(address(mockDocToken), SCHEDULE_INDEX, PURCHASE_PERIOD);
        assertEq(PURCHASE_PERIOD, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testPurchaseAmountCannotBeZero() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__PurchaseAmountMustBeGreaterThanZero.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX, 0);
        vm.stopPrank();
    }

    function testPurchaseAmountCannotBeMoreThanHalfBalance() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__PurchaseAmountMustBeLowerThanHalfOfBalance.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT / 2 + 1);
        vm.stopPrank();
    }

    //////////////////////
    /// Purchase tests ///
    //////////////////////
    function testSinglePurchase() external {
        vm.startPrank(USER);
        uint256 docBalanceBeforePurchase = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        uint256 RbtcBalanceBeforePurchase = docTokenHandler.getAccumulatedRbtcBalance();
        vm.stopPrank();
        vm.prank(OWNER);
        dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX);
        vm.startPrank(USER);
        uint256 docBalanceAfterPurchase = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        uint256 RbtcBalanceAfterPurchase = docTokenHandler.getAccumulatedRbtcBalance();
        vm.stopPrank();
        // Check that DOC was substracted and rBTC was added to user's balances
        assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, DOC_TO_SPEND);
        assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, DOC_TO_SPEND / BTC_PRICE);
    }

    function testCannotBuyIfPeriodNotElapsed() external {
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX, DOC_TO_SPEND);
        dcaManager.setPurchasePeriod(address(mockDocToken), SCHEDULE_INDEX, PURCHASE_PERIOD);
        vm.stopPrank();
        vm.prank(OWNER);
        dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX); // first purchase
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__CannotBuyIfPurchasePeriodHasNotElapsed.selector,
            block.timestamp + PURCHASE_PERIOD - block.timestamp
        );
        vm.expectRevert(encodedRevert);
        vm.prank(OWNER);
        dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX); // second purchase
    }

    function testSeveralPurchases() external {
        uint256 numOfPurchases = 5;
        vm.prank(USER);
        dcaManager.setPurchasePeriod(address(mockDocToken), SCHEDULE_INDEX, PURCHASE_PERIOD);
        for (uint256 i; i < numOfPurchases; i++) {
            vm.prank(OWNER);
            dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX);
            vm.warp(block.timestamp + PURCHASE_PERIOD);
        }
        vm.prank(USER);
        assertEq(docTokenHandler.getAccumulatedRbtcBalance(), (DOC_TO_SPEND / BTC_PRICE) * numOfPurchases);
    }

    function testRevertPurchasetIfDocRunsOut() external {
        uint256 numOfPurchases = DOC_TO_DEPOSIT / DOC_TO_SPEND;
        for (uint256 i; i < numOfPurchases; i++) {
            vm.prank(OWNER);
            dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX);
            vm.warp(block.timestamp + PURCHASE_PERIOD);
        }
        // Attempt to purchase once more
        bytes memory encodedRevert = abi.encodeWithSelector(
            IDcaManager.DcaManager__CannotBuyWithTokenBalanceLowerThanPurchaseAmount.selector, address(mockDocToken), 0
        );
        vm.expectRevert(encodedRevert);
        vm.prank(OWNER);
        dcaManager.buyRbtc(USER, address(mockDocToken), SCHEDULE_INDEX);
    }

    function testSeveralPurchasesWithSeveralSchedules() external {
        this.testCreateSeveralDcaSchedules();

        uint8 numOfPurchases = 5;
        uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
        uint256 docToSpend = DOC_TO_SPEND / NUM_OF_SCHEDULES;

        for (uint8 i; i < NUM_OF_SCHEDULES; i++) {
            uint256 scheduleIndex = i;
            uint256 purchasePeriod = PURCHASE_PERIOD + i * 5 seconds;
            for (uint8 j; j < numOfPurchases; j++) {
                vm.startPrank(USER);
                uint256 docBalanceBeforePurchase =
                    dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
                uint256 RbtcBalanceBeforePurchase = docTokenHandler.getAccumulatedRbtcBalance();
                vm.stopPrank();
                vm.prank(OWNER);
                dcaManager.buyRbtc(USER, address(mockDocToken), scheduleIndex);
                vm.startPrank(USER);
                uint256 docBalanceAfterPurchase =
                    dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
                uint256 RbtcBalanceAfterPurchase = docTokenHandler.getAccumulatedRbtcBalance();
                vm.stopPrank();
                // Check that DOC was substracted and rBTC was added to user's balances
                assertEq(docBalanceBeforePurchase - docBalanceAfterPurchase, docToSpend);
                assertEq(RbtcBalanceAfterPurchase - RbtcBalanceBeforePurchase, docToSpend / BTC_PRICE);

                vm.warp(block.timestamp + purchasePeriod);
            }
        }
        vm.prank(USER);
        assertEq(docTokenHandler.getAccumulatedRbtcBalance(), (DOC_TO_SPEND / BTC_PRICE) * numOfPurchases);
    }

    /////////////////////////////
    /// rBTC Withdrawal tests ///
    /////////////////////////////

    function testWithdrawRbtc() external {
        // TODO: test this for multiple stablecoins/schedules
        this.testSinglePurchase();
        vm.startPrank(USER);
        uint256 rbtcBalanceBeforeWithdrawal = USER.balance;
        dcaManager.withdrawAllAccmulatedRbtc();
        uint256 rbtcBalanceAfterWithdrawal = USER.balance;
        vm.stopPrank();
        assertEq(rbtcBalanceAfterWithdrawal - rbtcBalanceBeforeWithdrawal, DOC_TO_SPEND / BTC_PRICE);
    }

    /////////////////////////////////
    /// DcaSchedule tests  //////////
    /////////////////////////////////

    function testCreateDcaSchedule() external {
        vm.startPrank(USER);
        uint256 userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        vm.expectEmit(true, true, true, true);
        emit DcaManager__newDcaScheduleCreated(
            USER, address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT, DOC_TO_SPEND, PURCHASE_PERIOD
        );
        dcaManager.createOrUpdateDcaSchedule(
            address(mockDocToken), SCHEDULE_INDEX, DOC_TO_DEPOSIT, DOC_TO_SPEND, PURCHASE_PERIOD
        );
        uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX);
        assertEq(DOC_TO_DEPOSIT, userBalanceAfterDeposit - userBalanceBeforeDeposit);
        assertEq(DOC_TO_SPEND, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), SCHEDULE_INDEX));
        assertEq(PURCHASE_PERIOD, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), SCHEDULE_INDEX));
        vm.stopPrank();
    }

    function testCreateSeveralDcaSchedules() external {
        vm.startPrank(USER);
        mockDocToken.approve(address(docTokenHandler), DOC_TO_DEPOSIT);
        uint256 docToDeposit = DOC_TO_DEPOSIT / NUM_OF_SCHEDULES;
        uint256 purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES;
        // test with scheduleIndex == 0 updates the schedule created in setUp, so testUpdateSchedule() would be redundant
        for (uint256 i = 0; i < NUM_OF_SCHEDULES; i++) {
            uint256 scheduleIndex = SCHEDULE_INDEX + i;
            uint256 purchasePeriod = PURCHASE_PERIOD + i * 5 seconds;
            uint256 userBalanceBeforeDeposit;
            if (dcaManager.getMyDcaPositions(address(mockDocToken)).length > scheduleIndex) {
                userBalanceBeforeDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
            } else {
                userBalanceBeforeDeposit = 0;
            }
            vm.expectEmit(true, true, true, true);
            emit DcaManager__newDcaScheduleCreated(
                USER, address(mockDocToken), scheduleIndex, docToDeposit, purchaseAmount, purchasePeriod
            );
            dcaManager.createOrUpdateDcaSchedule(
                address(mockDocToken), scheduleIndex, docToDeposit, purchaseAmount, purchasePeriod
            );
            uint256 userBalanceAfterDeposit = dcaManager.getScheduleTokenBalance(address(mockDocToken), scheduleIndex);
            assertEq(docToDeposit, userBalanceAfterDeposit - userBalanceBeforeDeposit);
            assertEq(purchaseAmount, dcaManager.getSchedulePurchaseAmount(address(mockDocToken), scheduleIndex));
            assertEq(purchasePeriod, dcaManager.getSchedulePurchasePeriod(address(mockDocToken), scheduleIndex));
        }
        vm.stopPrank();
    }

    // function testUpdateSchedule() external {} REDUNDANT

    function testCannotUpdateInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__CannotUpdateInexistentSchedule.selector);
        dcaManager.depositToken(address(mockDocToken), SCHEDULE_INDEX + 1, DOC_TO_DEPOSIT);
        vm.expectRevert(IDcaManager.DcaManager__CannotUpdateInexistentSchedule.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1, DOC_TO_SPEND);
        vm.expectRevert(IDcaManager.DcaManager__CannotUpdateInexistentSchedule.selector);
        dcaManager.setPurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1, PURCHASE_PERIOD);
        vm.stopPrank();
    }

    function testCannotConsultInexistentSchedule() external {
        vm.startPrank(USER);
        vm.expectRevert(IDcaManager.DcaManager__DcaScheduleDoesNotExist.selector);
        dcaManager.getScheduleTokenBalance(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__DcaScheduleDoesNotExist.selector);
        dcaManager.getSchedulePurchaseAmount(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.expectRevert(IDcaManager.DcaManager__DcaScheduleDoesNotExist.selector);
        dcaManager.getSchedulePurchasePeriod(address(mockDocToken), SCHEDULE_INDEX + 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/
    function testUpdateTokenHandlerMustSupportInterface() external {
        vm.startBroadcast();
        DummyERC165Contract dummyERC165Contract = new DummyERC165Contract();
        vm.stopBroadcast();
        bytes memory encodedRevert = abi.encodeWithSelector(
            IAdminOperations.AdminOperations__ContractIsNotTokenHandler.selector, address(dummyERC165Contract)
        );
        
        vm.expectRevert(encodedRevert);
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), address(dummyERC165Contract));


        vm.expectRevert();
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), address(dcaManager));
    }

    function testUpdateTokenHandlerFailsIfAddressIsEoa() external {
        address dummyAddress = makeAddr("dummyAddress");
        bytes memory encodedRevert =
            abi.encodeWithSelector(IAdminOperations.AdminOperations__EoaCannotBeHandler.selector, dummyAddress);
        vm.expectRevert(encodedRevert);
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), dummyAddress);
    }

    function testTokenHandlerUpdated() external {
        address prevDocTokenHandler = adminOperations.getTokenHandler(address(mockDocToken));
        vm.startBroadcast();
        DocTokenHandler newDocTokenHandler = new DocTokenHandler(address(mockDocToken), address(dcaManager), address(mockMocProxy));
        vm.stopBroadcast();
        assert(prevDocTokenHandler != address(newDocTokenHandler));
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), address(newDocTokenHandler));
        assertEq(adminOperations.getTokenHandler(address(mockDocToken)), address(newDocTokenHandler));
    }

}

contract DummyERC165Contract {
    constructor (){}
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == type(IDcaManager).interfaceId; // Check against an interface different from TokenHandler's
    }
}