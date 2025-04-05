# BitChill - Smart Contracts

## Introduction
BitChill is a decentralized protocol that enables users to automate their BTC purchases through Dollar-Cost Averaging (DCA) strategies. The protocol supports the Dollar On Chain stablecoin and Tropykus and Sovryn lending protocols, allowing users to create, update, and delete DCA schedules while potentially earning yield on their deposits.

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
   - `TropykusDocHandler` and `SovrynDocHandler`
      - Implement deposits and withdrawals overriding `TokenHandler` to deposit to and withdraw from lending protocols
      - Handle withdrawal of accrued interests

4. **Purchase Methods**
   - `PurchaseMoc`: Direct redemption through Money on Chain
   - `PurchaseUniswap`: Swaps through Uniswap V3 (currently deprecated)
   - Both implementations tested and compared for efficiency

### Architecture Design Considerations

The protocol was initially designed with extensibility in mind, supporting multiple purchase methods (MoC and Uniswap). However, after comprehensive testing and analysis, it was determined that:

1. Money on Chain (MoC) provides:
   - Better gas efficiency overall (slightly worse for small purchases)
   - More stable pricing
   - Direct redemption mechanism
   - No slippage

2. Current Implementation:
   - Maintains both implementations for future flexibility, since integrating other stablecoins shall require using the Uniswap version. 
   - Only the MoC version shall be deployed on mainnet for BitChill v1.
   - Could be optimized by removing the abstraction used to accomodate both methods

### Gas Efficiency Considerations

The current architecture, while extensible, has some gas inefficiencies:

1. Multiple inheritance layers
2. Redundant code paths for different purchase methods

These are intentional, considering the possibility of adding support for other stablecoins in the future.

## Features

1. **DCA Schedules**
   - Create, update, and delete DCA schedules
   - Multiple schedules per user and token
   - Configurable purchase amounts and periods
   - Automatic yield generation on deposits

2. **Token Management**
   - Currently only DOC supported
   - Support for multiple stablecoins
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

## Audit Information

### Contract Dependencies
- Rootstock-compatible compiler version (v0.8.19)
- OpenZeppelin Contracts v4.9.3
- Money on Chain Protocol

### Key Security Assumptions
1. Money on Chain protocol security
2. Token contract integrity
3. Lending protocol reliability

### Known Limitations
1. Gas efficiency trade-offs for extensibility
2. Potential for future optimization
3. Dependencies on external protocols

## Getting Started

### Prerequisites
- Rust
- Foundry
- Rootstock RPC access

### Installation
```bash
git clone git@github.com:BitChillRSK/DCAdApp.git
cd DCAdApp
./setup.sh
```

### Testing
```bash
source .env
make moc
```

## Development Roadmap

1. **Short Term**
   - Gas optimization
   - Code consolidation
   - Additional test coverage

2. **Medium Term**
   - New token integrations
   - Enhanced fee mechanisms
   - Improved batch processing

3. **Long Term**
   - Protocol upgrades
   - Advanced yield strategies

## Contact
For audit-related inquiries or security concerns, please contact:
- Smart Contract Developer: [Antonio María Rodríguez-Ynyesto Sánchez](https://www.linkedin.com/in/antonio-maria-rodriguez-ynyesto-sanchez/)

## Disclaimer
This protocol is currently undergoing security audit. Use at your own risk. Always perform due diligence before interacting with smart contracts.

## Dependency Management

This project uses Git submodules for dependency management. The following dependencies are included:

- OpenZeppelin Contracts v4.9.3
- Uniswap V3 Core v1.0.0
- Uniswap V3 Periphery v1.3.0
- Uniswap Swap Router Contracts v1.3.0

Due to Rootstock's requirement for Solidity 0.8.19, we've modified the pragma statements in some dependencies. These modifications are documented in [DEPENDENCY_MODIFICATIONS.md](./DEPENDENCY_MODIFICATIONS.md).
