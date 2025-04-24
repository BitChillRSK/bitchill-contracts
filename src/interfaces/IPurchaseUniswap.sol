// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IWRBTC} from "./IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "./ICoinPairPrice.sol";

/**
 * @title IPurchaseUniswap
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for DEX swapping
 */
interface IPurchaseUniswap {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    struct UniswapSettings {
        IWRBTC wrBtcToken;
        ISwapRouter02 swapRouter02;
        address[] swapIntermediateTokens;
        uint24[] swapPoolFeeRates;
        ICoinPairPrice mocOracle;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PurchaseUniswap_NewPathSet(
        address[] indexed intermediateTokens, uint24[] indexed poolFeeRates, bytes indexed newPath
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PurchaseUniswap__WrongNumberOfTokensOrFeeRates(uint256 numberOfIntermediateTokens, uint256 numberOfFeeRates);
    error PurchaseUniswap__AmountOutMinimumPercentTooHigh();
    error PurchaseUniswap__AmountOutMinimumPercentTooLow();
    error PurchaseUniswap__AmountOutMinimumSafetyCheckTooHigh();
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new swap path.
     *  @param intermediateTokens The array of intermediate token addresses in the path.
     * @param poolFeeRates The array of pool fees for each swap step.
     */
    function setPurchasePath(address[] memory intermediateTokens, uint24[] memory poolFeeRates) external;

    /**
     * @notice Set the minimum percentage of rBTC that must be received from the swap.
     * @param amountOutMinimumPercent The minimum percentage of rBTC that must be received from the swap.
     */
    function setAmountOutMinimumPercent(uint256 amountOutMinimumPercent) external;
    
    /**
     * @notice Get the minimum percentage of rBTC that must be received from the swap.
     * @return The minimum percentage of rBTC that must be received from the swap.
     */
    function getAmountOutMinimumPercent() external view returns (uint256);

    /**
     * @notice Set the minimum percentage of rBTC that must be received from the swap.
     * @param amountOutMinimumSafetyCheck The minimum percentage of rBTC that must be received from the swap.
     */
    function setAmountOutMinimumSafetyCheck(uint256 amountOutMinimumSafetyCheck) external;

    /**
     * @notice Get the minimum percentage of rBTC that must be received from the swap.
     * @return The minimum percentage of rBTC that must be received from the swap.
     */
    function getAmountOutMinimumSafetyCheck() external view returns (uint256);
    
}
