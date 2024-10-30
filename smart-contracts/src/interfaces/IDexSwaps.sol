// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDexSwaps
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for DEX swapping
 */
interface IDexSwaps {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DexSwaps_NewPathSet(
        address[] indexed intermediateTokens, uint24[] indexed poolFeeRates, bytes indexed newPath
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DexSwaps__WrongNumberOfTokensOrFeeRates(uint256 numberOfIntermediateTokens, uint256 numberOfFeeRates);

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets a new swap path.
     *  @param intermediateTokens The array of intermediate token addresses in the path.
     * @param poolFeeRates The array of pool fees for each swap step.
     */
    function setPurchasePath(address[] memory intermediateTokens, uint24[] memory poolFeeRates) external;
}
