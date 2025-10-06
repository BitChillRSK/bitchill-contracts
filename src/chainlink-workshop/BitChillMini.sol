// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Minimal interfaces for the workshop
interface IkToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
}

interface IMocProxy {
    function redeemDocRequest(uint256 docAmount) external;
    function redeemFreeDoc(uint256 docAmount) external;
}

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

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Simplified DCA schedule per user
    struct DcaDetails {
        uint256 docBalance; // DOC deposited for DCA
        uint256 purchaseAmount; // DOC to spend per period
        uint256 purchasePeriod; // seconds between purchases
        uint256 lastPurchaseTimestamp; // timestamp of latest scheduled purchase
        uint256 kdocBalance; // kDOC balance in Tropykus
        uint256 accumulatedRbtc; // accumulated rBTC from purchases
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

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
    
    /// @notice DCA schedule per user
    mapping(address user => DcaDetails) private s_schedules;
        
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event BitChillMini__DocDeposited(address indexed user, uint256 indexed amount);
    event BitChillMini__DocWithdrawn(address indexed user, uint256 indexed amount);
    event BitChillMini__RbtcBought(address indexed user, uint256 indexed docSpent, uint256 indexed rbtcReceived);
    event BitChillMini__RbtcWithdrawn(address indexed user, uint256 indexed amount);
    event BitChillMini__InterestWithdrawn(address indexed user, uint256 indexed amount);

    /*//////////////////////////////////////////////////////////////
                             CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error BitChillMini__AmountMustBeGreaterThanZero();
    error BitChillMini__InexistentSchedule();
    error BitChillMini__InsufficientBalance();
    error BitChillMini__PurchasePeriodHasNotElapsed();
    error BitChillMini__InsufficientAllowance();
    error BitChillMini__NoAccumulatedRbtcToWithdraw();
    error BitChillMini__RbtcWithdrawalFailed();
    error BitChillMini__TropykusDepositFailed();
    error BitChillMini__TropykusRedeemFailed();
    error BitChillMini__MocRedeemRequestFailed();
    error BitChillMini__MocRedeemFreeFailed();
    error BitChillMini__NoInterestToWithdraw();

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

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow the contract to receive rBTC
     */
    receive() external payable {}

    /**
     * @notice Deposit DOC tokens and lend them on Tropykus
     * @param amount Amount of DOC to deposit
     */
    function depositDoc(uint256 amount) external nonReentrant {
        _depositDoc(amount);
    }

    function _depositDoc(uint256 amount) internal {
        if ((s_schedules[msg.sender].purchasePeriod == 0)) revert BitChillMini__InexistentSchedule();
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
        if (result != 0) revert BitChillMini__TropykusDepositFailed();
        uint256 postKDocBalance = i_kDocToken.balanceOf(address(this));
        uint256 kDocReceived = postKDocBalance - prevKDocBalance;
        
        // Track user's kDOC balance
        s_schedules[msg.sender].docBalance += amount;
        s_schedules[msg.sender].kdocBalance += kDocReceived;
        
        emit BitChillMini__DocDeposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw DOC tokens by redeeming from Tropykus
     * @param amount Amount of DOC to withdraw
     */
    function withdrawDoc(uint256 amount) external nonReentrant {
        if (amount == 0) revert BitChillMini__AmountMustBeGreaterThanZero();
        DcaDetails storage sched = s_schedules[msg.sender];
        if (amount > sched.docBalance) revert BitChillMini__InsufficientBalance();
        
        // Redeem kDOC for underlying DOC
        uint256 kDocBalancePrev = i_kDocToken.balanceOf(address(this));
        uint256 result = i_kDocToken.redeemUnderlying(amount);
        uint256 kDocBurnt = kDocBalancePrev - i_kDocToken.balanceOf(address(this));
        if (result != 0) revert BitChillMini__TropykusRedeemFailed();
        
        // Update user's balances
        sched.kdocBalance -= kDocBurnt;
        sched.docBalance -= amount;
        
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
        DcaDetails storage sched = s_schedules[msg.sender];
        uint256 docAmountToSpend = sched.purchaseAmount;
        if (sched.lastPurchaseTimestamp > 0 && block.timestamp - sched.lastPurchaseTimestamp < sched.purchasePeriod) {
            revert BitChillMini__PurchasePeriodHasNotElapsed();
        }
        if (docAmountToSpend > sched.docBalance) revert BitChillMini__InsufficientBalance();

        // 1) Redeem the requested DOC from Tropykus first (require exact availability)
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        _redeemDocFromTropykus(docAmountToSpend, exchangeRate);

        // 2) Calculate and transfer fee from freshly redeemed DOC
        uint256 netdocAmountToSpend = _deductAndTransferFee(docAmountToSpend);

        // 3) Ensure MoC can pull DOC from this contract
        uint256 currentAllowance = i_docToken.allowance(address(this), address(i_mocProxy));
        if (currentAllowance < netdocAmountToSpend) {
            if (currentAllowance != 0) {
                i_docToken.safeApprove(address(i_mocProxy), 0);
            }
            i_docToken.safeApprove(address(i_mocProxy), netdocAmountToSpend);
        }

        // 4) Redeem DOC for rBTC via MoC
        uint256 rbtcBalanceBefore = address(this).balance;
        try i_mocProxy.redeemDocRequest(netdocAmountToSpend) {} catch {
            revert BitChillMini__MocRedeemRequestFailed();
        }
        try i_mocProxy.redeemFreeDoc(netdocAmountToSpend) {} catch {
            revert BitChillMini__MocRedeemFreeFailed();
        }

        // 5) Account for rBTC received
        uint256 rbtcReceived = address(this).balance - rbtcBalanceBefore;
        s_schedules[msg.sender].accumulatedRbtc += rbtcReceived;

        // Deduct DOC spent from schedule balance and advance timestamp
        sched.docBalance -= docAmountToSpend;
        sched.lastPurchaseTimestamp =
            sched.lastPurchaseTimestamp == 0 ? block.timestamp : sched.lastPurchaseTimestamp + sched.purchasePeriod;
        emit BitChillMini__RbtcBought(msg.sender, netdocAmountToSpend, rbtcReceived);
    }

    /**
     * @notice Create or update a simple DCA schedule and optionally deposit DOC
     * @param depositAmount DOC to deposit now (0 to skip deposit)
     * @param purchaseAmount DOC to spend per period
     * @param purchasePeriod seconds between scheduled buys (>= 1 day)
     */
    function createDcaSchedule(uint256 depositAmount, uint256 purchaseAmount, uint256 purchasePeriod) external nonReentrant {
        if (purchaseAmount == 0) revert BitChillMini__AmountMustBeGreaterThanZero();
        DcaDetails storage schedule = s_schedules[msg.sender];
        if (purchaseAmount > (depositAmount) / 2) revert BitChillMini__InsufficientBalance();
        schedule.purchaseAmount = purchaseAmount;
        schedule.purchasePeriod = purchasePeriod;
        _depositDoc(depositAmount);
    }

    /**
     * @notice Withdraw accumulated rBTC
     */
    function withdrawAccumulatedRbtc() external nonReentrant {
        uint256 rbtcAmount = s_schedules[msg.sender].accumulatedRbtc;
        if (rbtcAmount == 0) revert BitChillMini__NoAccumulatedRbtcToWithdraw();
        
        // Clear user's accumulated rBTC (CEI pattern)
        s_schedules[msg.sender].accumulatedRbtc = 0;
        emit BitChillMini__RbtcWithdrawn(msg.sender, rbtcAmount);
        
        // Transfer rBTC to user
        (bool success,) = msg.sender.call{value: rbtcAmount}("");
        if (!success) revert BitChillMini__RbtcWithdrawalFailed();
    }

    /**
     * @notice Withdraw interest earned from Tropykus (DOC above what's needed for DCA)
     */
    function withdrawInterest() external nonReentrant {
        uint256 exchangeRate = i_kDocToken.exchangeRateCurrent();
        uint256 totalDocInTropykus = _kdocToDoc(s_schedules[msg.sender].kdocBalance, exchangeRate);
        uint256 lockedAmount = s_schedules[msg.sender].docBalance;
        if (totalDocInTropykus <= lockedAmount) revert BitChillMini__NoInterestToWithdraw();
        uint256 interestAmount = totalDocInTropykus - lockedAmount;
        _redeemDocFromTropykus(interestAmount, exchangeRate);
        i_docToken.safeTransfer(msg.sender, interestAmount);
        emit BitChillMini__InterestWithdrawn(msg.sender, interestAmount);
    }
   
    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get user's kDOC balance
     * @param user User address
     * @return kDoc balance
     */
    function getUserKDocBalance(address user) external view returns (uint256) {
        return s_schedules[user].kdocBalance;
    }

    /**
     * @notice Get user's accumulated rBTC
     * @param user User address
     * @return rBTC amount
     */
    function getUserAccumulatedRbtc(address user) external view returns (uint256) {
        return s_schedules[user].accumulatedRbtc;
    }

    /**
     * @notice Get user's total DOC in Tropykus (including interest)
     * @param user User address
     * @return Total DOC amount
     */
    function getUserTotalDocInTropykus(address user) external view returns (uint256) {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        return _kdocToDoc(s_schedules[user].kdocBalance, exchangeRate);
    }

    /**
     * @notice Get user's accrued interest
     * @param user User address
     * @param lockedAmount Amount locked in DCA
     * @return Interest amount
     */
    function getAccruedInterest(address user, uint256 lockedAmount) external view returns (uint256) {
        uint256 exchangeRate = i_kDocToken.exchangeRateStored();
        uint256 totalDocInTropykus = _kdocToDoc(s_schedules[user].kdocBalance, exchangeRate);
        return totalDocInTropykus > lockedAmount ? totalDocInTropykus - lockedAmount : 0;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Redeem DOC from Tropykus protocol
     * @param amount Amount of DOC to redeem
     */
    function _redeemDocFromTropykus(uint256 amount, uint256 exchangeRate) internal {
        uint256 kDocNeeded = _docToKdoc(amount, exchangeRate);
        if (kDocNeeded > s_schedules[msg.sender].kdocBalance) revert BitChillMini__InsufficientBalance();
        uint256 kDocBalancePrev = i_kDocToken.balanceOf(address(this));
        uint256 result = i_kDocToken.redeemUnderlying(amount);
        if (result != 0) revert BitChillMini__TropykusRedeemFailed();
        uint256 kDocBurnt = kDocBalancePrev - i_kDocToken.balanceOf(address(this));
        s_schedules[msg.sender].kdocBalance -= kDocBurnt;
    }

    /**
     * @notice Deduct and transfer fee from amount
     * @param amount Amount of DOC to deduct fee from
     * @return netAmount Amount of DOC after fee deduction
     */
    function _deductAndTransferFee(uint256 amount) internal returns (uint256 netAmount) {
        uint256 fee = (amount * FEE_RATE_BPS) / FEE_PERCENTAGE_DIVISOR;
        netAmount = amount - fee;
        if (fee > 0) {
            i_docToken.safeTransfer(i_feeCollector, fee);
        }
    }

    /**
     * @notice Convert doc amount to kdoc amount
     * @param docAmount Amount of doc
     * @param exchangeRate Current exchange rate
     * @return kdocAmount Amount of kdoc
     */
    function _docToKdoc(uint256 docAmount, uint256 exchangeRate) 
        internal 
        pure 
        returns (uint256 kdocAmount) 
    {
        kdocAmount = (docAmount * EXCHANGE_RATE_DECIMALS) / exchangeRate;
    }

    /**
     * @notice Convert kdoc amount to doc amount
     * @param kdocAmount Amount of kdoc
     * @param exchangeRate Current exchange rate
     * @return docAmount Amount of doc
     */
    function _kdocToDoc(uint256 kdocAmount, uint256 exchangeRate) 
        internal 
        pure 
        returns (uint256 docAmount) 
    {
        docAmount = (kdocAmount * exchangeRate) / EXCHANGE_RATE_DECIMALS;
    }
}
