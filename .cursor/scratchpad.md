# BitChill DCA Manager - deleteDcaSchedule Failure Analysis

## Background and Motivation

A user's `deleteDcaSchedule` transaction failed on RSK mainnet at block 7911986 with error code 9. The transaction involves withdrawing tokens from a lending protocol (Tropykus) before deleting the DCA schedule. The failure occurs during the `redeemUnderlying` call to the Tropykus protocol.

## Key Challenges and Analysis

### Transaction Flow Analysis

1. **User calls `deleteDcaSchedule`** on BitChill DCA Manager
2. **DCA Manager calls `withdrawToken`** on the token handler (TropykusDocHandlerMoc)
3. **Token handler calls `redeemUnderlying`** on the Tropykus cToken (kDOC)
4. **cToken calls `redeemAllowed`** on the Comptroller
5. **Comptroller returns 0** (success) but then emits a Failure event
6. **cToken reverts** with error code 9

### Error Code Analysis

From the ErrorReporter.sol and the trace, error code 9 corresponds to:
- **Error 9**: `TOKEN_INSUFFICIENT_CASH` 
- **Info 45**: `REDEEM_EXCHANGE_AMOUNT_CALCULATION_FAILED`
- **Detail 3**: Additional opaque error from the cToken

### Root Cause Analysis

The issue occurs in the cToken's `redeemUnderlying` function after `redeemAllowed` succeeds. Looking at the trace:

1. **`redeemAllowed` returns 0** - The Comptroller allows the redemption
2. **cToken calculates exchange rate** and determines how many underlying tokens to return
3. **Arithmetic underflow occurs** during the calculation:
   ```
   subUInt(a = 2354341273288807542861, b = 2354341273288807542892) => (3, 0)
   ```
4. **`failOpaque` is called** with error 9, info 45, detail 3
5. **Transaction reverts**

### Specific Problem

The issue is a **precision/rounding error** in the Tropykus cToken implementation. The cToken is trying to redeem 2,354,341,273,288,807,542,892 tokens but the calculation results in an underflow when converting to underlying tokens.

This suggests that either:
1. The exchange rate calculation has precision issues
2. The amount being redeemed is too large relative to the available liquidity
3. There's a bug in the cToken's arithmetic operations

### Impact on BitChill

This failure prevents users from deleting DCA schedules when they have positions in Tropykus, as the underlying token withdrawal fails. This is a critical issue that affects the core functionality of the DCA system.

## High-level Task Breakdown

1. **Verify the exact failure point** in the Tropykus cToken code
2. **Identify the arithmetic operation** causing the underflow
3. **Determine if this is a known issue** in the Tropykus protocol
4. **Assess potential workarounds** for BitChill users
5. **Consider protocol-level fixes** or alternative approaches

## Project Status Board

- [ ] Analyze Tropykus cToken redeemUnderlying implementation
- [ ] Identify the specific arithmetic operation causing underflow
- [ ] Research if this is a known Tropykus protocol issue
- [ ] Determine immediate workarounds for affected users
- [ ] Evaluate long-term solutions

## Root Cause: Cross-Protocol Accounting Corruption

### **THE SMOKING GUN: Misused batchBuyRbtc**

Based on the six key insights, the root cause is **accounting corruption** caused by your colleague's misuse of `batchBuyRbtc`:

1. **batchBuyRbtc was called with mixed protocol schedules** - Tropykus AND Sovryn schedules in the same batch
2. **Only one `lendingProtocolIndex` (Tropykus) was passed** to the function
3. **All purchases were routed through TropykusErc20Handler** regardless of actual protocol
4. **Sovryn schedule purchases corrupted Tropykus accounting**

### **How the Corruption Occurred**

When `batchBuyRbtc` was misused:

```solidity
// This happened in DcaManager.batchBuyRbtc:
for (uint256 i; i < numOfPurchases; ++i) {
    // Decremented tokenBalance for BOTH Tropykus AND Sovryn schedules
    _rBtcPurchaseChecksEffects(buyers[i], token, scheduleIndexes[i], scheduleIds[i]);
}
// But then ALL purchases went through Tropykus handler:
IPurchaseRbtc(address(_handler(token, lendingProtocolIndex))).batchBuyRbtc(
    buyers, scheduleIds, purchaseAmounts  // <-- Tropykus handler processed ALL
);
```

**Result**: 
- DcaManager decremented tokenBalances for BOTH protocols
- But TropykusErc20Handler only decremented `s_kTokenBalances` for Tropykus purchases
- Sovryn purchases never decremented `s_kTokenBalances` but DID decrement DcaManager balances
- **Net effect**: `s_kTokenBalances` became INFLATED relative to actual kTokens held

### **Why This Caused the Exact Failure Pattern**

1. **90 DOC attempted withdrawal** (from DcaManager tokenBalance)
2. **Only 60.18 DOC available** (actual underlying from kTokens)  
3. **Withdrawal adjusted down** (TokenLending__WithdrawalAmountAdjusted)
4. **kToken calculation**: 60.18 DOC → 2,354,341,273,288,807,542,892 kTokens needed
5. **Available kTokens**: Only 2,354,341,273,288,807,542,861 (31 kTokens short)
6. **Arithmetic underflow** in Tropykus → revert

