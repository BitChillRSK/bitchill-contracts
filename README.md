# BitChill - Smart Contracts

## Introduction
BitChill is a decentralized protocol on Rootstock that enables users to automate their BTC purchases with Dollar-Cost Averaging (DCA) strategies. The protocol currently supports stablecoins DOC and USDRIF and integrates with Tropykus and Sovryn lending protocols, allowing users to create, update, and delete DCA schedules while earning yield on their deposits.

## Protocol Architecture

### Core Components

1. **DcaManager**
   - Central contract managing all DCA operations
   - It is the only contract users shall interact with through BitChill's UI to create, delete or modify their DCA schedules
   - It is the only contract the CRON job will interact with to trigger the purchases
   - Keeps track of users' DCA schedules
   - Implements access control and security checks

2. **Token Handlers**
   - Base contract: `TokenHandler` abstract contract
   - Implements core token operations and access control
   - Stores the stablecoins deposited by the users
   - Handles deposits and withdrawals of stablecoins

3. **Lending Integration**
   - `TokenLending` abstract contract
      - Manages conversion of balances from stablecoins to lending tokens and viceversa
   - Supports multiple lending protocols (Tropykus, Sovryn)
   - `TropykusErc20Handler` and `SovrynErc20Handler`
      - Implement deposits and withdrawals overriding `TokenHandler` to deposit to and withdraw from lending protocols
      - Handle withdrawal of accrued interests

4. **Purchase Methods**
   - `PurchaseMoc`: Direct redemption through Money on Chain (for DOC)
   - `PurchaseUniswap`: Swaps through Uniswap V3 (for other stablecoins)
   - Both implementations tested and optimized for their specific use cases

### Architecture Design Considerations

The protocol was designed with extensibility in mind, supporting multiple purchase methods and stablecoins:

1. Money on Chain (MoC) for DOC:
   - Better gas efficiency overall (slightly worse for small purchases)
   - More stable pricing (primary market)
   - Direct redemption mechanism
   - No slippage

2. Uniswap V3 for other stablecoins:
   - Flexible integration for any ERC20 stablecoin
   - Market-based pricing
   - Owner-configurable slippage protection
   - Path optimization for best rates

### Gas Efficiency Considerations

The current architecture balances extensibility with gas efficiency:

1. Multiple inheritance layers to support different purchase methods
2. Optimized purchase paths for each stablecoin type
3. Batch processing for gas savings

## Features

1. **DCA Schedules**
   - Create, update, and delete DCA schedules
   - Multiple schedules per user and token
   - Configurable purchase amounts and periods
   - Automatic yield generation on deposits

2. **Token Management**
   - Support for multiple stablecoins (DOC, USDRIF)
   - Integration with lending protocols
   - Interest accrual and withdrawal
   - Fee management system

3. **Security Features**
   - Access control for all critical functions
   - Reentrancy protection
   - Input validation and error handling

4. **Batch Processing**
   - Gas-efficient batch purchases
   - Optimized for multiple users

## Security Considerations

### Access Control
- Role-based access control for all critical functions
- Owner and admin roles with specific permissions
- Swapper role for purchase operations
- DCA manager contract as central authority

### Reentrancy Protection
- ReentrancyGuard implementation
- Checks-Effects-Interactions pattern
- Safe token transfers using SafeERC20

### Input Validation
- Comprehensive parameter validation
- Range checks for amounts and periods
- Schedule existence verification
- Balance checks before operations

### Contract Dependencies
- Rootstock-compatible compiler version (v0.8.19)
- OpenZeppelin Contracts v4.9.3
- Money on Chain Protocol (for DOC)
- Uniswap V3 Protocol (for other stablecoins)

### Key Security Assumptions
1. Money on Chain protocol security (for DOC)
2. Uniswap V3 protocol security (for other stablecoins)
3. Token contract integrity
4. Lending protocol reliability

### Known Limitations
1. Gas efficiency trade-offs for extensibility
2. Potential for future optimization
3. Dependencies on external protocols

### Audit and Testing

BitChill's smart-contracts have undergone a manual audit by **[Ivan Fitro](https://github.com/IvanFitro)**.  

Also, we used an extensive automation pipeline:

* 100 % branch-level test-coverage on core contracts, with > 94 % line coverage overall.  
  – Hundreds of AI-generated unit tests exercise edge-cases that were missed in the original hand-written suite.
