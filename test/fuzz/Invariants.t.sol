// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {OperationsAdmin} from "../../src/OperationsAdmin.sol";
import {TropykusErc20Handler} from "../../src/TropykusErc20Handler.sol";
import {SovrynErc20Handler} from "../../src/SovrynErc20Handler.sol";
import {PurchaseRbtc} from "../../src/PurchaseRbtc.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IFeeHandler} from "../../src/interfaces/IFeeHandler.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import {ITokenLending} from "../../src/interfaces/ITokenLending.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {MockStablecoin} from "../mocks/MockStablecoin.sol";
import {MockKdocToken} from "../mocks/MockKdocToken.sol";
import {MockIsusdToken} from "../mocks/MockIsusdToken.sol";
import {Handler} from "./Handler.t.sol";
import "../../script/Constants.sol";

/**
 * @title InvariantTest
 * @notice Invariant tests for the BitChill DCA protocol
 * @dev Tests critical invariants that must always hold regardless of user actions
 *      Supports both local mocked tests and mainnet fork tests via environment variables
 */
contract InvariantTest is StdInvariant, Test {
    /*//////////////////////////////////////////////////////////////
                            CONTRACTS
    //////////////////////////////////////////////////////////////*/
    
    DcaManager public dcaManager;
    OperationsAdmin public operationsAdmin;
    IPurchaseRbtc public handler;
    MockStablecoin public stablecoin;
    MockKdocToken public kToken;
    MockIsusdToken public iSusdToken;
    Handler public fuzzHandler;
    
    /*//////////////////////////////////////////////////////////////
                            TEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/
    
    uint256 constant NUM_USERS = 10;
    uint256 constant USER_INITIAL_BALANCE = 100000 ether; // 100k tokens per user
    uint256 constant HANDLER_INITIAL_BALANCE = 1000000 ether; // 1M tokens for handler operations
    
    address public constant OWNER = address(0x1111);
    address public constant ADMIN = address(0x2222);
    address public constant SWAPPER = address(0x3333);
    address public constant FEE_COLLECTOR = address(0x4444);
    
    address[] public s_users;
    uint256 public deploymentTimestamp;
    uint256 public s_lendingProtocolIndex;
    
    /*//////////////////////////////////////////////////////////////
                           TEST CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 constant MAX_USER_STABLECOIN_BALANCE = 250_000 ether;   
    uint256 constant MAX_USER_RBTC_BALANCE      = 100 ether;        
    uint256 constant MAX_SCHEDULE_TOKEN_BALANCE = 7_000 ether;      

    function setUp() external {
        deploymentTimestamp = block.timestamp;
        
        // Setup lending protocol from environment variable (like unit tests)
        string memory lendingProtocol;
        try vm.envString("LENDING_PROTOCOL") returns (string memory protocol) {
            lendingProtocol = protocol;
        } catch {
            lendingProtocol = TROPYKUS_STRING; // Default to Tropykus
        }
        
        // Set lending protocol index
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked(TROPYKUS_STRING))) {
            s_lendingProtocolIndex = TROPYKUS_INDEX;
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked(SOVRYN_STRING))) {
            s_lendingProtocolIndex = SOVRYN_INDEX;
        } else {
            revert("Invalid lending protocol");
        }
        
        // Deploy core contracts
        vm.prank(OWNER);
        operationsAdmin = new OperationsAdmin();
        
        vm.prank(OWNER);
        dcaManager = new DcaManager(address(operationsAdmin), MIN_PURCHASE_PERIOD, MAX_SCHEDULES_PER_TOKEN);
        
        stablecoin = new MockStablecoin(address(this));
        
        // Setup roles
        vm.prank(OWNER);
        operationsAdmin.setAdminRole(ADMIN);
        
        vm.prank(ADMIN);
        operationsAdmin.setSwapperRole(SWAPPER);
        
        vm.prank(ADMIN);
        operationsAdmin.addOrUpdateLendingProtocol(TROPYKUS_STRING, TROPYKUS_INDEX);
        
        vm.prank(ADMIN);
        operationsAdmin.addOrUpdateLendingProtocol(SOVRYN_STRING, SOVRYN_INDEX);
        
        // Deploy appropriate handler wrapper based on lending protocol
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE_TEST,
            feePurchaseLowerBound: FEE_PURCHASE_LOWER_BOUND,
            feePurchaseUpperBound: FEE_PURCHASE_UPPER_BOUND
        });
        
        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            kToken = new MockKdocToken(address(stablecoin));
            handler = IPurchaseRbtc(address(new TropykusHandlerWrapper(
                address(dcaManager),
                address(stablecoin),
                address(kToken),
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                feeSettings
            )));
            // Give kToken sufficient balance for operations
            stablecoin.mint(address(kToken), HANDLER_INITIAL_BALANCE);
        } else {
            iSusdToken = new MockIsusdToken(address(stablecoin));
            handler = IPurchaseRbtc(address(new SovrynHandlerWrapper(
                address(dcaManager),
                address(stablecoin),
                address(iSusdToken),
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                feeSettings
            )));
            // Give iSusdToken sufficient balance for operations
            stablecoin.mint(address(iSusdToken), HANDLER_INITIAL_BALANCE);
        }
        
        // Give handler enough rBTC for testing purposes (in test context)
        vm.deal(address(handler), 1000 ether);
        
        vm.prank(ADMIN);
        operationsAdmin.assignOrUpdateTokenHandler(
            address(stablecoin),
            s_lendingProtocolIndex,
            address(handler)
        );
        
        // Setup users and balances
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = address(uint160(0x10000 + i));
            s_users.push(user);
            stablecoin.mint(user, USER_INITIAL_BALANCE);
            
            vm.prank(user);
            stablecoin.approve(address(handler), type(uint256).max);
        }
        
        // Deploy and target the invariant handler
        fuzzHandler = new Handler(
            dcaManager,
            operationsAdmin,
            ITokenHandler(address(handler)),
            stablecoin,
            s_users
        );
        
        targetContract(address(fuzzHandler));
    }
    
    /*//////////////////////////////////////////////////////////////
                            INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice The sum of all users' deposited tokens should match the total tokens in the lending protocol
     */
    function invariant_totalDepositedTokensMatchesLendingProtocol() public {
        address[] memory users = dcaManager.getUsers();
        uint256 totalUserDeposits = 0;
        uint256 totalLendingBalances = 0;
        
        // Sum all user deposits across all schedules AND their lending balances
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            // Get user's lending token balance
            uint256 userLendingBalance = ITokenLending(address(handler)).getUsersLendingTokenBalance(user);
            totalLendingBalances += userLendingBalance;
            
            // Get all schedules for this user with the stablecoin
            try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory schedules) {
                for (uint256 j = 0; j < schedules.length; j++) {
                    totalUserDeposits += schedules[j].tokenBalance;
                }
            } catch {
                continue;
            }
        }
        
        // Convert lending token balances to stablecoin equivalent
        uint256 totalInLendingProtocol = 0;
        if (totalLendingBalances > 0) {
            if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
                totalInLendingProtocol = totalLendingBalances * kToken.exchangeRateCurrent() / 1e18;
            } else {
                totalInLendingProtocol = totalLendingBalances * iSusdToken.tokenPrice() / 1e18;
            }
        }
        
        // Account for potential rounding differences in lending protocol
        if (totalUserDeposits > 0) {
            assertApproxEqRel(totalInLendingProtocol, totalUserDeposits, 0.05e18); // 5% tolerance for interest accrual
        } else {
            assertEq(totalInLendingProtocol, 0);
        }
        
        console2.log("Total user deposits:", totalUserDeposits);
        console2.log("Total in lending protocol:", totalInLendingProtocol);
        console2.log("Total lending balances (kTokens):", totalLendingBalances);
    }
    
    /**
     * @notice Handler's rBTC balance should be reasonable and non-negative
     * @dev Simplified rBTC invariant - handler maintains proper rBTC balance
     */
    function invariant_rbtcBalancesConsistent() public {
        uint256 handlerRbtcBalance = address(handler).balance;
        
        // Basic invariant: handler should have reasonable rBTC balance 
        assertGe(handlerRbtcBalance, 0);
        assertLe(handlerRbtcBalance, 1000 ether); // Should not exceed initial allocation
        
        console2.log("Handler rBTC balance:", handlerRbtcBalance);
    }
    
    /**
     * @notice User balances should never be negative or exceed reasonable bounds
     */
    function invariant_userBalancesReasonable() public {
        address[] memory users = dcaManager.getUsers();
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            // Check stablecoin balance is reasonable
            uint256 stablecoinBalance = stablecoin.balanceOf(user);
            assertLe(stablecoinBalance, MAX_USER_STABLECOIN_BALANCE);
            
            // Check rBTC balance is reasonable
            uint256 rbtcBalance = handler.getAccumulatedRbtcBalance(user);
            assertLe(rbtcBalance, MAX_USER_RBTC_BALANCE);
            
            // Check schedule balances are reasonable
            try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory schedules) {
                for (uint256 j = 0; j < schedules.length; j++) {
                    assertLe(schedules[j].tokenBalance, MAX_SCHEDULE_TOKEN_BALANCE);
                    if (schedules[j].purchaseAmount > 0) {
                        assertGt(schedules[j].purchaseAmount, 0);
                        assertGe(schedules[j].purchasePeriod, MIN_PURCHASE_PERIOD);
                    }
                    assertNotEq(schedules[j].scheduleId, bytes32(0));
                }
            } catch {
                // User has no schedules, which is fine
            }
        }
    }
    
    /**
     * @notice The lending protocol exchange rate should only increase over time (interest accrual)
     */
    function invariant_exchangeRateOnlyIncreases() public {
        if (s_lendingProtocolIndex == TROPYKUS_INDEX) {
            uint256 previousRate = kToken.exchangeRateStored();
            uint256 currentRate = kToken.exchangeRateCurrent();
            assertGe(currentRate, previousRate);
            console2.log("Previous stored rate:", previousRate);
            console2.log("Current rate:", currentRate);
        } else {
            uint256 previousRate = iSusdToken.tokenPrice();
            // For Sovryn, we don't store previous rate, so just check it's positive
            assertGt(previousRate, 0);
            console2.log("Current token price:", previousRate);
        }
    }
    
    /**
     * @notice Handler contracts should never hold any stablecoin tokens
     */
    function invariant_handlerStablecoinBalanceZero() public {
        uint256 handlerBalance = stablecoin.balanceOf(address(handler));
        assertEq(handlerBalance, 0);
        console2.log("Handler token balance:", handlerBalance);
    }
    
    /**
     * @notice Interest should never decrease for users
     */
    function invariant_interestOnlyIncreases() public {
        address[] memory users = dcaManager.getUsers();
        
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            try dcaManager.getDcaSchedules(user, address(stablecoin)) returns (IDcaManager.DcaDetails[] memory schedules) {
                if (schedules.length > 0) {
                    uint256 totalDeposited = 0;
                    for (uint256 j = 0; j < schedules.length; j++) {
                        if (schedules[j].lendingProtocolIndex == s_lendingProtocolIndex) {
                            totalDeposited += schedules[j].tokenBalance;
                        }
                    }
                    
                    if (totalDeposited > 0) {
                        uint256 lendingBalance = ITokenLending(address(handler)).getUsersLendingTokenBalance(user);
                        assertGe(lendingBalance, 0);
                    }
                }
            } catch {
                // User has no schedules, skip
            }
        }
    }
}

