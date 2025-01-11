// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITokenHandler
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the TokenHandler contract.
 */
interface ITokenHandler {
    //////////////////////
    // Events ////////////
    //////////////////////
    event TokenHandler__TokenDeposited(address indexed token, address indexed user, uint256 indexed amount);
    event TokenHandler__TokenWithdrawn(address indexed token, address indexed user, uint256 indexed amount);

    //////////////////////
    // Errors ////////////
    //////////////////////
    error TokenHandler__InsufficientTokenAllowance(address token);
    // error TokenHandler__TokenDepositFailed(address token);
    // error TokenHandler__TokenWithdrawalFailed(address token);
    error TokenHandler__PurchaseAmountMustBeGreaterThanZero();
    error TokenHandler__PurchasePeriodMustBeGreaterThanZero();
    error TokenHandler__PurchaseAmountMustBeLowerThanHalfOfBalance();

    ///////////////////////////////
    // External functions /////////
    ///////////////////////////////

    /**
     * @notice Deposit a specified amount of a stablecoin into the contract for DCA operations.
     * @param amount The amount of the stablecoin to deposit.
     * @param user The user making the deposit.
     */
    function depositToken(address user, uint256 amount) external;

    /**
     * @notice Withdraw a specified amount of a stablecoin from the contract.
     * @param amount The amount of the stablecoin to withdraw.
     * @param user The user making the withdrawal.
     */
    function withdrawToken(address user, uint256 amount) external;
    /**
     * @dev to comply with ERC165
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    /**
     * @dev modifies the minimum amount of the token that can be spent in each purchase
     */
    function modifyMinPurchaseAmount(uint256 minPurchaseAmount) external;

    /**
     * @dev Returns the minimum amount of the token that can be spent in each purchase.
     * @return The minimum purchase amount in token units.
     */
    function getMinPurchaseAmount() external returns (uint256);
}
