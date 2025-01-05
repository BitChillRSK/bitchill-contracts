// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IiSusdToken
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the iSusd token contract.
 */
interface IiSusdToken {
    /**
     * @dev This function is used to deposit DOC into the Sovryn protocol and get kDOC in exchange
     *
     * @param depositAmount the amount of DOC to be deposited
     * @param receiver the receiver of iSusdC in return for depositing DOC
     */
    function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount);

    /**
     * @dev This function is used to withdraw DOC from the Sovryn protocol and give back the corresponding kDOC
     * @param receiver The account getting the redeemed DOC tokens.
     * @param burnAmount The amount of loan tokens to redeem.
     */
    function burn(address receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid);

    /**
     * @dev This function is used to withdraw DOC from the Sovryn protocol and give back the corresponding kDOC
     * @param owner the user that owns the DOC deposited into Sovryn
     */
    function getSupplierSnapshotStored(address owner)
        external
        returns (uint256 tokens, uint256 underlyingAmount, uint256 suppliedAt, uint256 promisedSupplyRate);

    /**
     * @dev Returns the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address owner) external returns (uint256);

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() external view returns (uint256);
}
