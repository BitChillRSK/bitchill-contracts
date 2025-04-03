// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    uint256 internal s_minAnnualAmount; // Spending below min annual amount annually gets the maximum fee rate
    uint256 internal s_maxAnnualAmount; // Spending above max annually gets the minimum fee rate
    address internal s_feeCollector; // Address to which the fees charged to the user will be sent
    uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000; // feeRate will belong to [100, 200], so we need to divide by 10,000 (100 * 100)
    // address public immutable i_stableToken; // The stablecoin token to be deposited

    constructor(address feeCollector, FeeSettings memory feeSettings) Ownable() {
        s_feeCollector = feeCollector;
        s_minFeeRate = feeSettings.minFeeRate;
        s_maxFeeRate = feeSettings.maxFeeRate;
        s_minAnnualAmount = feeSettings.minAnnualAmount;
        s_maxAnnualAmount = feeSettings.maxAnnualAmount;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setFeeRateParams(uint256 minFeeRate, uint256 maxFeeRate, uint256 minAnnualAmount, uint256 maxAnnualAmount)
        external
        override
        onlyOwner
    {
        if (s_minFeeRate != minFeeRate) setMinFeeRate(minFeeRate);
        if (s_maxFeeRate != maxFeeRate) setMaxFeeRate(maxFeeRate);
        if (s_minAnnualAmount != minAnnualAmount) setMinAnnualAmount(minAnnualAmount);
        if (s_maxAnnualAmount != maxAnnualAmount) setMaxAnnualAmount(maxAnnualAmount);
    }

    function setMinFeeRate(uint256 minFeeRate) public override onlyOwner {
        s_minFeeRate = minFeeRate;
        emit FeeHandler__MinFeeRateSet(minFeeRate);
    }

    function setMaxFeeRate(uint256 maxFeeRate) public override onlyOwner {
        s_maxFeeRate = maxFeeRate;
        emit FeeHandler__MaxFeeRateSet(maxFeeRate);
    }

    function setMinAnnualAmount(uint256 minAnnualAmount) public override onlyOwner {
        s_minAnnualAmount = minAnnualAmount;
        emit FeeHandler__MinAnnualAmountSet(minAnnualAmount);
    }

    function setMaxAnnualAmount(uint256 maxAnnualAmount) public override onlyOwner {
        s_maxAnnualAmount = maxAnnualAmount;
        emit FeeHandler__MaxAnnualAmountSet(maxAnnualAmount);
    }

    function setFeeCollectorAddress(address feeCollector) external override onlyOwner {
        s_feeCollector = feeCollector;
        emit FeeHandler__FeeCollectorAddress(feeCollector);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function getMinFeeRate() public view override returns (uint256) {
        return s_minFeeRate;
    }

    function getMaxFeeRate() public view override returns (uint256) {
        return s_maxFeeRate;
    }

    function getMinAnnualAmount() public view override returns (uint256) {
        return s_minAnnualAmount;
    }

    function getMaxAnnualAmount() public view override returns (uint256) {
        return s_maxAnnualAmount;
    }

    function getFeeCollectorAddress() external view override returns (address) {
        return s_feeCollector;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Calculates the fee rate based on the annual spending.
     * @param purchaseAmount The amount of stablecoin to be swapped for rBTC in each purchase.
     * @param purchasePeriod The period between purchases in seconds.
     * @return The fee rate in basis points.
     */
    function _calculateFee(uint256 purchaseAmount, uint256 purchasePeriod) internal view returns (uint256) {
        uint256 annualSpending = (purchaseAmount * 365 days) / purchasePeriod;
        uint256 feeRate;

        if (annualSpending >= s_maxAnnualAmount) {
            feeRate = s_minFeeRate;
        } else if (annualSpending <= s_minAnnualAmount) {
            feeRate = s_maxFeeRate;
        } else {
            // Calculate the linear fee rate
            feeRate = s_maxFeeRate
                - ((annualSpending - s_minAnnualAmount) * (s_maxFeeRate - s_minFeeRate))
                    / (s_maxAnnualAmount - s_minAnnualAmount);
        }
        return purchaseAmount * feeRate / FEE_PERCENTAGE_DIVISOR;
    }

    function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods)
        internal
        view
        returns (uint256, uint256[] memory, uint256)
    {
        uint256 fee;
        uint256 aggregatedFee;
        uint256[] memory netAmountsToSpend = new uint256[](purchaseAmounts.length);
        uint256 totalAmountToSpend;
        for (uint256 i; i < purchaseAmounts.length; ++i) {
            fee = _calculateFee(purchaseAmounts[i], purchasePeriods[i]);
            aggregatedFee += fee;
            netAmountsToSpend[i] = purchaseAmounts[i] - fee;
            totalAmountToSpend += netAmountsToSpend[i];
        }
        return (aggregatedFee, netAmountsToSpend, totalAmountToSpend);
    }

    // function transferFee(address feeCollector, uint256 fee) external onlyDcaManager {
    function _transferFee(IERC20 token, uint256 fee) internal {
        token.safeTransfer(s_feeCollector, fee);

        // bool feeTransferSuccess = IERC20(i_stableToken).safeTransfer(s_feeCollector, fee);
        // if (!feeTransferSuccess) revert TokenHandler__FeeTransferFailed(s_feeCollector, i_stableToken, fee);
    }
}
