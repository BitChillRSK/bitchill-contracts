// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {OperationsAdmin} from "../../src/OperationsAdmin.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import "../../script/Constants.sol";

/**
 * @title GettersTest
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @notice Comprehensive test suite for all getter functions in the DCA contracts
 * @dev Tests normal functionality, edge cases, and revert conditions for getters
 */
contract GettersTest is Test {
    DcaManager dcaManager;
    OperationsAdmin operationsAdmin;

    address user1 = address(0x1);
    address user2 = address(0x2);
    address nonOwner = address(0x3);
    address owner = address(this);
    address mockToken = address(0x123);

    function setUp() public {
        // Deploy core contracts
        operationsAdmin = new OperationsAdmin();
        dcaManager = new DcaManager(address(operationsAdmin), MIN_PURCHASE_PERIOD, MAX_SCHEDULES_PER_TOKEN);
        
        // Setup operations admin
        operationsAdmin.setAdminRole(owner);
        operationsAdmin.addOrUpdateLendingProtocol("tropykus", 1);
        operationsAdmin.addOrUpdateLendingProtocol("sovryn", 2);
    }

    /*//////////////////////////////////////////////////////////////
                        DCAMANAGER GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dcaManager_getDcaSchedules_emptyByDefault() public {
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(user1, mockToken);
        assertEq(schedules.length, 0);
    }

    function test_dcaManager_getMyDcaSchedules_emptyByDefault() public {
        vm.prank(user1);
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getMyDcaSchedules(mockToken);
        assertEq(schedules.length, 0);
    }

    function test_dcaManager_getMyScheduleTokenBalance_reverts_invalidIndex() public {
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMyScheduleTokenBalance(mockToken, 0);
    }

    function test_dcaManager_getScheduleTokenBalance_reverts_invalidIndex() public {
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleTokenBalance(user1, mockToken, 0);
    }

    function test_dcaManager_getMySchedulePurchaseAmount_reverts_invalidIndex() public {
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMySchedulePurchaseAmount(mockToken, 0);
    }

    function test_dcaManager_getSchedulePurchaseAmount_reverts_invalidIndex() public {
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchaseAmount(user1, mockToken, 0);
    }

    function test_dcaManager_getMySchedulePurchasePeriod_reverts_invalidIndex() public {
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMySchedulePurchasePeriod(mockToken, 0);
    }

    function test_dcaManager_getSchedulePurchasePeriod_reverts_invalidIndex() public {
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchasePeriod(user1, mockToken, 0);
    }

    function test_dcaManager_getMyScheduleId_reverts_invalidIndex() public {
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMyScheduleId(mockToken, 0);
    }

    function test_dcaManager_getScheduleId_reverts_invalidIndex() public {
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleId(user1, mockToken, 0);
    }

    function test_dcaManager_getUsers_onlyOwner() public {
        address[] memory users = dcaManager.getUsers();
        assertEq(users.length, 0); // No users initially
    }

    function test_dcaManager_getUsers_reverts_notOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        dcaManager.getUsers();
    }

    function test_dcaManager_getAllTimeUserCount() public {
        uint256 count = dcaManager.getAllTimeUserCount();
        assertEq(count, 0); // No users initially
    }

    function test_dcaManager_getOperationsAdminAddress() public {
        address adminAddress = dcaManager.getOperationsAdminAddress();
        assertEq(adminAddress, address(operationsAdmin));
    }

    function test_dcaManager_getMinPurchasePeriod() public {
        uint256 minPeriod = dcaManager.getMinPurchasePeriod();
        assertEq(minPeriod, MIN_PURCHASE_PERIOD);
    }

    function test_dcaManager_getMaxSchedulesPerToken() public {
        uint256 maxSchedules = dcaManager.getMaxSchedulesPerToken();
        assertEq(maxSchedules, MAX_SCHEDULES_PER_TOKEN);
    }

    function test_dcaManager_getUsersDepositedTokens() public {
        address[] memory user1Tokens = dcaManager.getUsersDepositedTokens(user1);
        assertEq(user1Tokens.length, 0); // No deposits yet

        // Test user with no deposits
        address[] memory noTokens = dcaManager.getUsersDepositedTokens(address(0x999));
        assertEq(noTokens.length, 0);
    }

    function test_dcaManager_getMyInterestAccrued_reverts_tokenDoesNotYieldInterest() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, mockToken));
        dcaManager.getMyInterestAccrued(mockToken, 0); // Index 0 = no lending
    }

    function test_dcaManager_getInterestAccrued_reverts_tokenDoesNotYieldInterest() public {
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, mockToken));
        dcaManager.getInterestAccrued(user1, mockToken, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    OPERATIONS ADMIN GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_operationsAdmin_getTokenHandler() public {
        // Test non-existent handler returns zero address
        address nonExistentHandler = operationsAdmin.getTokenHandler(mockToken, 1);
        assertEq(nonExistentHandler, address(0));

        address nonExistentHandler2 = operationsAdmin.getTokenHandler(address(0x999), 1);
        assertEq(nonExistentHandler2, address(0));
    }

    function test_operationsAdmin_getLendingProtocolIndex() public {
        uint256 tropykusIndex = operationsAdmin.getLendingProtocolIndex("tropykus");
        assertEq(tropykusIndex, 1);

        uint256 sovrynIndex = operationsAdmin.getLendingProtocolIndex("sovryn");
        assertEq(sovrynIndex, 2);

        // Test non-existent protocol
        uint256 nonExistentIndex = operationsAdmin.getLendingProtocolIndex("nonexistent");
        assertEq(nonExistentIndex, 0);
    }

    function test_operationsAdmin_getLendingProtocolName() public {
        string memory tropykusName = operationsAdmin.getLendingProtocolName(1);
        assertEq(tropykusName, "tropykus");

        string memory sovrynName = operationsAdmin.getLendingProtocolName(2);
        assertEq(sovrynName, "sovryn");

        // Test non-existent index
        string memory emptyName = operationsAdmin.getLendingProtocolName(999);
        assertEq(bytes(emptyName).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getters_withZeroAddress() public {
        // Test with zero address user
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(address(0), mockToken);
        assertEq(schedules.length, 0);

        address[] memory tokens = dcaManager.getUsersDepositedTokens(address(0));
        assertEq(tokens.length, 0);
    }

    function test_getters_withNonExistentToken() public {
        address fakeToken = address(0x999);
        
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(user1, fakeToken);
        assertEq(schedules.length, 0);

        address handler = operationsAdmin.getTokenHandler(fakeToken, 1);
        assertEq(handler, address(0));
    }

    function test_getters_consistencyBetweenUserAndCallerVariants() public {
        vm.prank(user1);
        IDcaManager.DcaDetails[] memory mySchedules = dcaManager.getMyDcaSchedules(mockToken);
        
        IDcaManager.DcaDetails[] memory userSchedules = dcaManager.getDcaSchedules(user1, mockToken);
        
        assertEq(mySchedules.length, userSchedules.length);
    }

    /*//////////////////////////////////////////////////////////////
                        ADDITIONAL VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getters_validateScheduleIndex_modifier() public {
        // Test that validateScheduleIndex works correctly for different getter functions
        // All these should revert with the same error for invalid indices
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleTokenBalance(user1, mockToken, 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchaseAmount(user1, mockToken, 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchasePeriod(user1, mockToken, 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleId(user1, mockToken, 999);
    }

    function test_getters_returnTypesAndDefaults() public {
        // Test that getters return appropriate default values for empty states
        assertEq(dcaManager.getAllTimeUserCount(), 0);
        assertEq(dcaManager.getMinPurchasePeriod(), MIN_PURCHASE_PERIOD);
        assertEq(dcaManager.getMaxSchedulesPerToken(), MAX_SCHEDULES_PER_TOKEN);
        assertNotEq(dcaManager.getOperationsAdminAddress(), address(0));
        
        // Test empty arrays
        address[] memory emptyTokens = dcaManager.getUsersDepositedTokens(user1);
        assertEq(emptyTokens.length, 0);
        
        address[] memory emptyUsers = dcaManager.getUsers();
        assertEq(emptyUsers.length, 0);
        
        IDcaManager.DcaDetails[] memory emptySchedules = dcaManager.getDcaSchedules(user1, mockToken);
        assertEq(emptySchedules.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                      COMPREHENSIVE EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getters_withLargeValues() public {
        // Test getters work with maximum uint256 values without overflow
        address[] memory schedules = dcaManager.getUsersDepositedTokens(user1);
        assertEq(schedules.length, 0);
        
        // Test protocol index at max value
        string memory protocolName = operationsAdmin.getLendingProtocolName(type(uint256).max);
        assertEq(bytes(protocolName).length, 0);
    }

    function test_getters_immutableVsStorage() public {
        // Test that immutable values are returned correctly
        assertNotEq(dcaManager.getOperationsAdminAddress(), address(0));
        assertGt(dcaManager.getMinPurchasePeriod(), 0);
        assertGt(dcaManager.getMaxSchedulesPerToken(), 0);
        
        // Test storage values
        assertEq(dcaManager.getAllTimeUserCount(), 0);
        assertEq(dcaManager.getUsers().length, 0);
    }

    function test_getters_accessControl() public {
        // Test that view functions don't have access control restrictions
        vm.prank(nonOwner);
        assertEq(dcaManager.getAllTimeUserCount(), 0);
        
        vm.prank(nonOwner);
        assertNotEq(dcaManager.getOperationsAdminAddress(), address(0));
        
        vm.prank(nonOwner);
        uint256 minPeriod = dcaManager.getMinPurchasePeriod();
        assertEq(minPeriod, MIN_PURCHASE_PERIOD);
        
        // Test that only getUsers() requires owner permission
        vm.prank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        dcaManager.getUsers();
    }

    function test_getters_gasOptimization() public {
        // Test that getters are gas efficient and don't revert unexpectedly
        uint256 gasBefore = gasleft();
        dcaManager.getAllTimeUserCount();
        uint256 gasAfter = gasleft();
        assertLt(gasBefore - gasAfter, 10000); // Should be very cheap
        
        gasBefore = gasleft();
        dcaManager.getMinPurchasePeriod();
        gasAfter = gasleft();
        assertLt(gasBefore - gasAfter, 10000);
        
        gasBefore = gasleft();
        operationsAdmin.getLendingProtocolName(1);
        gasAfter = gasleft();
        assertLt(gasBefore - gasAfter, 15000); // String operations slightly more expensive
    }

    function test_getters_stateConsistency() public {
        // Verify that related getters return consistent values
        assertEq(dcaManager.getMinPurchasePeriod(), MIN_PURCHASE_PERIOD);
        assertEq(dcaManager.getMaxSchedulesPerToken(), MAX_SCHEDULES_PER_TOKEN);
        
        // Test protocol mappings are bidirectional
        assertEq(operationsAdmin.getLendingProtocolIndex("tropykus"), 1);
        assertEq(operationsAdmin.getLendingProtocolName(1), "tropykus");
        
        assertEq(operationsAdmin.getLendingProtocolIndex("sovryn"), 2);
        assertEq(operationsAdmin.getLendingProtocolName(2), "sovryn");
    }

    function test_getters_errorHandling() public {
        // Test that all "My" variant getters properly revert for invalid schedules
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMyScheduleTokenBalance(mockToken, 0);
        
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMySchedulePurchaseAmount(mockToken, 0);
        
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMySchedulePurchasePeriod(mockToken, 0);
        
        vm.prank(user1);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMyScheduleId(mockToken, 0);
    }

    function test_getters_boundaryConditions() public {
        // Test boundary conditions for various getters
        
        // Test with address(0) as token
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(user1, address(0));
        assertEq(schedules.length, 0);
        
        // Test protocol index 0 (should return empty name)
        string memory emptyProtocol = operationsAdmin.getLendingProtocolName(0);
        assertEq(bytes(emptyProtocol).length, 0);
        
        // Test empty protocol name (should return 0)
        uint256 emptyIndex = operationsAdmin.getLendingProtocolIndex("");
        assertEq(emptyIndex, 0);
    }
} 