// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title BitChillMini
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @notice Simplified version of BitChill for educational purposes
 * @dev This contract demonstrates the core functionality of BitChill:
 *      - Deposit DOC tokens
 *      - Lend them on Tropykus (kDOC)
 *      - Purchase rBTC by redeeming from Money on Chain
 *      - Withdraw accumulated rBTC
 */
contract BitChillMini is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////

    /// @notice DOC token contract
    IERC20 public immutable i_docToken;
    
    /// @notice kDOC token contract (Tropykus lending token)
    IkToken public immutable i_kDocToken;
    
    /// @notice Money on Chain proxy contract
    IMocProxy public immutable i_mocProxy;
    
    /// @notice Fee collector address
    address public immutable i_feeCollector;
    
    /// @notice Flat fee rate in basis points (100 = 1%)
    uint256 public constant FEE_RATE_BPS = 100; // 1%
    uint256 public constant FEE_PERCENTAGE_DIVISOR = 10_000;
    
    /// @notice Exchange rate decimals for kDOC (1e18)
    uint256 public constant EXCHANGE_RATE_DECIMALS = 1e18;
    
    /// @notice User's kDOC balance tracking
    mapping(address user => uint256 balance) public s_userKDocBalances;
    
    /// @notice User's accumulated rBTC from purchases
    mapping(address user => uint256 amount) public s_userAccumulatedRbtc;

    //////////////////////
    // Events ////////////
    //////////////////////

    event BitChillMini__DocDeposited(address indexed user, uint256 indexed amount);
    event BitChillMini__DocWithdrawn(address indexed user, uint256 indexed amount);
    event BitChillMini__RbtcBought(address indexed user, uint256 indexed docSpent, uint256 indexed rbtcReceived);
    event BitChillMini__RbtcWithdrawn(address indexed user, uint256 indexed amount);
    event BitChillMini__InterestWithdrawn(address indexed user, uint256 indexed amount);

    //////////////////////
    // Custom errors /////
    //////////////////////

    error BitChillMini__AmountMustBeGreaterThanZero();
    error BitChillMini__InsufficientBalance();
    error BitChillMini__InsufficientAllowance();
    error BitChillMini__NoAccumulatedRbtcToWithdraw();
    error BitChillMini__RbtcWithdrawalFailed();
    error BitChillMini__LendingDepositFailed();
    error BitChillMini__LendingRedeemFailed();
    error BitChillMini__MocRedeemRequestFailed();
    error BitChillMini__MocRedeemFreeFailed();
    error BitChillMini__NoInterestToWithdraw();

    //////////////////////
    // Constructor ///////
    //////////////////////

    /**
     * @param docTokenAddress Address of the DOC token
     * @param kDocTokenAddress Address of the kDOC token (Tropykus)
     * @param mocProxyAddress Address of the MoC proxy
     * @param feeCollectorAddress Address to receive fees
     */
    constructor(
        address docTokenAddress,
        address kDocTokenAddress,
        address mocProxyAddress,
        address feeCollectorAddress
    ) Ownable() {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkToken(kDocTokenAddress);
        i_mocProxy = IMocProxy(mocProxyAddress);
        i_feeCollector = feeCollectorAddress;
    }

    //////////////////////
    // External functions
    //////////////////////

    /**
     * @notice Allow the contract to receive rBTC
     */
    receive() external payable {}

    /**
     * @notice Deposit DOC tokens and lend them on Tropykus
     * @param amount Amount of DOC to deposit
     */
    function depositDoc(uint256 amount) external nonReentrant {
        if (amount == 0) revert BitChillMini__AmountMustBeGreaterThanZero();
        
        // Transfer DOC from user to contract
        i_docToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Approve kDOC contract to spend DOC
        if (i_docToken.allowance(address(this), address(i_kDocToken)) < amount) {
            i_docToken.safeApprove(address(i_kDocToken), amount);
        }
        
        // Mint kDOC tokens (lend on Tropykus)
        uint256 prevKDocBalance = i_kDocToken.balanceOf(address(this));
        uint256 result = i_kDocToken.mint(amount);
        if (result != 0) revert BitChillMini__LendingDepositFailed();
        
        uint256 postKDocBalance = i_kDocToken.balanceOf(address(this));
        uint256 kDocReceived = postKDocBalance - prevKDocBalance;
        
        // Track user's kDOC balance
        s_userKDocBalances[msg.sender] += kDocReceived;
        
        emit BitChillMini__DocDeposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw DOC tokens by redeeming from Tropykus
     * @param amount Amount of DOC to withdraw
     */
    function withdrawDoc(uint256 amount) external nonReentrant {
        if (amount == 0) revert BitChillMini__AmountMustBeGreaterThanZero();
        
        // Get current exchange rate
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        
        // Calculate how much kDOC is needed
        uint256 kDocNeeded = _stablecoinToLendingToken(amount, exchangeRate);
        
        // Check if user has enough kDOC
        if (kDocNeeded > s_userKDocBalances[msg.sender]) {
            // Adjust amount to what's available
            amount = _lendingTokenToStablecoin(s_userKDocBalances[msg.sender], exchangeRate);
            kDocNeeded = s_userKDocBalances[msg.sender];
        }
        
        // Redeem kDOC for underlying DOC
        uint256 result = i_kDocToken.redeemUnderlying(amount);
        if (result != 0) revert BitChillMini__LendingRedeemFailed();
        
        // Update user's kDOC balance
        s_userKDocBalances[msg.sender] -= kDocNeeded;
        
        // Transfer DOC back to user
        i_docToken.safeTransfer(msg.sender, amount);
        
        emit BitChillMini__DocWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Buy rBTC by redeeming DOC from Tropykus and using MoC
     * @param docAmount Amount of DOC to spend on rBTC purchase
     */
    function buyRbtc(uint256 docAmount) external nonReentrant {
        if (docAmount == 0) revert BitChillMini__AmountMustBeGreaterThanZero();
        
        // Calculate fee (1%)
        uint256 fee = (docAmount * FEE_RATE_BPS) / FEE_PERCENTAGE_DIVISOR;
        uint256 netDocAmount = docAmount - fee;
        
        // Transfer fee to collector
        if (fee > 0) {
            i_docToken.safeTransfer(i_feeCollector, fee);
        }
        
        // Redeem DOC from Tropykus first
        _redeemDocFromLending(netDocAmount);
        
        // Record rBTC balance before MoC redemption
        uint256 rbtcBalanceBefore = address(this).balance;
        
        // Redeem DOC for rBTC via MoC
        try i_mocProxy.redeemDocRequest(netDocAmount) {} catch {
            revert BitChillMini__MocRedeemRequestFailed();
        }
        
        try i_mocProxy.redeemFreeDoc(netDocAmount) {} catch {
            revert BitChillMini__MocRedeemFreeFailed();
        }
        
        // Calculate rBTC received
        uint256 rbtcBalanceAfter = address(this).balance;
        uint256 rbtcReceived = rbtcBalanceAfter - rbtcBalanceBefore;
        
        if (rbtcReceived == 0) {
            revert BitChillMini__MocRedeemFreeFailed();
        }
        
        // Track user's accumulated rBTC
        s_userAccumulatedRbtc[msg.sender] += rbtcReceived;
        
        emit BitChillMini__RbtcBought(msg.sender, netDocAmount, rbtcReceived);
    }

    /**
     * @notice Withdraw accumulated rBTC
     */
    function withdrawAccumulatedRbtc() external nonReentrant {
        uint256 rbtcAmount = s_userAccumulatedRbtc[msg.sender];
        if (rbtcAmount == 0) revert BitChillMini__NoAccumulatedRbtcToWithdraw();
        
        // Clear user's accumulated rBTC (CEI pattern)
        s_userAccumulatedRbtc[msg.sender] = 0;
        
        // Transfer rBTC to user
        (bool success,) = msg.sender.call{value: rbtcAmount}("");
        if (!success) revert BitChillMini__RbtcWithdrawalFailed();
        
        emit BitChillMini__RbtcWithdrawn(msg.sender, rbtcAmount);
    }

    /**
     * @notice Withdraw interest earned from lending (DOC above what's needed for DCA)
     * @param lockedAmount Amount of DOC locked in DCA schedules
     */
    function withdrawInterest(uint256 lockedAmount) external nonReentrant {
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        uint256 totalDocInLending = _lendingTokenToStablecoin(s_userKDocBalances[msg.sender], exchangeRate);
        
        if (totalDocInLending <= lockedAmount) {
            revert BitChillMini__NoInterestToWithdraw();
        }
        
        uint256 interestAmount = totalDocInLending - lockedAmount;
        
        // Redeem interest from lending
        _redeemDocFromLending(interestAmount);
        
        // Transfer interest to user
        i_docToken.safeTransfer(msg.sender, interestAmount);
        
        emit BitChillMini__InterestWithdrawn(msg.sender, interestAmount);
    }

    //////////////////////
    // View functions ////
    //////////////////////

    /**
     * @notice Get user's kDOC balance
     * @param user User address
     * @return kDoc balance
     */
    function getUserKDocBalance(address user) external view returns (uint256) {
        return s_userKDocBalances[user];
    }

    /**
     * @notice Get user's accumulated rBTC
     * @param user User address
     * @return rBTC amount
     */
    function getUserAccumulatedRbtc(address user) external view returns (uint256) {
        return s_userAccumulatedRbtc[user];
    }

    /**
     * @notice Get user's total DOC in lending (including interest)
     * @param user User address
     * @return Total DOC amount
     */
    function getUserTotalDocInLending(address user) external view returns (uint256) {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        return _lendingTokenToStablecoin(s_userKDocBalances[user], exchangeRate);
    }

    /**
     * @notice Get user's accrued interest
     * @param user User address
     * @param lockedAmount Amount locked in DCA
     * @return Interest amount
     */
    function getAccruedInterest(address user, uint256 lockedAmount) external view returns (uint256) {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        uint256 totalDocInLending = _lendingTokenToStablecoin(s_userKDocBalances[user], exchangeRate);
        
        return totalDocInLending > lockedAmount ? totalDocInLending - lockedAmount : 0;
    }

    //////////////////////
    // Internal functions
    //////////////////////

    /**
     * @notice Redeem DOC from lending protocol
     * @param amount Amount of DOC to redeem
     */
    function _redeemDocFromLending(uint256 amount) internal {
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        uint256 kDocNeeded = _stablecoinToLendingToken(amount, exchangeRate);
        
        // Check if we have enough kDOC
        if (kDocNeeded > s_userKDocBalances[msg.sender]) {
            // Adjust to what's available
            amount = _lendingTokenToStablecoin(s_userKDocBalances[msg.sender], exchangeRate);
            kDocNeeded = s_userKDocBalances[msg.sender];
        }
        
        // Redeem from lending protocol
        uint256 result = i_kDocToken.redeemUnderlying(amount);
        if (result != 0) revert BitChillMini__LendingRedeemFailed();
        
        // Update user's kDOC balance
        s_userKDocBalances[msg.sender] -= kDocNeeded;
    }

    /**
     * @notice Convert stablecoin amount to lending token amount
     * @param stablecoinAmount Amount of stablecoin
     * @param exchangeRate Current exchange rate
     * @return lendingTokenAmount Amount of lending token
     */
    function _stablecoinToLendingToken(uint256 stablecoinAmount, uint256 exchangeRate) 
        internal 
        pure 
        returns (uint256 lendingTokenAmount) 
    {
        lendingTokenAmount = (stablecoinAmount * EXCHANGE_RATE_DECIMALS) / exchangeRate;
    }

    /**
     * @notice Convert lending token amount to stablecoin amount
     * @param lendingTokenAmount Amount of lending token
     * @param exchangeRate Current exchange rate
     * @return stablecoinAmount Amount of stablecoin
     */
    function _lendingTokenToStablecoin(uint256 lendingTokenAmount, uint256 exchangeRate) 
        internal 
        pure 
        returns (uint256 stablecoinAmount) 
    {
        stablecoinAmount = (lendingTokenAmount * exchangeRate) / EXCHANGE_RATE_DECIMALS;
    }
}

// Minimal interfaces for the workshop
interface IkToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
}

interface IMocProxy {
    function redeemDocRequest(uint256 docAmount) external;
    function redeemFreeDoc(uint256 docAmount) external;
}