### **The Missing 31 kTokens**

The 31 kToken deficit represents the cumulative rounding/accounting errors from:
- Sovryn purchases that decremented DcaManager balances but not kToken balances
- Multiple round-trip conversions with different rounding directions
- The fact that `_lendingTokenToStablecoin` rounds UP (necessary for Sovryn)

### **Why redeemUnderlying vs redeem Distinction Matters**

Looking at your code:
- `_redeemStablecoin` uses `redeemUnderlying(stablecoinAmount)` 
- `_burnKtoken` uses `redeem(kTokenAmount)`

The distinction is crucial because:
- **redeemUnderlying**: Protocol calculates required kTokens internally (subject to its own rounding)
- **redeem**: You specify exact kTokens to burn (matches your accounting exactly)

When `s_kTokenBalances` is corrupted (inflated), using `redeemUnderlying` exposes the discrepancy because the protocol's calculation doesn't match your inflated internal accounting.

### **Evidence Supporting This Theory**

1. **TokenLending__AmountToRepayAdjusted emitted**: kTokenToRepay adjusted from 2,354,341,273,288,807,542,892 to 2,354,341,273,288,807,542,862
2. **The adjusted amount (2,354,341,273,288,807,542,862) is exactly 1 more than balanceOf returned (2,354,341,273,288,807,542,861)**
3. **Large withdrawal reduction**: 90 DOC → 60.18 DOC suggests major accounting mismatch
4. **Timing**: Issue appeared after the misused batchBuyRbtc call

## Lessons

- Cross-protocol batching functions need strict validation to prevent accounting corruption
- Rounding direction choices (UP vs DOWN) have cascading effects in multi-protocol systems  
- Internal accounting must EXACTLY match protocol state, not just approximately
- Mixed-protocol operations require careful isolation to prevent cross-contamination

## Critical Analysis: Proposed Emergency Fix

### **YOUR ANALYSIS IS INCORRECT AND DANGEROUS**

After thorough contract analysis, your proposed emergency fix would **NOT WORK** and could make the situation **MUCH WORSE**. Here's why:

### **The Fundamental Problem**

Your contracts maintain **TWO SEPARATE ACCOUNTING SYSTEMS**:

1. **Tropykus Protocol Level**: `i_kToken.balanceOf(address(this))` - actual kTokens held
2. **BitChill Internal Level**: `s_kTokenBalances[user]` - your internal user accounting

### **Why Adding kTokens Won't Fix It**

```solidity
// In _redeemInternal:
uint256 usersKtokenBalance = s_kTokenBalances[user];  // ← This is inflated/corrupted
uint256 kTokenToRepay = _stablecoinToLendingToken(stablecoinToRedeem, exchangeRate);

if (kTokenToRepay > usersKtokenBalance) {  // ← This check will still fail
    emit TokenLending__AmountToRepayAdjusted(user, kTokenToRepay, usersKtokenBalance);
    kTokenToRepay = usersKtokenBalance;  // ← Capped to inflated amount
    stablecoinToRedeem = _lendingTokenToStablecoin(kTokenToRepay, exchangeRate);
}
```

**Adding kTokens to the contract:**
- ✅ Increases `i_kToken.balanceOf(address(this))` 
- ❌ Does NOT fix `s_kTokenBalances[user]` (still inflated)
- ❌ The `if (kTokenToRepay > usersKtokenBalance)` check still caps at the corrupted amount
- ❌ You're still trying to redeem more underlying than you have kTokens for

### **The Real Issue: Internal vs External Balance Mismatch**

The problem isn't that the contract lacks kTokens - it's that your **internal accounting is wrong**:

- **Internal**: `s_kTokenBalances[user]` = inflated amount (from corruption)
- **External**: `i_kToken.balanceOf(address(this))` = actual amount
- **Result**: You try to redeem underlying worth more kTokens than you actually have

### **Why This Would Make Things Worse**

1. **You'd be masking the real problem** instead of fixing it
2. **The corruption would continue to grow** with future operations
3. **Users could withdraw more than they're entitled to** (stealing from other users)
4. **The protocol would become insolvent** over time

### **The Correct Emergency Fix**

Instead of adding kTokens, you need to **fix the internal accounting**:

1. **Audit all user balances** to find the corruption
2. **Reset corrupted `s_kTokenBalances`** to match actual kTokens
3. **Add validation** to prevent future cross-protocol corruption
4. **Consider using `redeem()` instead of `redeemUnderlying()`** to avoid protocol-level calculations

### **Why This Happens in Production**

This type of corruption is **extremely difficult to detect** because:
- It only manifests during withdrawals
- The amounts are tiny (31 wei in this case)
- It requires the exact sequence of operations that occurred
- Unit tests typically don't test cross-protocol scenarios

### **Conclusion**

Your proposed fix is **dangerous and incorrect**. The issue is **internal accounting corruption**, not insufficient kTokens. Adding kTokens would mask the problem and potentially allow users to steal funds. The real solution requires fixing the corrupted internal state and preventing future corruption.
