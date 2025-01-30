// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./ITokenHandler.sol";

/**
 * @title ITokenLending
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 */
interface ITokenLending is ITokenHandler {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenLending__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed lendingTokenRepayed
    );
    event TokenLending__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed lendingTokenRepayed);
    event TokenLending__DocRedeemedLendingTokenRepayed(
        address indexed user, uint256 docRedeemed, uint256 indexed lendingTokenRepayed
    );
    event TokenLending__SuccessfulInterestWithdrawal(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed lendingTokenRepayed
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error TokenLending__DocRedeemAmountExceedsBalance(uint256 redeemAmount, uint256 balance);
    // error TokenLending__InterestWithdrawalFailed(address user, uint256 interestAmount);
    error TokenLending__LendingTokenApprovalFailed(address user, uint256 depositAmount);
    error TokenLending__WithdrawalAmountExceedsLendingTokenBalance(
        address user, uint256 withdrawalAmount, uint256 balance
    );
    error TokenLending__LendingTokenToRepayExceedsUsersBalance(
        address user, uint256 lendingTokenAmountToRepay, uint256 lendingTokenUserbalance
    );
    // error TokenLending__RedeemUnderlyingFailed(); Tropykus returns an error code when redemptions attempts fail, but Sovryn does not, so this custom error goes to the specific contracts
    error TokenLending__BatchRedeemDocFailed();

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
