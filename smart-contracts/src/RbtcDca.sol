// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

//////////////////////
// Interfaces ////////
//////////////////////
interface DocTokenContract {
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface MocProxyContract {
    function redeemDocRequest(uint256 docAmount) external;
    function redeemFreeDoc(uint256 docAmount) external;
}

/**
 * @title DCA Contract
 * @author Antonio María Rodríguez-Ynyesto Sánchez
 * @notice The DOC deposited in this contract will be used to make periodical rBTC purchases
 * @custom:unaudited This is an unaudited contract
 */
contract RbtcDca is Ownable {
    //////////////////////
    // State variables ///
    //////////////////////
    DocTokenContract immutable i_docTokenContract;
    MocProxyContract immutable i_mocProxyContract;
    mapping(address user => uint256 docBalance) private s_docBalances; // DOC balances deposited by users
    mapping(address user => uint256 purchaseAmount) private s_docPurchaseAmounts; // DOC to spend periodically on rBTC
    mapping(address user => uint256 purchasePeriod) private s_docPurchasePeriods; // Time between purchases
    mapping(address user => uint256 lastPurchaseTimestamp) private s_lastPurchaseTimestamps; // Time between purchases
    mapping(address user => uint256 accumulatedBtc) private s_rbtcBalances; // Accumulated RBTC balance of users
    address[] private s_users; // Users that have deposited DOC in the DCA contract

    //////////////////////
    // Events ////////////
    //////////////////////
    event DocDeposited(address indexed user, uint256 amount);
    event DocWithdrawn(address indexed user, uint256 amount);
    event RbtcBought(address indexed user, uint256 docAmount, uint256 rbtcAmount);
    event rBtcWithdrawn(address indexed user, uint256 rbtcAmount);
    event PurchaseAmountSet(address indexed user, uint256 purchaseAmount);
    event PurchasePeriodSet(address indexed user, uint256 purchasePeriod);

    //////////////////////
    // Errors ////////////
    //////////////////////
    error RbtcDca__DepositAmountMustBeGreaterThanZero();
    error RbtcDca__DocWithdrawalAmountMustBeGreaterThanZero();
    error RbtcDca__DocWithdrawalAmountExceedsBalance();
    error RbtcDca__NotEnoughDocAllowanceForDcaContract();
    error RbtcDca__DocDepositFailed();
    error RbtcDca__DocWithdrawalFailed();
    error RbtcDca__PurchaseAmountMustBeGreaterThanZero();
    error RbtcDca__PurchasePeriodMustBeGreaterThanZero();
    error RbtcDca__PurchaseAmountMustBeLowerThanHalfOfBalance();
    error RbtcDca__RedeemDocRequestFailed();
    error RbtcDca__RedeemFreeDocFailed();
    error RbtcDca__CannotWithdrawRbtcBeforeBuying();
    error RbtcDca__rBtcWithdrawalFailed();
    error RbtcDca__OnlyMocProxyContractCanSendRbtcToDcaContract();
    error RbtcDca__CannotBuyIfPurchasePeriodHasNotElapsed();

    //////////////////////
    // Modifiers /////////
    //////////////////////
    modifier onlyMocProxy() {
        if (msg.sender != address(i_mocProxyContract)) revert RbtcDca__OnlyMocProxyContractCanSendRbtcToDcaContract();
        _;
    }

    //////////////////////
    // Functions /////////
    //////////////////////

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param docTokenAddress: the address of the Dollar On Chain token on the blockchain of deployment
     * @param mocProxyAddress: the address of the MoC proxy contract on the blockchain of deployment
     */
    constructor(address docTokenAddress, address mocProxyAddress) Ownable(msg.sender) {
        i_docTokenContract = DocTokenContract(docTokenAddress);
        i_mocProxyContract = MocProxyContract(mocProxyAddress);
    }

    /**
     * @notice deposit the full DOC amount for DCA on the contract
     * @param depositAmount: the amount of DOC to deposit
     */
    function depositDOC(uint256 depositAmount) external {
        if (depositAmount <= 0) revert RbtcDca__DepositAmountMustBeGreaterThanZero();

        uint256 prevDocBalance = s_docBalances[msg.sender];
        // Update user's DOC balance in the mapping
        s_docBalances[msg.sender] += depositAmount;

        // Transfer DOC from the user to this contract, user must have called the DOC contract's
        // approve function with this contract's address and the amount approved
        if (i_docTokenContract.allowance(msg.sender, address(this)) < depositAmount) {
            revert RbtcDca__NotEnoughDocAllowanceForDcaContract();
        }
        bool depositSuccess = i_docTokenContract.transferFrom(msg.sender, address(this), depositAmount);
        if (!depositSuccess) revert RbtcDca__DocDepositFailed();

        // Add user to users array
        /**
         * @notice every time a user who ran out of deposited DOC makes a new deposit they will be added to the users array, which is filtered in the dApp's back end.
         * Dynamic arrays have 2^256 positions, so repeated addresses are not an issue.
         */
        if (prevDocBalance == 0) s_users.push(msg.sender);

        emit DocDeposited(msg.sender, depositAmount);
    }

    /**
     * @notice withdraw some or all of the DOC previously deposited
     * @param withdrawalAmount: the amount of DOC to withdraw
     */
    function withdrawDOC(uint256 withdrawalAmount) external {
        if (withdrawalAmount <= 0) revert RbtcDca__DocWithdrawalAmountMustBeGreaterThanZero();
        if (withdrawalAmount > s_docBalances[msg.sender]) revert RbtcDca__DocWithdrawalAmountExceedsBalance();

        // Update user's DOC balance in the mapping
        s_docBalances[msg.sender] -= withdrawalAmount;

        // Transfer DOC from this contract back to the user
        bool withdrawalSuccess = i_docTokenContract.transfer(msg.sender, withdrawalAmount);
        if (!withdrawalSuccess) revert RbtcDca__DocWithdrawalFailed();

        emit DocWithdrawn(msg.sender, withdrawalAmount);
    }

    /**
     * @param purchaseAmount: the amount of DOC to swap periodically for rBTC
     * @notice the amount cannot be greater than or equal to half of the deposited amount
     */
    function setPurchaseAmount(uint256 purchaseAmount) external {
        if (purchaseAmount <= 0) revert RbtcDca__PurchaseAmountMustBeGreaterThanZero();
        if (purchaseAmount > s_docBalances[msg.sender] / 2) {
            revert RbtcDca__PurchaseAmountMustBeLowerThanHalfOfBalance();
        } //At least two DCA purchases
        s_docPurchaseAmounts[msg.sender] = purchaseAmount;
        emit PurchaseAmountSet(msg.sender, purchaseAmount);
    }

    /**
     * @param purchasePeriod: the time (in seconds) between rBTC purchases for each user
     * @notice the period
     */
    function setPurchasePeriod(uint256 purchasePeriod) external {
        if (purchasePeriod <= 0) revert RbtcDca__PurchasePeriodMustBeGreaterThanZero();
        s_docPurchasePeriods[msg.sender] = purchasePeriod;
        emit PurchasePeriodSet(msg.sender, purchasePeriod);
    }

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer) external onlyOwner {
        // If the user made their first purchase, check that period has elapsed before making a new purchase
        if (s_rbtcBalances[buyer] > 0) {
            if (block.timestamp - s_lastPurchaseTimestamps[buyer] < s_docPurchasePeriods[buyer]) {
                revert RbtcDca__CannotBuyIfPurchasePeriodHasNotElapsed();
            }
        }

        s_docBalances[buyer] -= s_docPurchaseAmounts[buyer];
        s_lastPurchaseTimestamps[buyer] = block.timestamp;

        // Redeem DOC for rBTC
        (bool success,) = address(i_mocProxyContract).call(
            abi.encodeWithSignature("redeemDocRequest(uint256)", s_docPurchaseAmounts[buyer])
        );
        if (!success) revert RbtcDca__RedeemDocRequestFailed();
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        (success,) = address(i_mocProxyContract).call(
            abi.encodeWithSignature("redeemFreeDoc(uint256)", s_docPurchaseAmounts[buyer])
        );
        if (!success) revert RbtcDca__RedeemFreeDocFailed();
        uint256 balancePost = address(this).balance;

        s_rbtcBalances[buyer] += (balancePost - balancePrev);

        emit RbtcBought(msg.sender, s_docPurchaseAmounts[buyer], balancePost - balancePrev);
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc() external {
        address user = msg.sender;
        uint256 rbtcBalance = s_rbtcBalances[user];
        if (rbtcBalance == 0) revert RbtcDca__CannotWithdrawRbtcBeforeBuying();

        s_rbtcBalances[user] = 0;
        // Transfer RBTC from this contract back to the user
        (bool sent,) = user.call{value: rbtcBalance}("");
        if (!sent) revert RbtcDca__rBtcWithdrawalFailed();
        emit rBtcWithdrawn(user, rbtcBalance);
    }

    //////////////////////
    // Getter functions //
    //////////////////////
    function getDocBalance() external view returns (uint256) {
        return s_docBalances[msg.sender];
    }

    function getRbtcBalance() external view returns (uint256) {
        return s_rbtcBalances[msg.sender];
    }

    function getPurchaseAmount() external view returns (uint256) {
        return s_docPurchaseAmounts[msg.sender];
    }

    function getPurchasePeriod() external view returns (uint256) {
        return s_docPurchasePeriods[msg.sender];
    }

    function getUsers() external view returns (address[] memory) {
        return s_users;
    }

    function getTotalNumberOfDeposits() external view returns (uint256) {
        return s_users.length;
    }

    receive() external payable onlyMocProxy {}
}
