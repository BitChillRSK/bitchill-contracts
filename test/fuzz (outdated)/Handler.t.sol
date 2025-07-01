// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {OperationsAdmin} from "../../src/OperationsAdmin.sol";
import {MockStablecoin} from "../mocks/MockStablecoin.sol";
import "../../script/Constants.sol";

/**
 * @title Handler
 * @notice Handler contract for invariant testing
 * @dev Provides controlled randomized actions for invariant testing
 */
contract Handler is Test {
    /*//////////////////////////////////////////////////////////////
                            CONTRACTS
    //////////////////////////////////////////////////////////////*/
    
    DcaManager public dcaManager;
    OperationsAdmin public operationsAdmin;
    ITokenHandler public tokenHandler;
    MockStablecoin public stablecoin;
    
    // Test role addresses (should match the invariant test setup)
    address public constant SWAPPER = address(0x3333);
    
    /*//////////////////////////////////////////////////////////////
                            TEST STATE
    //////////////////////////////////////////////////////////////*/
    
    address[] public s_users;
    
    // Very conservative bounds to prevent overflow
    uint256 constant MAX_DEPOSIT_AMOUNT = 2000 ether; // Reduced to 2k ether for safety
    uint256 constant MIN_DEPOSIT_AMOUNT = MIN_PURCHASE_AMOUNT * 2; // At least 2x purchase amount
    uint256 constant MAX_SCHEDULE_BALANCE = 6_000 ether; // Deposit cap per schedule (matches invariant)
    uint256 constant MAX_USER_BALANCE     = 200_000 ether; // Per-user stablecoin mint cap
    uint256 constant MAX_PURCHASE_PERIOD = 52 weeks; // Max 1 year
    uint256 constant MAX_PURCHASE_AMOUNT = 500 ether; // Reduced to 500 ether for safety
    
    // Track the number of calls for debugging
    uint256 public depositCalls;
    uint256 public withdrawCalls;
    uint256 public createScheduleCalls;
    uint256 public updateScheduleCalls;
    uint256 public buyRbtcCalls;
    
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    
    constructor(
        DcaManager _dcaManager,
        OperationsAdmin _operationsAdmin,
        ITokenHandler _tokenHandler,
        MockStablecoin _stablecoin,
        address[] memory _users
    ) {
        dcaManager = _dcaManager;
        operationsAdmin = _operationsAdmin;
        tokenHandler = _tokenHandler;
        stablecoin = _stablecoin;
        s_users = _users;
    }
    
    /*//////////////////////////////////////////////////////////////
                            HANDLER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Create a new DCA schedule for a random user
     */
    function createDcaSchedule(
        uint256 userSeed,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    ) external {
        createScheduleCalls++;
        
        address user = s_users[userSeed % s_users.length];
        
        // Bound parameters to reasonable ranges - prevent extreme values
        depositAmount = bound(depositAmount, MIN_DEPOSIT_AMOUNT, MAX_DEPOSIT_AMOUNT);
        
        // Additional safety check to ensure depositAmount is never 0
        if (depositAmount == 0) {
            depositAmount = MIN_DEPOSIT_AMOUNT;
        }
        
        // Calculate max purchase amount ensuring it's at least MIN_PURCHASE_AMOUNT
        uint256 maxPurchaseFromDeposit = depositAmount / 3;
        uint256 maxPurchaseAmount = max(maxPurchaseFromDeposit, MIN_PURCHASE_AMOUNT); // Ensure we don't go below minimum
        maxPurchaseAmount = min(maxPurchaseAmount, MAX_PURCHASE_AMOUNT); // Cap at maximum
        
        purchaseAmount = bound(purchaseAmount, MIN_PURCHASE_AMOUNT, maxPurchaseAmount);
        
        // Additional safety check for purchase amount
        if (purchaseAmount == 0 || purchaseAmount < MIN_PURCHASE_AMOUNT) {
            purchaseAmount = MIN_PURCHASE_AMOUNT;
        }
        
        purchasePeriod = bound(purchasePeriod, MIN_PURCHASE_PERIOD, MAX_PURCHASE_PERIOD);
        
        // Additional safety check for purchase period
        if (purchasePeriod == 0 || purchasePeriod < MIN_PURCHASE_PERIOD) {
            purchasePeriod = MIN_PURCHASE_PERIOD;
        }
        
        // Final validation before proceeding
        if (depositAmount < MIN_DEPOSIT_AMOUNT || 
            purchaseAmount < MIN_PURCHASE_AMOUNT || 
            purchasePeriod < MIN_PURCHASE_PERIOD ||
            purchaseAmount > depositAmount / 2) { // Purchase amount shouldn't be more than half of deposit
            return; // Skip if parameters are still invalid
        }
        
        // Check user's current balance and limit minting to prevent excessive accumulation
        uint256 userBalance = stablecoin.balanceOf(user);
        uint256 maxUserBalance = MAX_USER_BALANCE;
        
        if (userBalance >= maxUserBalance) {
            vm.stopPrank();
            return; // Skip if user already has too much
        }
        
        if (userBalance < depositAmount) {
            // Only mint up to the max user balance
            uint256 amountToMint = min(depositAmount, maxUserBalance - userBalance);
            if (amountToMint > 0) {
                stablecoin.mint(user, amountToMint);
            } else {
                vm.stopPrank();
                return;
            }
        }
        
        vm.startPrank(user);
        stablecoin.approve(address(tokenHandler), depositAmount);
        
        try dcaManager.createDcaSchedule(
            address(stablecoin),
            depositAmount,
            purchaseAmount,
            purchasePeriod,
            TROPYKUS_INDEX
        ) {
            // Success
        } catch {
            // Ignore failures (might be due to max schedules reached, etc.)
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Deposit additional tokens to an existing schedule
     */
    function depositToken(
        uint256 userSeed,
        uint256 scheduleIndex,
        uint256 depositAmount
    ) external {
        depositCalls++;
        
        address user = s_users[userSeed % s_users.length];
        
        // Bound deposit amount to very small ranges to prevent runaway growth
        depositAmount = bound(depositAmount, MIN_PURCHASE_AMOUNT, MAX_DEPOSIT_AMOUNT / 4); // Max 500 ether per deposit
        
        // Additional safety check to ensure depositAmount is never 0
        if (depositAmount == 0 || depositAmount < MIN_PURCHASE_AMOUNT) {
            depositAmount = MIN_PURCHASE_AMOUNT;
        }
        
        vm.startPrank(user);
        
        // Check if user has any schedules
        IDcaManager.DcaDetails[] memory schedules;
        try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory _schedules) {
            schedules = _schedules;
        } catch {
            vm.stopPrank();
            return;
        }
        
        if (schedules.length == 0) {
            vm.stopPrank();
            return;
        }
        
        scheduleIndex = bound(scheduleIndex, 0, schedules.length - 1);
        
        // Check current schedule balance and prevent excessive accumulation
        uint256 currentBalance = schedules[scheduleIndex].tokenBalance;
        uint256 maxScheduleBalance = MAX_SCHEDULE_BALANCE;
        
        if (currentBalance >= maxScheduleBalance) {
            vm.stopPrank();
            return; // Skip if schedule already has too much
        }
        
        // Cap deposit amount to not exceed max schedule balance
        if (currentBalance + depositAmount > maxScheduleBalance) {
            depositAmount = maxScheduleBalance - currentBalance;
        }
        
        // Final check - skip if resulting deposit would be too small
        if (depositAmount < MIN_PURCHASE_AMOUNT) {
            vm.stopPrank();
            return;
        }
        
        // Check user's current balance and limit minting to prevent excessive accumulation
        uint256 userBalance = stablecoin.balanceOf(user);
        uint256 maxUserBalance = MAX_USER_BALANCE;
        
        if (userBalance >= maxUserBalance) {
            vm.stopPrank();
            return; // Skip if user already has too much
        }
        
        if (userBalance < depositAmount) {
            // Only mint up to the max user balance
            uint256 amountToMint = min(depositAmount, maxUserBalance - userBalance);
            if (amountToMint > 0) {
                stablecoin.mint(user, amountToMint);
            } else {
                vm.stopPrank();
                return;
            }
        }
        
        stablecoin.approve(address(tokenHandler), depositAmount);
        
        try dcaManager.depositToken(address(stablecoin), scheduleIndex, depositAmount) {
            // Success
        } catch {
            // Ignore failures
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Withdraw tokens from an existing schedule
     */
    function withdrawToken(
        uint256 userSeed,
        uint256 scheduleIndex,
        uint256 withdrawalAmount
    ) external {
        withdrawCalls++;
        
        address user = s_users[userSeed % s_users.length];
        
        vm.startPrank(user);
        
        // Check if user has any schedules
        IDcaManager.DcaDetails[] memory schedules;
        try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory _schedules) {
            schedules = _schedules;
        } catch {
            vm.stopPrank();
            return;
        }
        
        if (schedules.length == 0) {
            vm.stopPrank();
            return;
        }
        
        scheduleIndex = bound(scheduleIndex, 0, schedules.length - 1);
        
        // Get current balance and bound withdrawal to it
        uint256 currentBalance = schedules[scheduleIndex].tokenBalance;
        if (currentBalance == 0) {
            vm.stopPrank();
            return;
        }
        
        withdrawalAmount = bound(withdrawalAmount, 1, currentBalance);
        
        try dcaManager.withdrawToken(address(stablecoin), scheduleIndex, withdrawalAmount) {
            // Success
        } catch {
            // Ignore failures
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Update an existing DCA schedule
     */
    function updateDcaSchedule(
        uint256 userSeed,
        uint256 scheduleIndex,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    ) external {
        updateScheduleCalls++;
        
        address user = s_users[userSeed % s_users.length];
        
        vm.startPrank(user);
        
        // Check if user has any schedules
        IDcaManager.DcaDetails[] memory schedules;
        try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory _schedules) {
            schedules = _schedules;
        } catch {
            vm.stopPrank();
            return;
        }
        
        if (schedules.length == 0) {
            vm.stopPrank();
            return;
        }
        
        scheduleIndex = bound(scheduleIndex, 0, schedules.length - 1);
        
        // Bound parameters to reasonable ranges with more conservative bounds for updates
        if (depositAmount > 0) {
            depositAmount = bound(depositAmount, MIN_PURCHASE_AMOUNT, MAX_DEPOSIT_AMOUNT);
            if (depositAmount < MIN_PURCHASE_AMOUNT) {
                depositAmount = 0; // Skip additional deposit
            }
        } else {
            depositAmount = 0; // 50% chance of no additional deposit based on original logic
        }
        
        if (purchaseAmount > 0) {
            purchaseAmount = bound(purchaseAmount, MIN_PURCHASE_AMOUNT, MAX_PURCHASE_AMOUNT);
            if (purchaseAmount < MIN_PURCHASE_AMOUNT) {
                purchaseAmount = 0; // Skip purchase amount update
            }
        } else {
            purchaseAmount = 0; // 50% chance of no purchase amount update based on original logic
        }
        
        if (purchasePeriod > 0) {
            purchasePeriod = bound(purchasePeriod, MIN_PURCHASE_PERIOD, MAX_PURCHASE_PERIOD);
            if (purchasePeriod < MIN_PURCHASE_PERIOD) {
                purchasePeriod = 0; // Skip period update
            }
        } else {
            purchasePeriod = 0; // 50% chance of no period update based on original logic
        }
        
        // Check current schedule balance and cap additional deposit to avoid exceeding reasonable limits
        uint256 currentBalance = schedules[scheduleIndex].tokenBalance;
        uint256 maxScheduleBalance = MAX_SCHEDULE_BALANCE;

        // If schedule already at or above cap, skip any deposit
        if (currentBalance >= maxScheduleBalance) {
            depositAmount = 0;
        } else if (depositAmount > 0 && currentBalance + depositAmount > maxScheduleBalance) {
            // Reduce deposit so final balance equals cap
            depositAmount = maxScheduleBalance - currentBalance;
        }

        // After adjustment, if deposit becomes too small, skip it
        if (depositAmount > 0 && depositAmount < MIN_PURCHASE_AMOUNT) {
            depositAmount = 0;
        }

        // Ensure user has enough tokens for additional deposit
        if (depositAmount > 0) {
            uint256 userBalance = stablecoin.balanceOf(user);
            uint256 maxUserBalance = MAX_USER_BALANCE;

            if (userBalance >= maxUserBalance) {
                depositAmount = 0; // Skip additional deposit if user already has too much
            } else if (userBalance < depositAmount) {
                // Only mint up to the max user balance
                uint256 amountToMint = min(depositAmount, maxUserBalance - userBalance);
                if (amountToMint > 0) {
                    stablecoin.mint(user, amountToMint);
                } else {
                    depositAmount = 0; // Skip if can't mint enough
                }
            }

            if (depositAmount > 0) {
                stablecoin.approve(address(tokenHandler), depositAmount);
            }
        }
        
        try dcaManager.updateDcaSchedule(
            address(stablecoin),
            scheduleIndex,
            depositAmount,
            purchaseAmount,
            purchasePeriod
        ) {
            // Success
        } catch {
            // Ignore failures
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Delete a DCA schedule
     */
    function deleteDcaSchedule(
        uint256 userSeed,
        uint256 scheduleIndex
    ) external {
        address user = s_users[userSeed % s_users.length];
        
        vm.startPrank(user);
        
        // Check if user has any schedules
        IDcaManager.DcaDetails[] memory schedules;
        try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory _schedules) {
            schedules = _schedules;
        } catch {
            vm.stopPrank();
            return;
        }
        
        if (schedules.length == 0) {
            vm.stopPrank();
            return;
        }
        
        scheduleIndex = bound(scheduleIndex, 0, schedules.length - 1);
        
        try dcaManager.deleteDcaSchedule(address(stablecoin), schedules[scheduleIndex].scheduleId) {
            // Success
        } catch {
            // Ignore failures
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Simulate buying rBTC for a user (mock implementation)
     */
    function buyRbtc(
        uint256 userSeed,
        uint256 scheduleIndex
    ) external {
        buyRbtcCalls++;
        
        address user = s_users[userSeed % s_users.length];
        
        // Check if user has any schedules
        IDcaManager.DcaDetails[] memory schedules;
        try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory _schedules) {
            schedules = _schedules;
        } catch {
            return;
        }
        
        if (schedules.length == 0) {
            return;
        }
        
        scheduleIndex = bound(scheduleIndex, 0, schedules.length - 1);
        
        // Check if purchase is due (time-based) and user has sufficient balance
        IDcaManager.DcaDetails memory schedule = schedules[scheduleIndex];
        if (schedule.tokenBalance < schedule.purchaseAmount) {
            return; // Not enough balance
        }
        
        if (block.timestamp < schedule.lastPurchaseTimestamp + schedule.purchasePeriod) {
            return; // Too early for next purchase
        }
        
        // Simulate the swapper role making the purchase using DcaManager's buyRbtc
        vm.startPrank(SWAPPER);
        
        try dcaManager.buyRbtc(user, address(stablecoin), scheduleIndex, schedule.scheduleId) {
            // Success
        } catch {
            // Ignore failures
        }
        
        vm.stopPrank();
    }
    
    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
    
    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function getCallCounts() external view returns (
        uint256 deposits,
        uint256 withdrawals,
        uint256 creates,
        uint256 updates,
        uint256 buys
    ) {
        return (depositCalls, withdrawCalls, createScheduleCalls, updateScheduleCalls, buyRbtcCalls);
    }
}
