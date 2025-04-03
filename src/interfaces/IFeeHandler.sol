// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IFeeHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the FeeHandler contract.
 */
interface IFeeHandler {
    ////////////////////////
    // Type declarations ///
    ////////////////////////
    struct FeeSettings {
        uint256 minFeeRate; // the lowest possible fee
        uint256 maxFeeRate; // the highest possible fee
        uint256 minAnnualAmount; // the annual amount below which max fee is applied
        uint256 maxAnnualAmount; // the annual amount above which min fee is applied
    }

    //////////////////////
    // Events ////////////
    //////////////////////
    event FeeHandler__MinFeeRateSet(uint256 indexed minFeeRate);
    event FeeHandler__MaxFeeRateSet(uint256 indexed maxFeeRate);
    event FeeHandler__MinAnnualAmountSet(uint256 indexed minAnnualAmount);
    event FeeHandler__MaxAnnualAmountSet(uint256 indexed maxAnnualAmount);
    event FeeHandler__FeeCollectorAddress(address indexed feeCollector);

    //////////////////////
    // Errors ////////////
    //////////////////////
    // error FeeHandler__FeeTransferFailed(address feeCollector, address token, uint256 feeAmount);

    ///////////////////////////////
    // External functions /////////
    ///////////////////////////////

    /**
     * @dev Sets the parameters for the fee rate.
     * @param minFeeRate The minimum fee rate.
     * @param maxFeeRate The maximum fee rate.
     * @param minAnnualAmount The minimum annual amount for fee calculations.
     * @param maxAnnualAmount The maximum annual amount for fee calculations.
     */
    function setFeeRateParams(uint256 minFeeRate, uint256 maxFeeRate, uint256 minAnnualAmount, uint256 maxAnnualAmount)
        external;

    /**
     * @dev Sets the minimum fee rate.
     * @param minFeeRate The minimum fee rate.
     */
    function setMinFeeRate(uint256 minFeeRate) external;

    /**
     * @dev Sets the maximum fee rate.
     * @param maxFeeRate The maximum fee rate.
     */
    function setMaxFeeRate(uint256 maxFeeRate) external;

    /**
     * @dev Sets the minimum annual amount for fee calculations.
     * @param minAnnualAmount The minimum annual amount.
     */
    function setMinAnnualAmount(uint256 minAnnualAmount) external;

    /**
     * @dev Sets the maximum annual amount for fee calculations.
     * @param maxAnnualAmount The maximum annual amount.
     */
    function setMaxAnnualAmount(uint256 maxAnnualAmount) external;

    /**
     * @dev Sets the address of the fee collector.
     * @param feeCollector The address of the fee collector.
     */
    function setFeeCollectorAddress(address feeCollector) external;

    /**
     * @dev Gets the minimum fee rate that may be charged for each purchases
     */
    function getMinFeeRate() external returns (uint256);

    /**
     * @dev Gets the maximum fee rate that may be charged for each purchases
     */
    function getMaxFeeRate() external returns (uint256);

    /**
     * @dev Gets the annual (periodic purchase * number of purchases in a year) amount below which the max fee rate is charged
     */
    function getMinAnnualAmount() external returns (uint256);

    /**
     * @dev Gets the annual (periodic purchase * number of purchases in a year) amount above which the min fee rate is charged
     */
    function getMaxAnnualAmount() external returns (uint256);

    /**
     * @dev Gets the fee collector address
     */
    function getFeeCollectorAddress() external returns (address);
}
