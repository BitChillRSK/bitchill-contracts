// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// import {ITokenHandler} from "./ITokenHandler.sol";

/**
 * @title IDocTokenHandlerDex
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocTokenHandlerDex contract.
 */
interface IDocTokenHandlerDex { /* is ITokenHandler */
    //////////////////////
    // Events ////////////
    //////////////////////
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

    //////////////////////
    // Errors ////////////
    //////////////////////
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
}
