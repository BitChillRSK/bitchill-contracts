## Intro
`CToken::getSupplierSnapshotStored()`'s second return value, `underlyingAmount` —which is supposed to return the amount of underlying tokens equivalent to a user's kToken balance as of the latest market update— is erroneous, since it does not account for the interest accrued. This could cause accounting/TVL errors on third party integrations. Also, because `underlyingAmount` doesn’t include the accrued interest, protocols that rely on it for safety checks on withdrawals may reject valid redemptions, effectively causing permanent freeze of unclaimed yield.

## Vulnerability Details
In the [Proof of Concept](#proof-of-concept) section it is proven that `underlyingAmount` does not account for accrued interest, thus remaining lower than the amount of underlying tokens equivalent to the minted kTokens, at any given time after the deposit was made. It forks Rootstock mainnet at block 8089800 and shows that after interest accrues, `getSupplierSnapshotStored()` continues to report the original deposit amount. This is because `underlyingAmount` only gets updated on deposits (kToken mints) and withdrawals (kToken burns - underlying token redemptions), but not when interest is accrued. The expected outcome would be `getSupplierSnapshotStored().underlyingAmount` being equal to the kToken balance times the exchange rate returned by `exchangeRateStored()` divided by 1e18.

## Impact Details
The impact of this issue is uncertain, since it would depend on the use a third party protocol made of `underlyingAmount`. However, a plausible use of this datum would be a safety check to avoid calling the `redeemUnderlying()` function with a withdrawal amount greater than the one equivalent to the kToken balance held by the contract. Of course, `underlyingAmount` would be outdated by a few blocks, depending on when the latest market update happened, but leaving some dust in Tropykus by limiting the withdrawal amount to the one available at the latest market updated can actually be cheaper than calling `balanceOfUnderlying()` to perform the aforementioned safety check.

On the one hand, calling `balanceOfUnderlying()` is 9138 gas units more expensive than calling `getSupplierSnapshotStored()`, considering a gas price of 0.06 GWEI (default on Rootstock) and a bitcoin price of \$100,000, this would mean \$0.054828 more per withdrawal. On the other hand, `exchangeRateStored()` is typically around 99.999% of `exchangeRateCurrent()`. This means that on every partial withdrawal that made this check calling `getSupplierSnapshotStored()` instead of `balanceOfUnderlying()`, approximately \$0.054 would be saved, and only on total withdrawals in which the full underlying amount was redeemed would some dust be left in Tropykus. This dust would only exceed the amount saved on gas for withdrawal amounts of over \$5482.8, considering the approximations made above. Thus, it is plausible that a developer of a third party protocol would use this datum for such a check. Also, it should be noted that if/when EIP-7702 gets deployed on Rootstock, users interacting with Tropykus through a smart contract, thus potentially becoming affected by this bug, shall become more likely.

A smart contract that would have its funds frozen due to the wrong return value of `getSupplierSnapshotStored()` would look as follows:

```Solidity
contract VulnerableContract {
    IkToken public immutable kToken;
    IERC20 public immutable underlyingToken;
    
    error InsufficientUnderlyingBalance(uint256 requested, uint256 available);
    error TropykusRedemptionFailed(uint256 errorCode);

    constructor(address _kToken, address _underlyingToken) {
        kToken = IkToken(_kToken);
        underlyingToken = IERC20(_underlyingToken);
    }

    function depositOnTropykus(uint256 depositAmount) external onlyOwner {
        underlyingToken.transferFrom(msg.sender, address(this), depositAmount);
        kToken.mint(depositAmount); // Mint kTokens to the contract
    }
    
    function withdrawFundsFromTropykus(uint256 withdrawalAmount) external onlyOwner {
        // Get the underlying amount that can be redeemed according to Tropykus
        (, uint256 snapshotUnderlyingAmount,,) = kToken.getSupplierSnapshotStored(address(this));
        
        // This check shall fail for total withdrawals even if withdrawalAmount is lower 
        // than the real underlying amount of tokens equivalent to the kToken balance of 
        // this contract because snapshotUnderlyingAmount doesn't include accrued interest
        if (withdrawalAmount > snapshotUnderlyingAmount) {
            revert InsufficientUnderlyingBalance(withdrawalAmount, snapshotUnderlyingAmount);
        }
        
        // Attempt to redeem the underlying tokens
        uint256 result = kToken.redeemUnderlying(withdrawalAmount);
        if(result != 0) TropykusRedemptionFailed(result);
        
        // Transfer the underlying tokens to the caller
        underlyingToken.transfer(msg.sender, withdrawalAmount);
    }
}
```

In this contract, if the owner tried to withdraw the whole amount of underlying tokens equivalent to the kTokens stored in the contract, the transaction would fail, and it would only pass if the withdrawal amount were lower than or equal to the total amount deposited by calling `depositOnTropykus()` minus the total amount withdrawn on previous calls to `withdrawFundsFromTropykus()`.

## Proof of Concept

The Foundry test below confirms the bug explained above. Please note, that although kDoc was the kToken selected for this PoC, the bug affects other kTokens such as kUSDRIF and kRBTC as well.

```Solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CErc20Immutable} from "src/TropykusCriticalBugPoc/CErc20Immutable.sol";
import {ComptrollerInterface} from "src/TropykusCriticalBugPoc/ComptrollerInterface.sol";
import {InterestRateModel} from "src/TropykusCriticalBugPoc/InterestRateModel.sol";

interface IkToken {
    function accrueInterest() external;
    function mint(uint256 mintAmount) external returns (uint256);
    function getSupplierSnapshotStored(address owner)
        external
        returns (uint256 tokens, uint256 underlyingAmount, uint256 suppliedAt, uint256 promisedSupplyRate);
    function exchangeRateStored() external view returns (uint256);
    function balanceOfUnderlying(address owner) external returns (uint256);
}

/**
 * @title TropykusBugPoc
 * @dev Proof of Concept for Tropykus getSupplierSnapshotStored bug
 * @notice This test demonstrates that getSupplierSnapshotStored() returns incorrect underlyingAmount
 *         because accrued interest is never added to the underlyingAmount variable
 */
contract TropykusBugPoc is Test {
    // Mainnet addresses on Rootstock
    address constant K_DOC = 0x544Eb90e766B405134b3B3F62b6b4C23Fcd5fDa2;
    address constant DOC = 0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db;
    uint256 constant BLOCK_NUMBER = 8089800; // Block number of the day this POC was written
    uint256 constant BLOCK_TIME = 30 seconds;
    
    IkToken kDoc;
    IERC20 doc;
    uint256 docToDeposit = 1000 ether; // 1000 DOC
    
    address user = makeAddr("user");
    
    function setUp() public {
        // Fork Rootstock mainnet
        vm.createSelectFork("https://public-node.rsk.co", BLOCK_NUMBER);
        
        kDoc = IkToken(K_DOC);
        doc = IERC20(DOC);
        
        // Give user some DOC tokens
        deal(DOC, user, docToDeposit);
        
        // Approve kDoc to spend user's DOC
        vm.prank(user);
        doc.approve(K_DOC, type(uint256).max);
    }
    
    function testTropykusUnderlyingAmountBug() public {
        console2.log("=== Tropykus getSupplierSnapshotStored Bug POC ===");
        console2.log("Forked block:", block.number);
        
        
        // Step 1: User deposits 1000 DOC
        vm.prank(user);
        kDoc.mint(docToDeposit);
        console2.log("User deposited",  docToDeposit, " wei of DOC");
        
        // Get initial snapshot
        (uint256 tokens, uint256 underlyingAmount, , ) = kDoc.getSupplierSnapshotStored(user);
        
        console2.log("\nInitial state:");
        console2.log("  kToken balance:", tokens);
        console2.log("  underlyingAmount:", underlyingAmount);
        console2.log("  exchange rate:", kDoc.exchangeRateStored());
        
        // Verify initial state - underlyingAmount should equal deposit
        assertEq(underlyingAmount, docToDeposit, "Initial underlyingAmount should equal deposit");
        
        // Step 2: Simulate time passing and interest accrual
        vm.roll(block.number + 90 days / BLOCK_TIME);
        
        // Interest accrual is forced by calling accrueInterest()
        kDoc.accrueInterest();
        // Call exchangeRateStored() to get the exchange rate as of the latest market update for coherence,
        // since getSupplierSnapshotStored() would be expected to return the underlying amount as of the latest market update as well
        uint256 newExchangeRate = kDoc.exchangeRateStored();
        
        // Get updated snapshot after interest accrual
        (tokens, underlyingAmount, , ) = kDoc.getSupplierSnapshotStored(user);
        
        console2.log("\nAfter 90 days have passed and interest accrual has happened:");
        console2.log("  kToken balance:", tokens);
        console2.log("  underlyingAmount:", underlyingAmount);
        console2.log("  exchange rate:", newExchangeRate);
        
        // Calculate what the underlying amount should be
        uint256 expectedUnderlying = (tokens * newExchangeRate) / 1e18;
        console2.log("  Expected underlying amount:", expectedUnderlying);
        
        // Step 3: Prove the bug
        console2.log("\nBug Analysis:");
        console2.log("  underlyingAmount reported:", underlyingAmount);
        console2.log("  Expected value:", expectedUnderlying);
        console2.log("  Difference:", expectedUnderlying - underlyingAmount);
        
        // The bug: underlyingAmount should include accrued interest but doesn't
        assertTrue(underlyingAmount < expectedUnderlying, "underlyingAmount should be less than expected due to missing interest");
        
        console2.log("\nBUG CONFIRMED: underlyingAmount does not include accrued interest");
        console2.log("Impact: Third-party integrations will read lower than expected balance data");
    }
}
```

Below is the log output of the Foundry fork test proving the bug:

```bash
[PASS] testTropykusUnderlyingAmountBug() (gas: 280300)
Logs:
  === Tropykus getSupplierSnapshotStored Bug POC ===
  Forked block: 8089800
  User deposited 1000000000000000000000  wei of DOC
  
Initial state:
    kToken balance: 38704162440561780289430
    underlyingAmount: 1000000000000000000000
    exchange rate: 25837014340142514
  
After 90 days have passed and interest accrual has happened:
    kToken balance: 38704162440561780289430
    underlyingAmount: 1000000000000000000000
    exchange rate: 26227721044353484
    Expected underlying amount: 1015121975746397906235
  
Bug Analysis:
    underlyingAmount reported: 1000000000000000000000
    Expected value: 1015121975746397906235
    Difference: 15121975746397906235
  
BUG CONFIRMED: underlyingAmount does not include accrued interest
  Impact: Third-party integrations will read lower than expected balance data
```

## Recommended mitigation

To fix this bug, the following modification may be made to `getSupplierSnapshotStored()`, after implementing a function `balanceOfUnderlyingStored()`, very similar to `balanceOfUnderlying()`:

```Solidity
       function getSupplierSnapshotStored(address account)
        public
        view
        returns (
            uint256 tokens,
            uint256 underlyingAmount,
            uint256 suppliedAt,
            uint256 promisedSupplyRate
        )
    {
        tokens = accountTokens[account].tokens;
-       underlyingAmount = accountTokens[account].underlyingAmount;
+       underlyingAmount = accountTokens[account].suppliedAt == block.number ? accountTokens[account].underlyingAmount : balanceOfUnderlyingStored(account);
        suppliedAt = accountTokens[account].suppliedAt;
        promisedSupplyRate = accountTokens[account].promisedSupplyRate;
    }

+   /**
+    * @notice Get the underlying balance of the `owner` as of the last market update
+    * @dev This does not accrue interest in a transaction
+    * @param owner The address of the account to query
+    * @return The amount of underlying owned by `owner`
+    */
+   function balanceOfUnderlyingStored(address owner) public view returns (uint256) {
+       Exp memory exchangeRate = Exp({mantissa: exchangeRateStored()});
+       (MathError mErr, uint256 balance) = mulScalarTruncate(
+           exchangeRate,
+           accountTokens[owner].tokens
+       );
+       require(mErr == MathError.NO_ERROR, "T6");
+       return balance;
+   }
```

Implementing this fix would make `getSupplierSnapshotStored(account).underlyingAmount` equal to the underlying amount that would correspond to the kToken balance of the account at the exchange rate returned by `exchangeRateStored()`.

Also, it should be duly noted that this fix does not save the updated underlying amount in the contract's storage, it just fixes the public getter. However, this is probably the simplest and most efficient approach to fix this bug. This is because, since the Tropykus hack in June 2023, the custom Tropykus interest rate model shall never be used again and `interestRateModel.isTropykusInterestRateModel()` shall never return true, therefore leaving no paths in which `accountTokens[account].underlyingAmount` is read anywhere in the protocol, making it unnecessary to update this value with the interest accrued other than to return it in `getSupplierSnapshotStored()`.

Below is the snippet of a PoC for the suggested mitigation. This test would go below the bug's PoC test, in the same file:

```Solidity
    function testTropykusUnderlyingAmountBugFixed() public {
        console2.log("=== Testing Fixed Tropykus getSupplierSnapshotStored ===");
        console2.log("Forked block:", block.number);
        
        // Deploy the fixed kDOC contract
        CErc20Immutable fixedKDoc = new CErc20Immutable(
            0xe700691dA7b9851F2F35f8b8182c69c53CcaD9Db, // underlying_
            ComptrollerInterface(0x962308fEf8edFaDD705384840e7701F8f39eD0c0), // comptroller_
            InterestRateModel(0xAfB97ECb5007cbd7B72a4D9Add35B44d9d00eDc1), // interestRateModel_
            20000000000000000, // initialExchangeRateMantissa_
            "Tropykus kDOC", // name_
            "kDOC", // symbol_
            18, // decimals_
            payable(0x784024A1F91564743Cf7c17f4D5E994A8ee002e7) // admin_
        );
                
        // Replace the original kDOC with our fixed version
        vm.etch(K_DOC, address(fixedKDoc).code);
        
        // Step 1: User deposits 1000 DOC
        vm.prank(user);
        kDoc.mint(docToDeposit);
        console2.log("User deposited", docToDeposit, " wei of DOC to FIXED contract");
        
        // Get initial snapshot
        (uint256 tokens, uint256 underlyingAmount, , ) = kDoc.getSupplierSnapshotStored(user);
        
        console2.log("\nInitial state (FIXED):");
        console2.log("  kToken balance:", tokens);
        console2.log("  underlyingAmount:", underlyingAmount);
        console2.log("  exchange rate:", kDoc.exchangeRateStored());
        
        // Verify initial state - underlyingAmount should equal deposit
        assertEq(underlyingAmount, docToDeposit, "Initial underlyingAmount should equal deposit");
        
        // Step 2: Simulate time passing and interest accrual
        vm.roll(block.number + 90 days / BLOCK_TIME);
        
        // Interest accrual is forced by calling accrueInterest()
        kDoc.accrueInterest();
        uint256 newExchangeRate = kDoc.exchangeRateStored();
        
        // Get updated snapshot after interest accrual
        (tokens, underlyingAmount, , ) = kDoc.getSupplierSnapshotStored(user);
        
        console2.log("\nAfter 90 days and interest accrual (FIXED):");
        console2.log("  kToken balance:", tokens);
        console2.log("  underlyingAmount:", underlyingAmount);
        console2.log("  exchange rate:", newExchangeRate);
        
        // Calculate what the underlying amount should be
        uint256 expectedUnderlying = (tokens * newExchangeRate) / 1e18;
        console2.log("  Expected underlying amount:", expectedUnderlying);
        
        // Step 3: Test if the bug is fixed
        console2.log("\nFixed Contract Analysis:");
        console2.log("  underlyingAmount reported:", underlyingAmount);
        console2.log("  Expected value:", expectedUnderlying);
        console2.log("  Difference:", expectedUnderlying > underlyingAmount ? expectedUnderlying - underlyingAmount : underlyingAmount - expectedUnderlying, "wei");
        
        // The fix in CToken should make underlyingAmount exactly right
        assertEq(underlyingAmount, expectedUnderlying, "Fixed underlyingAmount should be exactly equal to expected value");
        
        console2.log("\nFIX CONFIRMED: underlyingAmount now includes accrued interest");
        
        // Step 4: Compare with balanceOfUnderlying() 1 block later
        vm.roll(block.number + 1);
        uint256 balanceOfUnderlying = kDoc.balanceOfUnderlying(user);
        console2.log("\nComparison with balanceOfUnderlying:");
        console2.log("  underlyingAmount from getSupplierSnapshotStored:", underlyingAmount);
        console2.log("  balanceOfUnderlying:", balanceOfUnderlying);
        console2.log("  Difference:", balanceOfUnderlying - underlyingAmount, "wei");
        
        // balanceOfUnderlying should be slightly greater due to rounding differences
        assertGt(balanceOfUnderlying, underlyingAmount, "balanceOfUnderlying should be > underlyingAmount");
        // Difference should be very small, less than 0.00001%
        assertApproxEqRel(balanceOfUnderlying, underlyingAmount, 1e11, "balanceOfUnderlying should be > underlyingAmount");
        
        console2.log("\nSUCCESS: The fix works correctly!");
    }
```

The output of the fix's PoC test looks as follows:

```bash
Ran 1 test for test/TropykusBugPoc.t.sol:TropykusBugPoc
[PASS] testTropykusUnderlyingAmountBugFixed() (gas: 9025898)
Logs:
  === Testing Fixed Tropykus getSupplierSnapshotStored ===
  Forked block: 8089800
  User deposited 1000000000000000000000  wei of DOC to FIXED contract
  
Initial state (FIXED):
    kToken balance: 38704162440561780289430
    underlyingAmount: 1000000000000000000000
    exchange rate: 25837014340142514
  
After 90 days and interest accrual (FIXED):
    kToken balance: 38704162440561780289430
    underlyingAmount: 1015121975746397906235
    exchange rate: 26227721044353484
    Expected underlying amount: 1015121975746397906235
  
Fixed Contract Analysis:
    underlyingAmount reported: 1015121975746397906235
    Expected value: 1015121975746397906235
    Difference: 0 wei
  
FIX CONFIRMED: underlyingAmount now includes accrued interest
  
Comparison with balanceOfUnderlying:
    underlyingAmount from getSupplierSnapshotStored: 1015121975746397906235
    balanceOfUnderlying: 1015122036363179953172
    Difference: 60616782046937 wei
  
SUCCESS: The fix works correctly!
```