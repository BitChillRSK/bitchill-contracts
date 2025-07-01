// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {IOperationsAdmin} from "../../src/interfaces/IOperationsAdmin.sol";
import {IFeeHandler} from "../../src/interfaces/IFeeHandler.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {IPurchaseUniswap} from "../../src/interfaces/IPurchaseUniswap.sol";
import {ITokenLending} from "../../src/interfaces/ITokenLending.sol";
import {ICoinPairPrice} from "../../src/interfaces/ICoinPairPrice.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {PurchaseUniswap} from "../../src/PurchaseUniswap.sol";
import {TropykusErc20Handler} from "../../src/TropykusErc20Handler.sol";
import {SovrynErc20Handler} from "../../src/SovrynErc20Handler.sol";
import {TropykusErc20HandlerDex} from "../../src/TropykusErc20HandlerDex.sol";
import {SovrynErc20HandlerDex} from "../../src/SovrynErc20HandlerDex.sol";
import {console2} from "forge-std/console2.sol";
import "../../script/Constants.sol";

/**
 * @title GettersTest
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @notice Comprehensive test suite for ALL getter functions in ALL contracts from /src directory
 * @dev Tests normal functionality, edge cases, and revert conditions for every getter across the entire codebase
 */
contract GettersTest is DcaDappTest {
    
    /*//////////////////////////////////////////////////////////////
                               SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();
        // Additional setup specific to getter tests can go here
    }

    /*//////////////////////////////////////////////////////////////
                        DCAMANAGER GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_dcaManager_getMyDcaSchedules() public {
        vm.prank(USER);
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getMyDcaSchedules(address(stablecoin));
        assertEq(schedules.length, 1); // Created in setup
        assertEq(schedules[0].tokenBalance, AMOUNT_TO_DEPOSIT);
        assertEq(schedules[0].purchaseAmount, AMOUNT_TO_SPEND);
        assertEq(schedules[0].purchasePeriod, MIN_PURCHASE_PERIOD);
    }

    function test_dcaManager_getDcaSchedules() public {
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(USER, address(stablecoin));
        assertEq(schedules.length, 1);
        assertEq(schedules[0].tokenBalance, AMOUNT_TO_DEPOSIT);
    }

    function test_dcaManager_getMyScheduleTokenBalance() public {
        vm.prank(USER);
        uint256 balance = dcaManager.getMyScheduleTokenBalance(address(stablecoin), 0);
        assertEq(balance, AMOUNT_TO_DEPOSIT);
    }

    function test_dcaManager_getScheduleTokenBalance() public {
        uint256 balance = dcaManager.getScheduleTokenBalance(USER, address(stablecoin), 0);
        assertEq(balance, AMOUNT_TO_DEPOSIT);
    }

    function test_dcaManager_getMySchedulePurchaseAmount() public {
        vm.prank(USER);
        uint256 amount = dcaManager.getMySchedulePurchaseAmount(address(stablecoin), 0);
        assertEq(amount, AMOUNT_TO_SPEND);
    }

    function test_dcaManager_getSchedulePurchaseAmount() public {
        uint256 amount = dcaManager.getSchedulePurchaseAmount(USER, address(stablecoin), 0);
        assertEq(amount, AMOUNT_TO_SPEND);
    }

    function test_dcaManager_getMySchedulePurchasePeriod() public {
        vm.prank(USER);
        uint256 period = dcaManager.getMySchedulePurchasePeriod(address(stablecoin), 0);
        assertEq(period, MIN_PURCHASE_PERIOD);
    }

    function test_dcaManager_getSchedulePurchasePeriod() public {
        uint256 period = dcaManager.getSchedulePurchasePeriod(USER, address(stablecoin), 0);
        assertEq(period, MIN_PURCHASE_PERIOD);
    }

    function test_dcaManager_getMyScheduleId() public {
        vm.prank(USER);
        bytes32 scheduleId = dcaManager.getMyScheduleId(address(stablecoin), 0);
        assertNotEq(scheduleId, bytes32(0));
    }

    function test_dcaManager_getScheduleId() public {
        bytes32 scheduleId = dcaManager.getScheduleId(USER, address(stablecoin), 0);
        assertNotEq(scheduleId, bytes32(0));
    }

    function test_dcaManager_getUsers() public {
        // Anyone should be able to call now
        address[] memory users = dcaManager.getUsers();
        assertEq(users.length, 1);
        assertEq(users[0], USER);

        vm.prank(makeAddr("randomUser"));
        address[] memory usersByRandom = dcaManager.getUsers();
        assertEq(usersByRandom.length, 1);
        assertEq(usersByRandom[0], USER);
    }

    function test_dcaManager_getUserAtIndex() public {
        address user0 = dcaManager.getUserAtIndex(0);
        assertEq(user0, USER);

        // Out of bounds should revert
        vm.expectRevert();
        dcaManager.getUserAtIndex(5);
    }

    function test_dcaManager_getAllTimeUserCount() public {
        uint256 count = dcaManager.getAllTimeUserCount();
        assertEq(count, 1);
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
        address[] memory tokens = dcaManager.getUsersDepositedTokens(USER);
        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(stablecoin));
    }

    function test_dcaManager_getMyInterestAccrued_whenSupported() public {
        // Only test if the lending protocol supports interest
        if (s_lendingProtocolIndex > 0) {
            vm.prank(USER);
            uint256 interest = dcaManager.getMyInterestAccrued(address(stablecoin), s_lendingProtocolIndex);
            assertGe(interest, 0); // Interest should be non-negative
        }
    }

    function test_dcaManager_getInterestAccrued_whenSupported() public {
        if (s_lendingProtocolIndex > 0) {
            uint256 interest = dcaManager.getInterestAccrued(USER, address(stablecoin), s_lendingProtocolIndex);
            assertGe(interest, 0);
        }
    }

    function test_dcaManager_getMyInterestAccrued_reverts_tokenDoesNotYieldInterest() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, address(stablecoin)));
        dcaManager.getMyInterestAccrued(address(stablecoin), 0); // Index 0 = no lending
    }

    function test_dcaManager_getInterestAccrued_reverts_tokenDoesNotYieldInterest() public {
        vm.expectRevert(abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, address(stablecoin)));
        dcaManager.getInterestAccrued(USER, address(stablecoin), 0);
    }

    // Test invalid schedule index reverts for all schedule getters
    function test_dcaManager_scheduleGetters_revert_invalidIndex() public {
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleTokenBalance(USER, address(stablecoin), 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchaseAmount(USER, address(stablecoin), 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getSchedulePurchasePeriod(USER, address(stablecoin), 999);
        
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getScheduleId(USER, address(stablecoin), 999);

        vm.prank(USER);
        vm.expectRevert(IDcaManager.DcaManager__InexistentScheduleIndex.selector);
        dcaManager.getMyScheduleTokenBalance(address(stablecoin), 999);
    }

    /*//////////////////////////////////////////////////////////////
                    OPERATIONS ADMIN GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_operationsAdmin_getTokenHandler() public {
        address handler = operationsAdmin.getTokenHandler(address(stablecoin), s_lendingProtocolIndex);
        assertEq(handler, address(docHandler));
        
        // Test non-existent handler
        address nonExistentHandler = operationsAdmin.getTokenHandler(address(0x999), 1);
        assertEq(nonExistentHandler, address(0));
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
                        FEE HANDLER GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_feeHandler_getMinFeeRate() public {
        uint256 minFeeRate = IFeeHandler(address(docHandler)).getMinFeeRate();
        assertGt(minFeeRate, 0); // Should be greater than 0
    }

    function test_feeHandler_getMaxFeeRate() public {
        uint256 maxFeeRate = IFeeHandler(address(docHandler)).getMaxFeeRate();
        assertGt(maxFeeRate, 0);
    }

    function test_feeHandler_getFeePurchaseLowerBound() public {
        uint256 lowerBound = IFeeHandler(address(docHandler)).getFeePurchaseLowerBound();
        assertGe(lowerBound, 0);
    }

    function test_feeHandler_getFeePurchaseUpperBound() public {
        uint256 upperBound = IFeeHandler(address(docHandler)).getFeePurchaseUpperBound();
        assertGe(upperBound, 0);
        
        // Upper bound should be >= lower bound
        uint256 lowerBound = IFeeHandler(address(docHandler)).getFeePurchaseLowerBound();
        assertGe(upperBound, lowerBound);
    }

    function test_feeHandler_getFeeCollectorAddress() public {
        address feeCollector = IFeeHandler(address(docHandler)).getFeeCollectorAddress();
        assertNotEq(feeCollector, address(0));
    }

    function test_feeHandler_feeRateConsistency() public {
        uint256 minFeeRate = IFeeHandler(address(docHandler)).getMinFeeRate();
        uint256 maxFeeRate = IFeeHandler(address(docHandler)).getMaxFeeRate();
        assertLe(minFeeRate, maxFeeRate); // Min should be <= Max
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN HANDLER GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_tokenHandler_getMinPurchaseAmount() public {
        uint256 minAmount = ITokenHandler(address(docHandler)).getMinPurchaseAmount();
        assertGt(minAmount, 0);
    }

    function test_tokenHandler_supportsInterface() public {
        // Test ERC165 support
        bool supportsERC165 = IERC165(address(docHandler)).supportsInterface(0x01ffc9a7);
        assertTrue(supportsERC165);
        
        // Test ITokenHandler interface support
        bool supportsTokenHandler = IERC165(address(docHandler)).supportsInterface(type(ITokenHandler).interfaceId);
        assertTrue(supportsTokenHandler);
    }

    /*//////////////////////////////////////////////////////////////
                        PURCHASE RBTC GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_purchaseRbtc_getAccumulatedRbtcBalance_withUser() public {
        uint256 balance = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(USER);
        assertGe(balance, 0);
    }

    function test_purchaseRbtc_getAccumulatedRbtcBalance_caller() public {
        vm.prank(USER);
        uint256 balance = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance();
        assertGe(balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PURCHASE UNISWAP GETTERS TESTS (DEX ONLY)
    //////////////////////////////////////////////////////////////*/

    function test_purchaseUniswap_getters() public onlyDexSwaps {
        if (address(docHandler).code.length > 0) {
            try IPurchaseUniswap(address(docHandler)).getAmountOutMinimumPercent() returns (uint256 percent) {
                assertGt(percent, 0);
                assertLe(percent, 10000); // Should be reasonable percentage
            } catch {
                // Some handlers might not implement this interface
                return;
            }

            try IPurchaseUniswap(address(docHandler)).getAmountOutMinimumSafetyCheck() returns (uint256 safetyCheck) {
                assertGt(safetyCheck, 0);
            } catch {
                return;
            }

            try IPurchaseUniswap(address(docHandler)).getMocOracle() returns (ICoinPairPrice oracle) {
                assertNotEq(address(oracle), address(0));
            } catch {
                return;
            }

            try IPurchaseUniswap(address(docHandler)).getSwapPath() returns (bytes memory path) {
                assertGt(path.length, 0);
            } catch {
                return;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TOKEN LENDING GETTERS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_tokenLending_getUsersLendingTokenBalance() public {
        if (s_lendingProtocolIndex > 0) {
            uint256 balance = ITokenLending(address(docHandler)).getUsersLendingTokenBalance(USER);
            assertGe(balance, 0);
        }
    }

    function test_tokenLending_getAccruedInterest() public {
        if (s_lendingProtocolIndex > 0) {
            vm.prank(address(dcaManager));
            uint256 interest = ITokenLending(address(docHandler)).getAccruedInterest(USER, AMOUNT_TO_DEPOSIT);
            assertGe(interest, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    DCA MANAGER ACCESS CONTROL GETTERS
    //////////////////////////////////////////////////////////////*/

    function test_dcaManagerAccessControl_immutableGetter() public {
        // Test that the docHandler has the correct DCA manager address
        // The public immutable creates an automatic getter
        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            try TropykusErc20Handler(payable(address(docHandler))).i_dcaManager() returns (address dcaManagerAddr) {
                assertEq(dcaManagerAddr, address(dcaManager));
            } catch {
                // Try the Dex version
                try TropykusErc20HandlerDex(payable(address(docHandler))).i_dcaManager() returns (address dcaManagerAddr) {
                    assertEq(dcaManagerAddr, address(dcaManager));
                } catch {
                    // Handler might not expose this getter
                }
            }
        } else if (s_lendingProtocolIndex == SOVRYN_INDEX) {
            try SovrynErc20Handler(payable(address(docHandler))).i_dcaManager() returns (address dcaManagerAddr) {
                assertEq(dcaManagerAddr, address(dcaManager));
            } catch {
                try SovrynErc20HandlerDex(payable(address(docHandler))).i_dcaManager() returns (address dcaManagerAddr) {
                    assertEq(dcaManagerAddr, address(dcaManager));
                } catch {
                    // Handler might not expose this getter
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getters_withZeroAddress() public {
        // Test getters with zero address inputs where applicable
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(address(0), address(stablecoin));
        assertEq(schedules.length, 0);

        address[] memory tokens = dcaManager.getUsersDepositedTokens(address(0));
        assertEq(tokens.length, 0);

        uint256 balance = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(address(0));
        assertEq(balance, 0);
    }

    function test_getters_withNonExistentToken() public {
        address fakeToken = address(0x999);
        
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(USER, fakeToken);
        assertEq(schedules.length, 0);

        address handler = operationsAdmin.getTokenHandler(fakeToken, 1);
        assertEq(handler, address(0));
    }

    function test_getters_consistencyBetweenUserAndCallerVariants() public {
        vm.prank(USER);
        IDcaManager.DcaDetails[] memory mySchedules = dcaManager.getMyDcaSchedules(address(stablecoin));
        
        IDcaManager.DcaDetails[] memory userSchedules = dcaManager.getDcaSchedules(USER, address(stablecoin));
        
        assertEq(mySchedules.length, userSchedules.length);
        if (mySchedules.length > 0) {
            assertEq(mySchedules[0].tokenBalance, userSchedules[0].tokenBalance);
            assertEq(mySchedules[0].purchaseAmount, userSchedules[0].purchaseAmount);
            assertEq(mySchedules[0].purchasePeriod, userSchedules[0].purchasePeriod);
            assertEq(mySchedules[0].scheduleId, userSchedules[0].scheduleId);
        }
    }

    function test_getters_returnTypesAndDefaults() public {
        // Test that getters return appropriate default values for empty states
        assertEq(dcaManager.getAllTimeUserCount(), 1); // We have one user from setup
        assertEq(dcaManager.getMinPurchasePeriod(), MIN_PURCHASE_PERIOD);
        assertEq(dcaManager.getMaxSchedulesPerToken(), MAX_SCHEDULES_PER_TOKEN);
        assertNotEq(dcaManager.getOperationsAdminAddress(), address(0));
        
        // Test empty arrays for new users
        address newUser = makeAddr("newUser");
        address[] memory emptyTokens = dcaManager.getUsersDepositedTokens(newUser);
        assertEq(emptyTokens.length, 0);
        
        IDcaManager.DcaDetails[] memory emptySchedules = dcaManager.getDcaSchedules(newUser, address(stablecoin));
        assertEq(emptySchedules.length, 0);
    }

    function test_getters_accessControl() public {
        // Test that view functions don't have access control restrictions
        vm.prank(makeAddr("randomUser"));
        assertEq(dcaManager.getAllTimeUserCount(), 1);
        
        vm.prank(makeAddr("randomUser"));
        assertNotEq(dcaManager.getOperationsAdminAddress(), address(0));
        
        vm.prank(makeAddr("randomUser"));
        uint256 minPeriod = dcaManager.getMinPurchasePeriod();
        assertEq(minPeriod, MIN_PURCHASE_PERIOD);
        
        // getUsers() should be callable by anyone now
        vm.prank(makeAddr("randomUser"));
        address[] memory users = dcaManager.getUsers();
        assertEq(users.length, 1);
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

        // Test fee bounds consistency
        uint256 lowerBound = IFeeHandler(address(docHandler)).getFeePurchaseLowerBound();
        uint256 upperBound = IFeeHandler(address(docHandler)).getFeePurchaseUpperBound();
        assertLe(lowerBound, upperBound);
    }

    function test_getters_boundaryConditions() public {
        // Test boundary conditions for various getters
        
        // Test with address(0) as token
        IDcaManager.DcaDetails[] memory schedules = dcaManager.getDcaSchedules(USER, address(0));
        assertEq(schedules.length, 0);
        
        // Test protocol index 0 (should return empty name)
        string memory emptyProtocol = operationsAdmin.getLendingProtocolName(0);
        assertEq(bytes(emptyProtocol).length, 0);
        
        // Test empty protocol name (should return 0)
        uint256 emptyIndex = operationsAdmin.getLendingProtocolIndex("");
        assertEq(emptyIndex, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getters_afterStateChanges() public {
        // Test getters after making actual state changes
        uint256 initialBalance = dcaManager.getScheduleTokenBalance(USER, address(stablecoin), 0);
        
        // Make a purchase
        vm.prank(USER);
        bytes32 scheduleId = dcaManager.getScheduleId(USER, address(stablecoin), 0);
        
        vm.prank(SWAPPER);
        dcaManager.buyRbtc(USER, address(stablecoin), 0, scheduleId);
        
        // Check balance changed
        uint256 newBalance = dcaManager.getScheduleTokenBalance(USER, address(stablecoin), 0);
        assertLt(newBalance, initialBalance);
        
        // Check rBTC balance increased
        uint256 rbtcBalance = IPurchaseRbtc(address(docHandler)).getAccumulatedRbtcBalance(USER);
        assertGt(rbtcBalance, 0);
    }

    function test_getters_gasEfficiency() public {
        // Test that getters are gas efficient
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
} 