* Property-based fuzzing & invariant testing.

Despite these measures **no audit or test-suite can guarantee absolute safety**. You should always perform your own due-diligence and only risk funds you can afford to lose.

## Getting Started

### Prerequisites
- Rust
- Foundry
- Rootstock RPC access

### Installation
```bash
git clone git@github.com:BitChillRSK/DCAdApp.git
cd bitchill-contracts
git checkout smart-contracts
./setup.sh
```

### Testing
```bash
# Run tests with DOC and Tropykus
make moc-tropykus 

# Run tests with DOC and Sovryn
make moc-sovryn 

# Run tests with USDRIF and Tropykus
make dex-tropykus

# Run tests with USDRIF and Sovryn
make dex-sovryn

# Run specific test file with custom parameters
STABLECOIN_TYPE=USDRIF SWAP_TYPE=dexSwaps LENDING_PROTOCOL=tropykus forge test --match-path test/unit/DcaDappTest.t.sol -vvv

# -------------------------------
# Invariant & Fuzz Testing
# -------------------------------
# Foundry-based fuzzing and invariants live in `test/ai-generated/fuzz`.  A detailed guide
# is available in [README_INVARIANTS.md](test/ai-generated//fuzz/README_INVARIANTS.md).
#
# Quick examples:
#
# Run the full invariant suite with Tropykus (default)
forge test --match-contract InvariantTest
#
# Same suite but forcing Sovryn mocks
LENDING_PROTOCOL=sovryn forge test --match-contract InvariantTest
#
# Run a single invariant (e.g. deposit-vs-lending consistency)
forge test --match-test invariant_totalDepositedTokensMatchesLendingProtocol -vv
```

### Deployment

To deploy the BitChill smart contracts on Rootstock testnet follow these steps:

1. Set up your environment variables in `.env`:
```bash
# Required variables
RSK_TESTNET_RPC_URL=your_rsk_testnet_rpc_url
PRIVATE_KEY=your_private_key
BLOCKSCOUT_API_KEY=your_blockscout_api_key
BLOCKSCOUT_API_URL=https://rootstock-testnet.blockscout.com/api

# Deployment configuration
export SWAP_TYPE=mocSwaps  # for DOC, or dexSwaps for other stablecoins
export STABLECOIN_TYPE=DOC  # or USDRIF
export REAL_DEPLOYMENT=true  # Set to true for actual deployment on a live network
```

2. Deploy the contracts:
```bash
forge script script/DeployMocSwaps.s.sol \
  --rpc-url $RSK_TESTNET_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url $BLOCKSCOUT_API_URL \
  --legacy
```

### Compilation profile for deployment
Before deploying on-chain, compile using the dedicated `deploy` profile that activates the Yul Intermediate Representation (via_IR) pipeline (see `foundry.toml`).

```bash
# One-off compilation
FOUNDRY_PROFILE=deploy forge build

# Or run any script / test under the deploy profile
FOUNDRY_PROFILE=deploy forge script ...
```

This profile sets `via_ir = true` and `optimizer_runs = 200`, producing smaller, cheaper byte-code, under the 24,576-byte limit (as per EIP-170). 

*Warning*: viaIR compilation might cause unexpected results. Be sure to run the full test suite again before deploying the contracts on Rootstock mainnet!

## Dependency Management

This project uses Git submodules for dependency management. The following dependencies are included:

- OpenZeppelin Contracts v4.9.3
- Uniswap V3 Core v1.0.0
- Uniswap V3 Periphery v1.3.0
- Uniswap Swap Router Contracts v1.3.0

Due to Rootstock's requirement for Solidity 0.8.19, we've modified the pragma statements in some dependencies. These modifications are documented in [DEPENDENCY_MODIFICATIONS.md](./DEPENDENCY_MODIFICATIONS.md).

For a complete list of contract addresses used in the protocol (including both mainnet and testnet), please refer to [ADDRESSES.md](./ADDRESSES.md).

## Contact
For audit-related inquiries or security concerns, please contact:
- Smart Contract Developer: [Antonio Rodríguez-Ynyesto](https://www.linkedin.com/in/antonio-maria-rodriguez-ynyesto-sanchez/)

## Disclaimer
This protocol has been audited but could still have bugs. Use at your own risk. Always perform due diligence before interacting with smart contracts.

