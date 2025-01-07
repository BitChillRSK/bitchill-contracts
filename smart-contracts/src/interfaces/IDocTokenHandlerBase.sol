// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IDocTokenHandlerBase
 * @dev Base interface for token handlers.
 */
interface IDocTokenHandlerBase {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DocTokenHandler__SuccessfulDocRedemption(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );
    event DocTokenHandler__SuccessfulBatchDocRedemption(uint256 indexed docRedeemed, uint256 indexed kDocRepayed);
    event DocTokenHandler__DocRedeemedKdocRepayed(
        address indexed user, uint256 docRedeemed, uint256 indexed kDocRepayed
    );
    event DocTokenHandler__SuccessfulInterestWithdrawal(
        address indexed user, uint256 indexed docRedeemed, uint256 indexed kDocRepayed
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DocTokenHandler__RedeemDocRequestFailed();
    error DocTokenHandler__RedeemFreeDocFailed();
    error DocTokenHandler__DocRedeemAmountExceedsBalance(uint256 redeemAmount, uint256 balance);
    error DocTokenHandler__kDocApprovalFailed(address user, uint256 depositAmount);
    error DocTokenHandler__WithdrawalAmountExceedsKdocBalance(address user, uint256 withdrawalAmount, uint256 balance);
    error DocTokenHandler__KdocToRepayExceedsUsersBalance(
        address user, uint256 kDocAmountToRepay, uint256 kDocUserbalance
    );
    error DocTokenHandler__RedeemUnderlyingFailed(uint256 errorCode);
    error DocTokenHandler__BatchRedeemDocFailed();

    /*//////////////////////////////////////////////////////////////
                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Withdraws the interest earned for a user.
     * @notice This function needs to be in this interface (even though it is not implemented in the TokenHandler abstract contract) because it is called by the DCA Manager contract
     * @param user The address of the user withdrawing the interest.
     * @param tokenLockedInDcaSchedules The amount of stablecoin locked in DCA schedules by the user.
     */
    function withdrawInterest(address user, uint256 tokenLockedInDcaSchedules) external; // TODO: check if this should go here

    /**
     * @notice Gets the kDOC balance of the user
     * @param user The user whose balance is checked
     */
    function getUsersLendingTokenBalance(address user) external view returns (uint256);
}
