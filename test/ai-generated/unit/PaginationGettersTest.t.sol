// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DcaManager} from "../../../src/DcaManager.sol";
import {OperationsAdmin} from "../../../src/OperationsAdmin.sol";
import {MockStablecoin} from "../../mocks/MockStablecoin.sol";
import {MockKdocToken} from "../../mocks/MockKdocToken.sol";
import {TropykusErc20HandlerDex} from "../../../src/TropykusErc20HandlerDex.sol";
import {IPurchaseUniswap} from "../../../src/interfaces/IPurchaseUniswap.sol";
import {ICoinPairPrice} from "../../../src/interfaces/ICoinPairPrice.sol";
import {MockMocOracle} from "../../mocks/MockMocOracle.sol";
import {MockWrbtcToken} from "../../mocks/MockWrbtcToken.sol";
import {IWRBTC} from "../../../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {IDcaManager} from "../../../src/interfaces/IDcaManager.sol";
import {IFeeHandler} from "../../../src/interfaces/IFeeHandler.sol";
import "../../../script/Constants.sol";

/**
 * @title PaginationGettersTest
 * @notice Tests for DCA Manager pagination and getter functions
 * @dev Covers item 5-B from the coverage plan: Pagination getters getUserAtIndex coverage
 */
contract PaginationGettersTest is Test {
    
    /*//////////////////////////////////////////////////////////////
                               CONTRACTS
    //////////////////////////////////////////////////////////////*/
    
    DcaManager public dcaManager;
    OperationsAdmin public operationsAdmin;
    MockStablecoin public stablecoin;
    MockKdocToken public kToken;
    TropykusErc20HandlerDex public handler;
    MockWrbtcToken public wrbtcToken;
    MockMocOracle public mocOracle;
    
    /*//////////////////////////////////////////////////////////////
                               TEST ACCOUNTS
    //////////////////////////////////////////////////////////////*/
    
    address public constant OWNER = address(0x1111);
    address public constant ADMIN = address(0x2222);
    address public constant SWAPPER = address(0x3333);
    address public constant FEE_COLLECTOR = address(0x4444);
    
    // Array of test users for pagination testing
    address[] internal testUsers;
    uint256 public constant NUM_TEST_USERS = 20;
    
    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/
    
    function setUp() public {
        // Deploy contracts
        vm.prank(OWNER);
        operationsAdmin = new OperationsAdmin();
        
        vm.prank(OWNER);
        dcaManager = new DcaManager(address(operationsAdmin), MIN_PURCHASE_PERIOD, MAX_SCHEDULES_PER_TOKEN);
        
        stablecoin = new MockStablecoin(address(this));
        kToken = new MockKdocToken(address(stablecoin));
        wrbtcToken = new MockWrbtcToken();
        mocOracle = new MockMocOracle();
        
        // Setup roles
        vm.prank(OWNER);
        operationsAdmin.setAdminRole(ADMIN);
        
        vm.prank(ADMIN);
        operationsAdmin.setSwapperRole(SWAPPER);
        
        vm.prank(ADMIN);
        operationsAdmin.addOrUpdateLendingProtocol("Tropykus", TROPYKUS_INDEX);
        
        // Deploy and register handler
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE_TEST,
            feePurchaseLowerBound: FEE_PURCHASE_LOWER_BOUND,
            feePurchaseUpperBound: FEE_PURCHASE_UPPER_BOUND
        });
        
        address[] memory intermediateTokens = new address[](0);
        uint24[] memory poolFeeRates = new uint24[](1);
        poolFeeRates[0] = 3000;
        
        IPurchaseUniswap.UniswapSettings memory uniswapSettings = IPurchaseUniswap.UniswapSettings({
            wrBtcToken: IWRBTC(address(wrbtcToken)),
            swapRouter02: ISwapRouter02(address(0x777)),
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracle: ICoinPairPrice(address(mocOracle))
        });
        
        vm.prank(OWNER);
        handler = new TropykusErc20HandlerDex(
            address(dcaManager),
            address(stablecoin),
            address(kToken),
            uniswapSettings,
            MIN_PURCHASE_AMOUNT,
            FEE_COLLECTOR,
            feeSettings,
            9970,
            9900,
            EXCHANGE_RATE_DECIMALS
        );
        
        vm.prank(ADMIN);
        operationsAdmin.assignOrUpdateTokenHandler(
            address(stablecoin),
            TROPYKUS_INDEX,
            address(handler)
        );
        
        // Create test users and fund them
        for (uint256 i = 0; i < NUM_TEST_USERS; i++) {
            address user = address(uint160(0x10000 + i));
            testUsers.push(user);
            stablecoin.mint(user, 10000 ether);
            
            vm.prank(user);
            stablecoin.approve(address(handler), type(uint256).max);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                           BASIC PAGINATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_getUserAtIndex_withNoUsers() public {
        // Should return zero address when no users exist
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, 0));
        dcaManager.getUserAtIndex(0);
    }
    
    function test_getUserAtIndex_singleUser() public {
        // Create DCA schedule for first user
        vm.prank(testUsers[0]);
        dcaManager.createDcaSchedule(
            address(stablecoin),
            500 ether,           // depositAmount
            100 ether,           // purchaseAmount
            MIN_PURCHASE_PERIOD, // purchasePeriod
            TROPYKUS_INDEX       // lendingProtocolIndex
        );
        
        // Check user can be retrieved at index 0
        address retrievedUser = dcaManager.getUserAtIndex(0);
        assertEq(retrievedUser, testUsers[0]);
        
        // Index 1 should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, 1));
        dcaManager.getUserAtIndex(1);
    }
    
    function test_getUserAtIndex_multipleUsers() public {
        // Create DCA schedules for first 5 users
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,           // depositAmount
                100 ether,           // purchaseAmount
                MIN_PURCHASE_PERIOD, // purchasePeriod
                TROPYKUS_INDEX       // lendingProtocolIndex
            );
        }
        
        // Verify all users can be retrieved in correct order
        for (uint256 i = 0; i < 5; i++) {
            address retrievedUser = dcaManager.getUserAtIndex(i);
            assertEq(retrievedUser, testUsers[i]);
        }
        
        // Index beyond the array should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, 5));
        dcaManager.getUserAtIndex(5);
    }
    
    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_getUserAtIndex_outOfBounds_reverts() public {
        // Create schedule for one user
        vm.prank(testUsers[0]);
        dcaManager.createDcaSchedule(
            address(stablecoin),
            500 ether,           // depositAmount
            100 ether,           // purchaseAmount
            MIN_PURCHASE_PERIOD, // purchasePeriod
            TROPYKUS_INDEX       // lendingProtocolIndex
        );
        
        // Large index should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, 999));
        dcaManager.getUserAtIndex(999);
    }
    
    function test_getUserAtIndex_duplicateUsers() public {
        // User creates multiple schedules - should only appear once in users array
        vm.startPrank(testUsers[0]);
        dcaManager.createDcaSchedule(
            address(stablecoin),
            500 ether,
            100 ether,
            MIN_PURCHASE_PERIOD,
            TROPYKUS_INDEX
        );
        dcaManager.createDcaSchedule(
            address(stablecoin),
            300 ether,
            50 ether,
            MIN_PURCHASE_PERIOD,
            TROPYKUS_INDEX
        );
        vm.stopPrank();
        
        // Should only have one user in array
        address retrievedUser = dcaManager.getUserAtIndex(0);
        assertEq(retrievedUser, testUsers[0]);
        
        // Second index should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, 1));
        dcaManager.getUserAtIndex(1);
    }
    
    function test_getUserAtIndex_afterUserDeletion() public {
        // Create schedules for 3 users
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,
                100 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // Verify all three users are registered before deletion
        assertEq(dcaManager.getUserAtIndex(0), testUsers[0]);
        assertEq(dcaManager.getUserAtIndex(1), testUsers[1]);
        assertEq(dcaManager.getUserAtIndex(2), testUsers[2]);
        
        // Get the schedule ID for the user who wants to delete and delete it
        vm.startPrank(testUsers[1]);
        bytes32 scheduleId = dcaManager.getMyScheduleId(address(stablecoin), 0);
        dcaManager.deleteDcaSchedule(address(stablecoin), scheduleId);
        vm.stopPrank();
        
        // All three users should still be retrievable (users array doesn't shrink on deletion)
        assertEq(dcaManager.getUserAtIndex(0), testUsers[0]);
        assertEq(dcaManager.getUserAtIndex(1), testUsers[1]);
        assertEq(dcaManager.getUserAtIndex(2), testUsers[2]);
    }
    
    function test_getUserAtIndex_largeDataset() public {
        // Create schedules for many users to test pagination with larger datasets
        uint256 numUsers = 15;
        
        for (uint256 i = 0; i < numUsers; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                (i + 1) * 100 ether, // Varying deposit amounts
                50 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // Verify all users can be retrieved correctly
        for (uint256 i = 0; i < numUsers; i++) {
            address retrievedUser = dcaManager.getUserAtIndex(i);
            assertEq(retrievedUser, testUsers[i]);
        }
        
        // Beyond the array should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, numUsers));
        dcaManager.getUserAtIndex(numUsers);
    }
    
    function test_getUserAtIndex_gasEfficiency() public {
        // Create schedules for several users
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,
                100 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // Test gas efficiency - should be O(1) for any index
        uint256 gasBefore = gasleft();
        dcaManager.getUserAtIndex(0);
        uint256 gasUsedFirst = gasBefore - gasleft();
        
        gasBefore = gasleft();
        dcaManager.getUserAtIndex(9);
        uint256 gasUsedLast = gasBefore - gasleft();
        
        // Gas usage should be similar regardless of index (O(1))
        assertApproxEqRel(gasUsedFirst, gasUsedLast, 0.1e18); // Within 10%
    }
    
    /*//////////////////////////////////////////////////////////////
                           CONSISTENCY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_getUsers_consistency() public {
        // Create schedules for several users
        address[] memory expectedUsers = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            expectedUsers[i] = testUsers[i];
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,
                100 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // Verify getUsers() returns same as individual getUserAtIndex calls
        address[] memory allUsers = dcaManager.getUsers();
        assertEq(allUsers.length, 5);
        
        for (uint256 i = 0; i < 5; i++) {
            assertEq(allUsers[i], expectedUsers[i]);
            assertEq(dcaManager.getUserAtIndex(i), expectedUsers[i]);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFuzz_getUserAtIndex_boundaryValues(uint8 numUsers) public {
        vm.assume(numUsers > 0 && numUsers <= NUM_TEST_USERS);
        
        // Create schedules for specified number of users
        for (uint256 i = 0; i < numUsers; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,
                100 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // All valid indexes should work
        for (uint256 i = 0; i < numUsers; i++) {
            address retrievedUser = dcaManager.getUserAtIndex(i);
            assertEq(retrievedUser, testUsers[i]);
        }
        
        // First invalid index should revert
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__UserIndexOutOfBounds.selector, numUsers));
        dcaManager.getUserAtIndex(numUsers);
    }
    
    function testFuzz_getUserAtIndex_randomAccess(uint256 seed) public {
        uint256 numUsers = 10;
        
        // Create schedules for 10 users
        for (uint256 i = 0; i < numUsers; i++) {
            vm.prank(testUsers[i]);
            dcaManager.createDcaSchedule(
                address(stablecoin),
                500 ether,
                100 ether,
                MIN_PURCHASE_PERIOD,
                TROPYKUS_INDEX
            );
        }
        
        // Test random valid access
        uint256 randomIndex = seed % numUsers;
        address retrievedUser = dcaManager.getUserAtIndex(randomIndex);
        assertEq(retrievedUser, testUsers[randomIndex]);
    }
    
    function testFuzz_invalidUserIndex(uint256 invalidIndex) public {
        vm.assume(invalidIndex > 0 && invalidIndex < type(uint32).max); // Bound to reasonable range
        
        // Should revert for any invalid index when no users exist
        vm.expectRevert();
        dcaManager.getUserAtIndex(invalidIndex);
    }
} 