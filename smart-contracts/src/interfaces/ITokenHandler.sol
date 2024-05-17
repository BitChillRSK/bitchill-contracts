// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

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
    event TokenHandler__rBtcWithdrawn(address indexed user, uint256 indexed amount);
    event TokenHandler__RbtcBought(address indexed user, address indexed tokenSpent, uint256 indexed rBtcBought, uint256 amountSpent);

    //////////////////////
    // Errors ////////////
    //////////////////////
    error TokenHandler__DepositAmountMustBeGreaterThanZero();
    error TokenHandler__WithdrawalAmountMustBeGreaterThanZero();
    error TokenHandler__InsufficientTokenAllowance(address token);
    error TokenHandler__TokenDepositFailed(address token);
    error TokenHandler__TokenWithdrawalFailed(address token);
    error TokenHandler__PurchaseAmountMustBeGreaterThanZero();
    error TokenHandler__PurchasePeriodMustBeGreaterThanZero();
    error TokenHandler__PurchaseAmountMustBeLowerThanHalfOfBalance();
    error TokenHandler__NoAccumulatedRbtcToWithdraw();
    error TokenHandler__rBtcWithdrawalFailed();
    error TokenHandler__OnlyDcaManagerCanCall();
    error TokenHandler__RbtcPurchaseFailed(address user, address tokenSpent);
    error TokenHandler__FeeTransferFailed(address feeCollector, address token, uint256 feeAmount);

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
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer, uint256 purchaseAmount) external;

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc(address user) external;

    /**
     * @dev returns the rBTC that has been accumulated by the user through periodical purchases
     */
    function getAccumulatedRbtcBalance() external view returns (uint256);

    /**
     * @dev to comply with ERC165
     */
    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    /**
     * @dev modifies the minimum amount of the token that can be spent in each purchase
     */
    function modifyMinPurchaseAmount(uint256 minPurchaseAmount) external;

    /**
     * @dev returns the minimum amount of the token that can be spent in each purchase
     */
    function getMinPurchaseAmount() external returns (uint256);
}
