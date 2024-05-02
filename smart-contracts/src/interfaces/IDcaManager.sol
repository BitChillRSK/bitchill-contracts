// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IDcaManager
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the DcaManager contract.
 */
interface IDcaManager {
    ////////////////////////
    // Type declarations ///
    ////////////////////////
    struct DcaDetails {
        uint256 tokenBalance; // Stablecoin amount deposited by the user
        uint256 purchaseAmount; // Stablecoin amount to spend periodically on rBTC
        uint256 purchasePeriod; // Time between purchases in seconds
        uint256 lastPurchaseTimestamp; // Timestamp of the latest purchase
    }

    //////////////////////
    // Events ////////////
    //////////////////////
    event DcaManager__TokenBalanceUpdated(address indexed token, uint256 indexed scheduleIndex, uint256 amount);
    event DcaManager__TokenWithdrawn(address indexed user, address indexed token, uint256 amount);
    event DcaManager__TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event RbtcBought(address indexed user, uint256 docAmount, uint256 rbtcAmount);
    event rBtcWithdrawn(address indexed user, uint256 rbtcAmount);
    event PurchaseAmountSet(address indexed user, uint256 purchaseAmount);
    event PurchasePeriodSet(address indexed user, uint256 purchasePeriod);
    event DcaManager__newDcaScheduleCreated(
        address indexed user,
        address indexed token,
        uint256 scheduleIndex,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    );

    //////////////////////
    // Errors ////////////
    //////////////////////
    error DcaManager__TokenNotAccepted();
    error DcaManager__DepositAmountMustBeGreaterThanZero();
    error DcaManager__DocWithdrawalAmountMustBeGreaterThanZero();
    error DcaManager__DocWithdrawalAmountExceedsBalance();
    error DcaManager__NotEnoughDocAllowanceForDcaContract();
    error DcaManager__DocDepositFailed();
    error DcaManager__DocWithdrawalFailed();
    error DcaManager__PurchaseAmountMustBeGreaterThanZero();
    error DcaManager__PurchasePeriodMustBeGreaterThanZero();
    error DcaManager__PurchaseAmountMustBeLowerThanHalfOfBalance();
    error DcaManager__RedeemDocRequestFailed();
    error DcaManager__RedeemFreeDocFailed();
    error DcaManager__CannotWithdrawRbtcBeforeBuying();
    error DcaManager__rBtcWithdrawalFailed();
    error DcaManager__OnlyMocProxyCanSendRbtcToDcaContract();
    error DcaManager__CannotBuyIfPurchasePeriodHasNotElapsed();
    error DcaManager__CannotDepositInTropykusMoreThanBalance();
    error DcaManager__DocApprovalForKdocContractFailed();
    error DcaManager__TropykusDepositFailed();
    error DcaManager__WithdrawalAmountExceedsBalance();
    error DcaManager__CannotCreateScheduleSkippingIndexes();

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposit a specified amount of a stablecoin into the contract for DCA operations.
     * @param tokenAddress The token addreess of the stablecoin to deposit.
     * @param scheduleIndex The index of the DCA schedule
     * @param depositAmount The amount of the stablecoin to deposit.
     */
    function depositToken(address tokenAddress, uint256 scheduleIndex, uint256 depositAmount) external;

    /**
     * @notice Withdraw a specified amount of a stablecoin from the contract.
     * @param tokenAddress The token addreess of the stablecoin to deposit.
     * @param scheduleIndex The index of the DCA schedule
     * @param withdrawalAmount The amount of the stablecoin to withdraw.
     */
    function withdrawToken(address tokenAddress, uint256 scheduleIndex, uint256 withdrawalAmount) external;

    /**
     * @notice Deposit a specified amount of a stablecoin into the contract for DCA operations.
     * @param tokenAddress The token addreess of the stablecoin to deposit.
     * @param scheduleIndex The index of the DCA schedule
     * @param depositAmount The amount of the stablecoin to deposit.
     * @param purchaseAmount The amount of to spend periodically in buying rBTC
     * @param purchasePeriod The period for recurrent purchases
     */
    function createOrUpdateDcaSchedule(
        address tokenAddress,
        uint256 scheduleIndex,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    ) external;

    /**
     * @notice Withdraw a specified amount of a stablecoin from the contract.
     * @param tokenAddress The token address of the stablecoin to deposit.
     * @param scheduleIndex The index of the DCA schedule
     * @param purchaseAmount The amount of to spend periodically in buying rBTC
     */
    function setPurchaseAmount(address tokenAddress, uint256 scheduleIndex, uint256 purchaseAmount) external;

    /**
     * @notice Withdraw a specified amount of a stablecoin from the contract.
     * @param tokenAddress The token address of the stablecoin to deposit.
     * @param scheduleIndex The index of the DCA schedule
     * @param purchasePeriod The period for recurrent purchases
     */
    function setPurchasePeriod(address tokenAddress, uint256 scheduleIndex, uint256 purchasePeriod) external;

    /**
     * @notice Withdraw a specified amount of a stablecoin from the contract.
     * @param tokenHandlerFactoryAddress The address of the new token handler factory contract
     */
    function setAdminOperations(address tokenHandlerFactoryAddress) external;

    /**
     * @notice Withdraw the rBtc accumulated by a user through all the DCA strategies created using a given stablecoin
     * @param token The token address of the stablecoin
     */
    function withdrawRbtcFromTokenHandler(address token) external;

    /**
     * @notice Withdraw all of the rBTC accumulated by a user through their various DCA strategies
     */
    function withdrawAllAccmulatedRbtc() external;

    //////////////////////
    // Getter functions //
    //////////////////////

    function getMyDcaPositions(address token) external view returns (DcaDetails[] memory);
    function getScheduleTokenBalance(address token, uint256 scheduleIndex) external view returns (uint256);
    function getSchedulePurchaseAmount(address token, uint256 scheduleIndex) external view returns (uint256);
    function getSchedulePurchasePeriod(address token, uint256 scheduleIndex) external view returns (uint256);
    function ownerGetUsersDcaPositions(address user, address token) external view returns (DcaDetails[] memory);
    function getUsers() external view returns (address[] memory);
    function getTotalNumberOfDeposits() external view returns (uint256);
}
