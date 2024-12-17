// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {ITokenHandler} from "./ITokenHandler.sol";
import {IWRBTC} from "./IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "./ICoinPairPrice.sol";

/**
 * @title IDocTokenHandlerDex
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocTokenHandlerDex contract.
 */
interface IDocTokenHandlerDex { /* is ITokenHandler */
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

    event DocTokenHandlerDex__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );
    event DocTokenHandlerDex__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed kDocRepayed);
    event DocTokenHandlerDex__DocRedeemedKdocRepayed(
        address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed
    );
    event DocTokenHandlerDex_NewPathSet(
        address[] indexed intermediateTokens, uint24[] indexed poolFeeRates, bytes indexed newPath
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DocTokenHandlerDex__kDocApprovalFailed(address user, uint256 depositAmount);
    error DocTokenHandlerDex__WithdrawalAmountExceedsKdocBalance(
        address user, uint256 withdrawalAmount, uint256 balance
    );
    error DocTokenHandlerDex__KdocToRepayExceedsUsersBalance(
        address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance
    );
    error DocTokenHandlerDex__WrongNumberOfTokensOrFeeRates(
        uint256 numberOfIntermediateTokens, uint256 numberOfFeeRates
    );
    error DocTokenHandlerDex__DocRedeemAmountExceedsBalance(uint256 redeemAmount);
    error DocTokenHandlerDex__BatchRedeemDocFailed();

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the kDOC balance of the user
     * @param user The user whose balance is checked
     */
    function getUsersKdocBalance(address user) external returns (uint256);

    /**
     * @notice Sets a new swap path.
     *  @param intermediateTokens The array of intermediate token addresses in the path.
     * @param poolFeeRates The array of pool fees for each swap step.
     */
    function setPurchasePath(address[] memory intermediateTokens, uint24[] memory poolFeeRates) external;
}
