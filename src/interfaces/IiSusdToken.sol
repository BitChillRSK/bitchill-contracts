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
     * @return mintAmount the amount of iSusdC received
     */
    function mint(address receiver, uint256 depositAmount) external returns (uint256 mintAmount);

    /**
     * @dev This function is used to withdraw DOC from the Sovryn protocol and give back the corresponding kDOC
     * @param receiver The account getting the redeemed DOC tokens.
     * @param burnAmount The amount of loan tokens to redeem.
     */
    function burn(address receiver, uint256 burnAmount) external returns (uint256 loanAmountPaid);

    /**
     * @notice Get loan token balance.
     * @return The user's balance of underlying token.
     *
     */
    function assetBalanceOf(address _owner) external view returns (uint256);

    /**
     * @notice Wrapper for internal _profitOf low level function.
     * @param user The user address.
     * @return The profit of a user.
     *
     */
    function profitOf(address user) external view returns (int256);

    /**
     * @dev Returns the balance of the specified address.
     * @param owner The address to query the balance of.
     * @return The balance of the specified address.
     */
    function balanceOf(address owner) external returns (uint256);

    /**
     * @notice Calculates the exchange rate from the underlying DOC to iSusd
     * @return price of iSusd/DOC
     */
    function tokenPrice() external view returns (uint256 price);
}
