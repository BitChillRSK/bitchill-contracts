// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// import {ITokenHandler} from "./ITokenHandler.sol";

/**
 * @title IDocTokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocTokenHandler contract.
 */
interface IDocTokenHandler { /* is ITokenHandler */
    //////////////////////
    // Events ////////////
    //////////////////////
    event DocTokenHandler__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );
    event DocTokenHandler__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed kDocRepayed);
    event DocTokenHandler__DocRedeemedKdocRepayed(
        address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed
    );

    //////////////////////
    // Errors ////////////
    //////////////////////
    error DocTokenHandler__RedeemDocRequestFailed();
    error DocTokenHandler__RedeemFreeDocFailed();
    error DocTokenHandler__DocRedeemAmountExceedsBalance(uint256 redeemAmount);
    // error DocTokenHandler__InterestWithdrawalFailed(address user, uint256 interestAmount);
    error DocTokenHandler__kDocApprovalFailed(address user, uint256 depositAmount);
    error DocTokenHandler__WithdrawalAmountExceedsKdocBalance(address user, uint256 withdrawalAmount, uint256 balance);
    error DocTokenHandler__KdocToRepayExceedsUsersBalance(
        address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance
    );
    error DocTokenHandler__BatchRedeemDocFailed();
}
