// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./ITokenHandler.sol";

/**
 * @title ISovrynDocHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocHandler contract.
 */
interface ISovrynDocHandler is ITokenHandler {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DocHandler__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );
    event DocHandler__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed kDocRepayed);
    event DocHandler__DocRedeemedKdocRepayed(address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed);
    event DocHandler__SuccessfulInterestWithdrawal(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DocHandler__DocRedeemAmountExceedsBalance(uint256 redeemAmount, uint256 balance);
    // error DocHandler__InterestWithdrawalFailed(address user, uint256 interestAmount);
    error DocHandler__kDocApprovalFailed(address user, uint256 depositAmount);
    error DocHandler__WithdrawalAmountExceedsKdocBalance(address user, uint256 withdrawalAmount, uint256 balance);
    error DocHandler__KdocToRepayExceedsUsersBalance(address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance);
    error DocHandler__RedeemUnderlyingFailed(uint256 errorCode);
    error DocHandler__BatchRedeemDocFailed();

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the kDOC balance of the user
     * @param user The user whose balance is checked
     */
    function getUsersKdocBalance(address user) external returns (uint256);
}