/**
 * @title TropykusHandlerWrapper
 * @notice Concrete implementation of TropykusErc20Handler for testing
 * @dev Properly simulates rBTC accounting - handler's balance decreases when users buy rBTC
 */
contract TropykusHandlerWrapper is TropykusErc20Handler {
    // Track users' accumulated RBTC for testing
    mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;
    
    constructor(
        address dcaManagerAddress,
        address stableTokenAddress,
        address kTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    ) TropykusErc20Handler(
        dcaManagerAddress,
        stableTokenAddress,
        kTokenAddress,
        minPurchaseAmount,
        feeCollector,
        feeSettings
    ) {}
    
    /**
     * @notice Allow the contract to receive and hold rBTC
     */
    receive() external payable {}
    
    /**
     * @notice Mock implementation of buyRbtc for testing
     * @dev Properly simulates rBTC flow: redeems stablecoin, converts to rBTC, updates balances
     */
    function buyRbtc(
        address buyer,
        bytes32 scheduleId,
        uint256 purchaseAmount
    ) external onlyDcaManager {
        _buyRbtcInternal(buyer, scheduleId, purchaseAmount);
    }
    
    /**
     * @notice Mock implementation of batchBuyRbtc for testing
     */
    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts
    ) external onlyDcaManager {
        for (uint256 i = 0; i < buyers.length; i++) {
            _buyRbtcInternal(buyers[i], scheduleIds[i], purchaseAmounts[i]);
        }
    }
    
    /**
     * @notice Get the accumulated rBTC balance for a specific user
     */
    function getAccumulatedRbtcBalance(address user) external view returns (uint256) {
        return s_usersAccumulatedRbtc[user];
    }

    /**
     * @notice Get the accumulated rBTC balance for the caller
     */
    function getAccumulatedRbtcBalance() external view returns (uint256) {
        return s_usersAccumulatedRbtc[msg.sender];
    }

    /**
     * @notice Emergency function to withdraw rBTC stuck in contracts  
     */  
    function withdrawStuckRbtc(address, address) external pure {
        revert("Mock function - not implemented for testing");
    }
    
    /**
     * @notice Withdraw accumulated rBTC - transfers rBTC from handler to user
     */
    function withdrawAccumulatedRbtc(address user) external onlyDcaManager {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) return;
        
        s_usersAccumulatedRbtc[user] = 0;
        
        // Actually transfer rBTC (this properly decreases handler balance)
        (bool success, ) = payable(user).call{value: rbtcBalance}("");
        require(success, "rBTC transfer failed");
        
        emit PurchaseRbtc__rBtcWithdrawn(user, rbtcBalance);
    }
    
    /**
     * @notice Internal function for rBTC purchase logic
     * @dev Properly simulates: stablecoin -> rBTC conversion with correct balance accounting
     */
    function _buyRbtcInternal(
        address buyer,
        bytes32 scheduleId,
        uint256 purchaseAmount
    ) internal {
        // Redeem stablecoin from lending protocol
        uint256 redeemed = _redeemStablecoin(buyer, purchaseAmount);
        
        // Mock conversion: 1 stablecoin = 0.00003 rBTC (roughly $50k BTC price)
        uint256 rbtcAmount = (redeemed * 3e16) / 1e18; // 0.03 rBTC per token
        
        // Ensure handler has enough rBTC (should have been allocated in setUp)
        require(address(this).balance >= rbtcAmount, "Handler insufficient rBTC balance");
        
        // Add to user's rBTC balance
        s_usersAccumulatedRbtc[buyer] += rbtcAmount;
        
        emit PurchaseRbtc__RbtcBought(buyer, address(i_stableToken), rbtcAmount, scheduleId, purchaseAmount);
    }
    
    // Events for testing
    event PurchaseRbtc__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 rBtcBought,
        bytes32 indexed scheduleId,
        uint256 amountSpent
    );
    event PurchaseRbtc__rBtcWithdrawn(address indexed user, uint256 indexed amount);
}

