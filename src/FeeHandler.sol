// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IFeeHandler} from "./interfaces/IFeeHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenHandler
 * @dev Base contract for handling various tokens.
 */
abstract contract FeeHandler is IFeeHandler, Ownable {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////

    uint256 internal s_minFeeRate; // Minimum fee rate
    uint256 internal s_maxFeeRate; // Maximum fee rate
    uint256 internal s_purchaseLowerBound; // Spending below lower bound gets the maximum fee rate
    uint256 internal s_purchaseUpperBound; // Spending above upper bound gets the minimum fee rate
    address internal s_feeCollector; // Address to which the fees charged to the user will be sent
    uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000; // feeRate will belong to [100, 200], so we need to divide by 10,000 (100 * 100)

    constructor(address feeCollector, FeeSettings memory feeSettings) Ownable() {
        s_feeCollector = feeCollector;
        s_minFeeRate = feeSettings.minFeeRate;
        s_maxFeeRate = feeSettings.maxFeeRate;
        s_purchaseLowerBound = feeSettings.purchaseLowerBound;
        s_purchaseUpperBound = feeSettings.purchaseUpperBound;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice set the fee rate parameters
     * @param minFeeRate: the minimum fee rate
     * @param maxFeeRate: the maximum fee rate
     * @param purchaseLowerBound: the purchase lower bound
     * @param purchaseUpperBound: the purchase upper bound
     */
    function setFeeRateParams(uint256 minFeeRate, uint256 maxFeeRate, uint256 purchaseLowerBound, uint256 purchaseUpperBound)
        external
        override
        onlyOwner
    {
        if (s_minFeeRate != minFeeRate) setMinFeeRate(minFeeRate);
        if (s_maxFeeRate != maxFeeRate) setMaxFeeRate(maxFeeRate);
        if (s_purchaseLowerBound != purchaseLowerBound) setPurchaseLowerBound(purchaseLowerBound);
        if (s_purchaseUpperBound != purchaseUpperBound) setPurchaseUpperBound(purchaseUpperBound);
    }

    /**
     * @notice set the minimum fee rate
     * @param minFeeRate: the minimum fee rate
     */
    function setMinFeeRate(uint256 minFeeRate) public override onlyOwner {
        s_minFeeRate = minFeeRate;
        emit FeeHandler__MinFeeRateSet(minFeeRate);
    }

    /**
     * @notice set the maximum fee rate
     * @param maxFeeRate: the maximum fee rate
     */
    function setMaxFeeRate(uint256 maxFeeRate) public override onlyOwner {
        s_maxFeeRate = maxFeeRate;
        emit FeeHandler__MaxFeeRateSet(maxFeeRate);
    }

    /**
     * @notice set the purchase lower bound
     * @param purchaseLowerBound: the purchase lower bound
     */
    function setPurchaseLowerBound(uint256 purchaseLowerBound) public override onlyOwner {
        s_purchaseLowerBound = purchaseLowerBound;
        emit FeeHandler__PurchaseLowerBoundSet(purchaseLowerBound);
    }

    /**
     * @notice set the purchase upper bound
     * @param purchaseUpperBound: the purchase upper bound
     */
    function setPurchaseUpperBound(uint256 purchaseUpperBound) public override onlyOwner {
        s_purchaseUpperBound = purchaseUpperBound;
        emit FeeHandler__PurchaseUpperBoundSet(purchaseUpperBound);
    }

    /**
     * @notice set the fee collector address
     * @param feeCollector: the fee collector address
     */
    function setFeeCollectorAddress(address feeCollector) external override onlyOwner {
        s_feeCollector = feeCollector;
        emit FeeHandler__FeeCollectorAddress(feeCollector);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice get the minimum fee rate
     * @return the minimum fee rate
     */
    function getMinFeeRate() public view override returns (uint256) {
        return s_minFeeRate;
    }

    /**
     * @notice get the maximum fee rate
     * @return the maximum fee rate
     */ 
    function getMaxFeeRate() public view override returns (uint256) {
        return s_maxFeeRate;
    }

    /**
     * @notice get the minimum annual amount
     * @return the minimum annual amount
     */     
    function getMinAnnualAmount() public view override returns (uint256) {
        return s_purchaseLowerBound;
    }

    /**
     * @notice get the maximum annual amount
     * @return the maximum annual amount
     */
    function getMaxAnnualAmount() public view override returns (uint256) {
        return s_purchaseLowerBound;
    }

    /**
     * @notice get the fee collector address
     * @return the fee collector address
     */
    function getFeeCollectorAddress() external view override returns (address) {
        return s_feeCollector;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Calculates the fee based on the purchase amount.
     * @param purchaseAmount The amount of stablecoin to be swapped for rBTC in each purchase.
     * @return The fee amount to be deducted from the purchase amount.
     */
    function _calculateFee(uint256 purchaseAmount) internal view returns (uint256) {
        // If min and max rates are equal, apply a flat fee rate regardless of purchase amount
        if (s_minFeeRate == s_maxFeeRate) {
            return purchaseAmount * s_minFeeRate / FEE_PERCENTAGE_DIVISOR;
        }
        
        uint256 feeRate;
        
        if (purchaseAmount >= s_purchaseUpperBound) {
            feeRate = s_minFeeRate;
        } else if (purchaseAmount <= s_purchaseLowerBound) {
            feeRate = s_maxFeeRate;
        } else {
            // Calculate the linear fee rate based on purchase amount
            feeRate = s_maxFeeRate
                - ((purchaseAmount - s_purchaseLowerBound) * (s_maxFeeRate - s_minFeeRate))
                    / (s_purchaseUpperBound - s_purchaseLowerBound);
        }
        
        return purchaseAmount * feeRate / FEE_PERCENTAGE_DIVISOR;
    }

    /**
     * @notice calculate the fee and net amounts
     * @param purchaseAmounts: the purchase amounts
     * @return the fee, the net amounts, and the total amount to spend on the rBTC purchase
     */
    function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts)
        internal
        view
        returns (uint256, uint256[] memory, uint256)
    {
        uint256 fee;
        uint256 aggregatedFee;
        uint256[] memory netAmountsToSpend = new uint256[](purchaseAmounts.length);
        uint256 totalAmountToSpend;
        for (uint256 i; i < purchaseAmounts.length; ++i) {
            fee = _calculateFee(purchaseAmounts[i]);
            aggregatedFee += fee;
            netAmountsToSpend[i] = purchaseAmounts[i] - fee;
            totalAmountToSpend += netAmountsToSpend[i];
        }
        return (aggregatedFee, netAmountsToSpend, totalAmountToSpend);
    }

    /**
     * @notice transfer the fee to the fee collector
     * @param token: the token to transfer the fee to
     * @param fee: the fee to transfer
     */
    function _transferFee(IERC20 token, uint256 fee) internal {
        token.safeTransfer(s_feeCollector, fee);
    }
}
