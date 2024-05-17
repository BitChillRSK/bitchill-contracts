// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title FeeCalculator
 * @dev Contract to calculate dynamic fees based on annual spending.
 */
contract FeeCalculator {
    uint256 public constant MIN_FEE_RATE = 100; // Minimum fee rate in basis points (1%)
    uint256 public constant MAX_FEE_RATE = 200; // Maximum fee rate in basis points (2%)
    uint256 public constant MIN_SPENDING = 1_000 ether; // Spending below 1,000 DOC annually gets the maximum fee rate
    uint256 public constant MAX_SPENDING = 100_000 ether; // Spending above 100,000 DOC annually gets the minimum fee rate

    /**
     * @dev Calculates the fee rate based on the annual spending.
     * @param purchaseAmount The amount of stablecoin to be swapped for rBTC in each purchase.
     * @param purchasePeriod The period between purchases in seconds.
     * @return The fee rate in basis points.
     */
    function calculateFeeRate(uint256 purchaseAmount, uint256 purchasePeriod) external pure returns (uint256) {
        uint256 annualSpending = (purchaseAmount * 365 days) / purchasePeriod;

        if (annualSpending >= MAX_SPENDING) {
            return MIN_FEE_RATE;
        } else if (annualSpending <= MIN_SPENDING) {
            return MAX_FEE_RATE;
        } else {
            // Calculate the linear fee rate
            uint256 feeRate = MAX_FEE_RATE - ((annualSpending - MIN_SPENDING) * (MAX_FEE_RATE - MIN_FEE_RATE)) / (MAX_SPENDING - MIN_SPENDING);
            return feeRate;
        }
    }
}