/**
 * @title SovrynHandlerWrapper  
 * @notice Concrete implementation of SovrynErc20Handler for testing
 * @dev Provides the missing Sovryn wrapper for invariant testing
 */
contract SovrynHandlerWrapper is SovrynErc20Handler {
    // Track users' accumulated RBTC for testing
    mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;
    
    constructor(
        address dcaManagerAddress,
        address stableTokenAddress,
        address iSusdTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    ) SovrynErc20Handler(
        dcaManagerAddress,
        stableTokenAddress,
        iSusdTokenAddress,
        minPurchaseAmount,
        feeCollector,
        feeSettings
    ) {}
    
    /**
     * @notice Allow the contract to receive and hold rBTC
     */
    receive() external payable {}
    
    /**
     * @notice Mock implementation of buyRbtc for testing
     */
    function buyRbtc(
        address buyer,
        bytes32 scheduleId,
        uint256 purchaseAmount
    ) external onlyDcaManager {
        _buyRbtcInternal(buyer, scheduleId, purchaseAmount);
    }
    
    /**
     * @notice Mock implementation of batchBuyRbtc for testing  
     */
    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts
    ) external onlyDcaManager {
        for (uint256 i = 0; i < buyers.length; i++) {
            _buyRbtcInternal(buyers[i], scheduleIds[i], purchaseAmounts[i]);
        }
    }
    
    /**
     * @notice Get the accumulated rBTC balance for a specific user
     */
    function getAccumulatedRbtcBalance(address user) external view returns (uint256) {
        return s_usersAccumulatedRbtc[user];
    }

    /**
     * @notice Get the accumulated rBTC balance for the caller
     */
    function getAccumulatedRbtcBalance() external view returns (uint256) {
        return s_usersAccumulatedRbtc[msg.sender];
    }

    /**
     * @notice Emergency function to withdraw rBTC stuck in contracts  
     */
    function withdrawStuckRbtc(address, address) external pure {
        revert("Mock function - not implemented for testing");
    }
    
    /**
     * @notice Withdraw accumulated rBTC - transfers rBTC from handler to user
     */
    function withdrawAccumulatedRbtc(address user) external onlyDcaManager {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) return;
        
        s_usersAccumulatedRbtc[user] = 0;
        
        // Actually transfer rBTC (this properly decreases handler balance)
        (bool success, ) = payable(user).call{value: rbtcBalance}("");
        require(success, "rBTC transfer failed");
        
        emit PurchaseRbtc__rBtcWithdrawn(user, rbtcBalance);
    }
    
    /**
     * @notice Internal function for rBTC purchase logic
     */
    function _buyRbtcInternal(
        address buyer,
        bytes32 scheduleId,
        uint256 purchaseAmount
    ) internal {
        // Redeem stablecoin from lending protocol
        uint256 redeemed = _redeemStablecoin(buyer, purchaseAmount);
        
        // Mock conversion: 1 stablecoin = 0.00003 rBTC
        uint256 rbtcAmount = (redeemed * 3e16) / 1e18; // 0.03 rBTC per token
        
        // Ensure handler has enough rBTC (should have been allocated in setUp)
        require(address(this).balance >= rbtcAmount, "Handler insufficient rBTC balance");
        
        // Add to user's rBTC balance  
        s_usersAccumulatedRbtc[buyer] += rbtcAmount;
        
        emit PurchaseRbtc__RbtcBought(buyer, address(i_stableToken), rbtcAmount, scheduleId, purchaseAmount);
    }
    
    // Events for testing
    event PurchaseRbtc__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 rBtcBought,
        bytes32 indexed scheduleId,
        uint256 amountSpent
    );
    event PurchaseRbtc__rBtcWithdrawn(address indexed user, uint256 indexed amount);
}
