// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IDocTokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the TokenHandler contract.
 */
interface IDocTokenHandler {
    //////////////////////
    // Events ////////////
    //////////////////////

    //////////////////////
    // Errors ////////////
    //////////////////////
    error DocTokenHandler__RedeemDocRequestFailed();
    error DocTokenHandler__RedeemFreeDocFailed();
    error DocTokenHandler__RedeemAmountExceedsBalance(uint256 redeemAmount);
    
    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositDocAndLend(address user, uint256 depositAmount) external;
}
