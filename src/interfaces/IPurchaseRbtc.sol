// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title IPurchaseRbtc
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @dev Interface for the RBTC purchase related functions
 */
interface IPurchaseRbtc {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PurchaseRbtc__rBtcWithdrawn(address indexed user, uint256 indexed amount);
    event PurchaseRbtc__RbtcBought(
        address indexed user,
        address indexed tokenSpent,
        uint256 rBtcBought,
        bytes32 indexed scheduleId,
        uint256 amountSpent
    );
    event PurchaseRbtc__SuccessfulRbtcBatchPurchase(
        address indexed token, uint256 indexed totalPurchasedRbtc, uint256 indexed totalDocAmountSpent
    );

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error PurchaseRbtc__RedeemDocRequestFailed();
    error PurchaseRbtc__RedeemFreeDocFailed();
    error PurchaseRbtc__NoAccumulatedRbtcToWithdraw();
    error PurchaseRbtc__rBtcWithdrawalFailed();
    error PurchaseRbtc__RbtcPurchaseFailed(address user, address tokenSpent);
    error PurchaseRbtc__RbtcBatchPurchaseFailed(address tokenSpent);

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @param scheduleId: the ID of the DCA schedule to which the purchase belongs
     * @param purchaseAmount: the amount of the token to be spent on BTC
     * @param purchasePeriod: the DCA period of the corresopnding schedule
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer, bytes32 scheduleId, uint256 purchaseAmount, uint256 purchasePeriod) external;

    /**
     * @param buyers: the users on behalf of which the contract is making the rBTC purchases
     * @param scheduleIds: the IDs of the DCA schedules to which the purchases belong
     * @param purchaseAmounts: the amounts of the token to be spent on BTC
     * @param purchasePeriods: the DCA periods of the corresopnding schedule
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts,
        uint256[] memory purchasePeriods
    ) external;

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc(address user) external;

    /**
     * @dev returns the rBTC that has been accumulated by the user through periodical purchases
     */
    function getAccumulatedRbtcBalance() external view returns (uint256);
}
