// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

//////////////////////
// Interfaces ////////
//////////////////////
interface DocTokenContract {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
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
contract DCAContract is Ownable {
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
    error DepositAmountMustBeGreaterThanZero();
    error DocWithdrawalAmountMustBeGreaterThanZero();
    error DocWithdrawalAmountExceedsBalance();
    error DocDepositFailed();
    error DocWithdrawalFailed();
    error PurchaseAmountMustBeGreaterThanZero();
    error PurchasePeriodMustBeGreaterThanZero();
    error PurchaseAmountMustBeLowerThanHalfOfBalance();
    error RedeemDocRequestFailed();
    error RedeemFreeDocFailed();
    error rBtcWithdrawalFailed();
    error OnlyMocProxyContractCanSendRbtcToDcaContract();
    error CannotBuyIfPurchasePeriodHasNotElapsed();

    //////////////////////
    // Modifiers /////////
    //////////////////////
    modifier onlyMocProxy() {
        if (msg.sender != address(i_mocProxyContract)) revert OnlyMocProxyContractCanSendRbtcToDcaContract();
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
        if (depositAmount <= 0) revert DepositAmountMustBeGreaterThanZero();

        // Transfer DOC from the user to this contract, user must have called the DOC contract's
        // approve function with this contract's address and the amount approved
        bool depositSuccess = i_docTokenContract.transferFrom(msg.sender, address(this), depositAmount);
        if (!depositSuccess) revert DocDepositFailed();

        // Update user's DOC balance in the mapping
        s_docBalances[msg.sender] += depositAmount;

        emit DocDeposited(msg.sender, depositAmount);
    }

    /**
     * @notice withdraw some or all of the DOC previously deposited
     * @param withdrawalAmount: the amount of DOC to withdraw
     */
    function withdrawDOC(uint256 withdrawalAmount) external {
        if (withdrawalAmount <= 0) revert DocWithdrawalAmountMustBeGreaterThanZero();
        if (withdrawalAmount > s_docBalances[msg.sender]) revert DocWithdrawalAmountExceedsBalance();

        // Transfer DOC from this contract back to the user
        bool withdrawalSuccess = i_docTokenContract.transfer(msg.sender, withdrawalAmount);
        if (!withdrawalSuccess) revert DocWithdrawalFailed();

        // Update user's DOC balance in the mapping
        s_docBalances[msg.sender] -= withdrawalAmount;

        emit DocWithdrawn(msg.sender, withdrawalAmount);
    }

    /**
     * @param purchaseAmount: the amount of DOC to swap periodically for rBTC
     * @notice the amount cannot be greater than or equal to half of the deposited amount
     */
    function setPurchaseAmount(uint256 purchaseAmount) external {
        if (purchaseAmount <= 0) revert PurchaseAmountMustBeGreaterThanZero();
        if (purchaseAmount > s_docBalances[msg.sender] / 2) revert PurchaseAmountMustBeLowerThanHalfOfBalance(); //At least two DCA purchases
        s_docPurchaseAmounts[msg.sender] = purchaseAmount;
        emit PurchaseAmountSet(msg.sender, purchaseAmount);
    }

    /**
     * @param purchasePeriod: the time (in seconds) between rBTC purchases for each user
     * @notice the period
     */
    function setPurchasePeriod(uint256 purchasePeriod) external {
        if (purchasePeriod <= 0) revert PurchasePeriodMustBeGreaterThanZero();
        s_docPurchasePeriods[msg.sender] = purchasePeriod;
        emit PurchasePeriodSet(msg.sender, purchasePeriod);
    }

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buy(address buyer) external onlyOwner {
        if (block.timestamp - s_lastPurchaseTimestamps[buyer] < s_docPurchasePeriods[buyer]) {
            revert CannotBuyIfPurchasePeriodHasNotElapsed();
        }

        // Redeem DOC for rBTC
        (bool success,) = address(i_mocProxyContract).call(
            abi.encodeWithSignature("redeemDocRequest(uint256)", s_docPurchaseAmounts[buyer])
        );
        if (!success) revert RedeemDocRequestFailed();
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        (success,) = address(i_mocProxyContract).call(
            abi.encodeWithSignature("redeemFreeDoc(uint256)", s_docPurchaseAmounts[buyer])
        );
        if (!success) revert RedeemFreeDocFailed();
        uint256 balancePost = address(this).balance;

        s_docBalances[buyer] -= s_docPurchaseAmounts[buyer];
        s_rbtcBalances[buyer] += (balancePost - balancePrev);
        s_lastPurchaseTimestamps[buyer] = block.timestamp;

        // Emit event
        emit RbtcBought(msg.sender, s_docPurchaseAmounts[buyer], balancePost - balancePrev);
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc() external {
        // Transfer RBTC from this contract back to the user
        (bool sent,) = msg.sender.call{value: s_rbtcBalances[msg.sender]}("");
        if (!sent) revert rBtcWithdrawalFailed();

        // Update user's RBTC balance in the mapping
        s_rbtcBalances[msg.sender] -= s_rbtcBalances[msg.sender];

        emit rBtcWithdrawn(msg.sender, s_rbtcBalances[msg.sender]);
    }

    //////////////////////
    // Getter functions///
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

    receive() external payable onlyMocProxy {}
}
