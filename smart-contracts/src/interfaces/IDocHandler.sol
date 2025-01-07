// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./ITokenHandler.sol";

/**
 * @title IDocHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DocHandler contract.
 */
// TODO: create ITokenLendingHandler and rename this to ITropykusDocHandler?
interface IDocHandler is ITokenHandler {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DocHandler__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );
    event DocHandler__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed kDocRepayed);
    event DocHandler__DocRedeemedKdocRepayed(address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed);
    event DocHandler__DocRedeemediSusdRepayed(address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed);
    event DocHandler__SuccessfulInterestWithdrawal(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DocHandler__DocRedeemAmountExceedsBalance(uint256 redeemAmount, uint256 balance);
    // error DocHandler__InterestWithdrawalFailed(address user, uint256 interestAmount);
    error DocHandler__kDocApprovalFailed(address user, uint256 depositAmount);
    error DocHandler__iSusdApprovalFailed(address user, uint256 depositAmount);
    error DocHandler__WithdrawalAmountExceedsKdocBalance(address user, uint256 withdrawalAmount, uint256 balance);
    error DocHandler__WithdrawalAmountExceedsiSusdBalance(address user, uint256 withdrawalAmount, uint256 balance);
    error DocHandler__IsusdToRepayExceedsUsersBalance(address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance);
    error DocHandler__KdocToRepayExceedsUsersBalance(address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance);
    error DocHandler__RedeemUnderlyingFailed(uint256 errorCode);
    error DocHandler__BatchRedeemDocFailed();

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the lending token balance of the user
     * @param user The user whose balance is checked
     */
    function getUsersLendingTokenBalance(address user) external view returns (uint256);

    /**
     * @dev Withdraws the interest earned for a user.
     * @notice This function needs to be in this interface (even though it is not implemented in the TokenHandler abstract contract) because it is called by the DCA Manager contract
     * @param user The address of the user withdrawing the interest.
     * @param tokenLockedInDcaSchedules The amount of stablecoin locked in DCA schedules by the user.
     */
    function withdrawInterest(address user, uint256 tokenLockedInDcaSchedules) external; // TODO: check if this should go here

    /**
     * @dev Checks the interest earned by a user in total.
     * @notice This function needs to be in this interface (even though it is not implemented in the TokenHandler abstract contract) because it is called by the DCA Manager contract
     * @param user The address of the user.
     * @param tokenLockedInDcaSchedules The amount of stablecoin locked in DCA schedules by the user in total.
     */
    function getAccruedInterest(address user, uint256 tokenLockedInDcaSchedules) external returns (uint256);
}
