// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDcaManager} from "./interfaces/IDcaManager.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {ITokenLending} from "./interfaces/ITokenLending.sol";
import {OperationsAdmin} from "./OperationsAdmin.sol";
import {IPurchaseRbtc} from "src/interfaces/IPurchaseRbtc.sol";

/**
 * @title DCA Manager
 * @author BitChill team: Ynyesto
 * @notice Entry point for the DCA dApp. Create and manage DCA schedules. 
 */
contract DcaManager is IDcaManager, Ownable, ReentrancyGuard {
    
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    OperationsAdmin private s_operationsAdmin;

    /**
     * @notice Each user may create different schedules with one or more stablecoins
     */
    mapping(address user => mapping(address stableCoin => bool isDeposited)) private s_tokenIsDeposited; // User to token deposited flag
    mapping(address user => address[] depositedTokens) private s_usersDepositedTokens;
    mapping(address user => mapping(address tokenDeposited => DcaDetails[] usersDcaSchedules)) private s_dcaSchedules;
    mapping(address user => bool registered) s_userRegistered; // Mapping to check if a user has (or ever had) an open DCA position
    address[] private s_users; // Users that have deposited stablecoins in the DCA dApp
    uint256 private s_minPurchasePeriod; // Minimum time between purchases
    uint256 private s_maxSchedulesPerToken; // Maximum number of schedules per stablecoin

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice validate the schedule index
     * @param user the user address to validate the schedule for
     * @param token the token address
     * @param scheduleIndex the schedule index
     */
    modifier validateScheduleIndex(address user, address token, uint256 scheduleIndex) {
        if (scheduleIndex >= s_dcaSchedules[user][token].length) {
            revert DcaManager__InexistentScheduleIndex();
        }
        _;
    }

    /**
     * @notice only allow swapper role
     */
    modifier onlySwapper() {
        if (!s_operationsAdmin.hasRole(s_operationsAdmin.SWAPPER_ROLE(), msg.sender)) {
            revert DcaManager__UnauthorizedSwapper(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @param operationsAdminAddress the address of the admin operations contract
     * @param minPurchasePeriod the minimum time between purchases (in seconds)
     * @param maxSchedulesPerToken the maximum number of schedules allowed per token
     */
    constructor(address operationsAdminAddress, uint256 minPurchasePeriod, uint256 maxSchedulesPerToken) Ownable() {
        s_operationsAdmin = OperationsAdmin(operationsAdminAddress);
        s_minPurchasePeriod = minPurchasePeriod;
        s_maxSchedulesPerToken = maxSchedulesPerToken;
    }

    /**
     * @notice deposit the full stablecoin amount for DCA on the contract
     * @param token the token address
     * @param scheduleIndex the schedule index
     * @param depositAmount the amount of stablecoin to deposit
     */
    function depositToken(address token, uint256 scheduleIndex, uint256 depositAmount)
        external
        override
        nonReentrant
        validateScheduleIndex(msg.sender, token, scheduleIndex)
    {
        _validateDeposit(token, depositAmount);
        DcaDetails storage dcaSchedule = s_dcaSchedules[msg.sender][token][scheduleIndex];
        dcaSchedule.tokenBalance += depositAmount;
        _handler(token, dcaSchedule.lendingProtocolIndex).depositToken(msg.sender, depositAmount);
        emit DcaManager__TokenBalanceUpdated(token, dcaSchedule.scheduleId, dcaSchedule.tokenBalance);
    }

    /**
     * @param token the token address
     * @param scheduleIndex the schedule index
     * @param purchaseAmount the amount of stablecoin to swap periodically for rBTC
     * @notice the amount cannot be greater than or equal to half of the deposited amount
     */
    function setPurchaseAmount(address token, uint256 scheduleIndex, uint256 purchaseAmount)
        external
        override
        validateScheduleIndex(msg.sender, token, scheduleIndex)
    {
        DcaDetails storage dcaSchedule = s_dcaSchedules[msg.sender][token][scheduleIndex];
        _validatePurchaseAmount(token, purchaseAmount, dcaSchedule.tokenBalance, dcaSchedule.lendingProtocolIndex);
        dcaSchedule.purchaseAmount = purchaseAmount;
        emit DcaManager__PurchaseAmountSet(msg.sender, dcaSchedule.scheduleId, purchaseAmount);
    }

    /**
     * @param token the token address
     * @param scheduleIndex the schedule index
     * @param purchasePeriod the time (in seconds) between rBTC purchases for each user
     * @notice the period
     */
    function setPurchasePeriod(address token, uint256 scheduleIndex, uint256 purchasePeriod)
        external
        override
        validateScheduleIndex(msg.sender, token, scheduleIndex)
    {
        DcaDetails storage dcaSchedule = s_dcaSchedules[msg.sender][token][scheduleIndex];
        _validatePurchasePeriod(purchasePeriod);
        dcaSchedule.purchasePeriod = purchasePeriod;
        emit DcaManager__PurchasePeriodSet(msg.sender, dcaSchedule.scheduleId, purchasePeriod);
    }

    /**
     * @notice deposit the full stablecoin amount for DCA on the contract, set the period and the amount for purchases
     * @param token: the token address of stablecoin to deposit
     * @param depositAmount: the amount of stablecoin to deposit
     * @param purchaseAmount: the amount of stablecoin to swap periodically for rBTC
     * @param purchasePeriod: the time (in seconds) between rBTC purchases for each user
     * @param lendingProtocolIndex: the lending protocol, if any, where the token will be deposited to generate yield
     */
    function createDcaSchedule(
        address token,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod,
        uint256 lendingProtocolIndex
    ) external override {
        _validatePurchasePeriod(purchasePeriod);
        _validateDeposit(token, depositAmount);
        _handler(token, lendingProtocolIndex).depositToken(msg.sender, depositAmount);

        DcaDetails[] storage schedules = s_dcaSchedules[msg.sender][token];
        if (schedules.length == s_maxSchedulesPerToken) {
            revert DcaManager__MaxSchedulesPerTokenReached(token);
        }

        bytes32 scheduleId =
            keccak256(abi.encodePacked(msg.sender, token, block.timestamp, schedules.length));

        DcaDetails memory dcaSchedule = DcaDetails(
            depositAmount,
            purchaseAmount,
            purchasePeriod,
            0, // lastPurchaseTimestamp
            scheduleId,
            lendingProtocolIndex
        );

        _validatePurchaseAmount(token, purchaseAmount, dcaSchedule.tokenBalance, dcaSchedule.lendingProtocolIndex);

        schedules.push(dcaSchedule);
        emit DcaManager__DcaScheduleCreated(
            msg.sender, token, scheduleId, depositAmount, purchaseAmount, purchasePeriod
        );
    }

    /**
     * @notice deposit the full stablecoin amount for DCA on the contract, set the period and the amount for purchases
     * @param token: the token address of stablecoin to deposit
     * @param scheduleIndex: the index of the schedule to create or update
     * @param depositAmount: the amount of stablecoin to add to the existing schedule (final token balance for the schedule is the previous balance + depositAmount)
     * @param purchaseAmount: the amount of stablecoin to swap periodically for rBTC
     * @param purchasePeriod: the time (in seconds) between rBTC purchases for each user
     */
    function updateDcaSchedule(
        address token,
        uint256 scheduleIndex,
        uint256 depositAmount,
        uint256 purchaseAmount,
        uint256 purchasePeriod
    ) external override validateScheduleIndex(msg.sender, token, scheduleIndex) {
        DcaDetails memory dcaSchedule = s_dcaSchedules[msg.sender][token][scheduleIndex];

        if (purchasePeriod > 0) {
            _validatePurchasePeriod(purchasePeriod);
            dcaSchedule.purchasePeriod = purchasePeriod;
        }
        if (depositAmount > 0) {
            _validateDeposit(token, depositAmount);
            dcaSchedule.tokenBalance += depositAmount;
            _handler(token, dcaSchedule.lendingProtocolIndex).depositToken(msg.sender, depositAmount);
        }
        if (purchaseAmount > 0) {
            _validatePurchaseAmount(token, purchaseAmount, dcaSchedule.tokenBalance, dcaSchedule.lendingProtocolIndex);
            dcaSchedule.purchaseAmount = purchaseAmount;
        }

        s_dcaSchedules[msg.sender][token][scheduleIndex] = dcaSchedule;

        emit DcaManager__DcaScheduleUpdated(
            msg.sender, token, dcaSchedule.scheduleId, depositAmount, purchaseAmount, purchasePeriod
        );
    }

    /**
     * @notice delete a DCA schedule
     * @param token: the token of the schedule to delete
     * @param scheduleId: the id of the schedule to delete
     */
    function deleteDcaSchedule(address token, bytes32 scheduleId) external override nonReentrant {
        DcaDetails[] storage schedules = s_dcaSchedules[msg.sender][token];

        uint256 scheduleIndex;
        bool found = false;

        // Find the schedule by scheduleId
        for (uint256 i = 0; i < schedules.length; i++) {
            if (schedules[i].scheduleId == scheduleId) {
                scheduleIndex = i;
                found = true;
                break;
            }
        }

        if (!found) revert DcaManager__InexistentScheduleId();

        // Store the balance and scheduleId before modifying the array
        uint256 tokenBalance = schedules[scheduleIndex].tokenBalance;
        uint256 lendingProtocolIndex = schedules[scheduleIndex].lendingProtocolIndex;

        // Remove the schedule
        uint256 lastIndex = schedules.length - 1;
        if (scheduleIndex != lastIndex) {
            // Overwrite the schedule getting deleted with the one in the last index
            schedules[scheduleIndex] = schedules[lastIndex];
        }
        // Remove the last schedule
        schedules.pop();

        // Withdraw all balance
        if (tokenBalance > 0) {
            _handler(token, lendingProtocolIndex).withdrawToken(msg.sender, tokenBalance);
        }

        emit DcaManager__DcaScheduleDeleted(msg.sender, token, scheduleId, tokenBalance);
    }

    /**
     * @notice withdraw amount for DCA from the contract
     * @param token: the token to withdraw
     * @param scheduleIndex: the index of the schedule to withdraw from
     * @param withdrawalAmount: the amount to withdraw
     */
    function withdrawToken(address token, uint256 scheduleIndex, uint256 withdrawalAmount)
        external
        override
        nonReentrant
    {
        _withdrawToken(token, scheduleIndex, withdrawalAmount);
    }

    /**
     * @notice buy rBTC for a user
     * @param buyer: the address of the user
     * @param token: the token to buy rBTC with
     * @param scheduleIndex: the index of the schedule to buy rBTC from
     * @param scheduleId: the id of the schedule to buy rBTC from
     */
    function buyRbtc(address buyer, address token, uint256 scheduleIndex, bytes32 scheduleId)
        external
        override
        nonReentrant
        onlySwapper
    {
        (uint256 purchaseAmount, uint256 lendingProtocolIndex) =
            _rBtcPurchaseChecksEffects(buyer, token, scheduleIndex, scheduleId);

        IPurchaseRbtc(address(_handler(token, lendingProtocolIndex))).buyRbtc(
            buyer, scheduleId, purchaseAmount
        );
    }

    /**
     * @param buyers the array of addresses of the users on behalf of whom rBTC is going to be bought
     * @notice a buyer may be featured more than once in the buyers array if two or more their schedules are due for a purchase
     * @notice we need to take extra care in the back end to not mismatch a user's address with a wrong DCA schedule
     * @param token the stablecoin that all users in the array will spend to purchase rBTC
     * @param scheduleIndexes the indexes of the DCA schedules that correspond to each user's purchase
     * @param purchaseAmounts the purchase amount that corresponds to each user's purchase
     * @param lendingProtocolIndex the lending protocol to withdraw the tokens from before purchasing
     */
    function batchBuyRbtc(
        address[] memory buyers,
        address token,
        uint256[] memory scheduleIndexes,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts,
        uint256 lendingProtocolIndex
    ) external override nonReentrant onlySwapper {
        uint256 numOfPurchases = buyers.length;
        if (numOfPurchases == 0) revert DcaManager__EmptyBatchPurchaseArrays();
        if (
            numOfPurchases != scheduleIndexes.length || numOfPurchases != scheduleIds.length
                || numOfPurchases != purchaseAmounts.length
        ) revert DcaManager__BatchPurchaseArraysLengthMismatch();
        for (uint256 i; i < numOfPurchases; ++i) {
            /**
             * @notice Update balances and timestamps, returned values are not needed here
             */
            _rBtcPurchaseChecksEffects(buyers[i], token, scheduleIndexes[i], scheduleIds[i]);
        }
        IPurchaseRbtc(address(_handler(token, lendingProtocolIndex))).batchBuyRbtc(
            buyers, scheduleIds, purchaseAmounts
        );
    }

    /**
     * @notice Users can withdraw the rBtc accumulated through all the DCA strategies created using a given stablecoin
     * @param token The token address of the stablecoin
     * @param lendingProtocolIndex The index of the lending protocol where the stablecoin is lent (0 if it is not lent)
     */
    function withdrawRbtcFromTokenHandler(address token, uint256 lendingProtocolIndex) external override nonReentrant {
        IPurchaseRbtc(address(_handler(token, lendingProtocolIndex))).withdrawAccumulatedRbtc(msg.sender);
    }

    /**
     * @notice Withdraw all of the rBTC accumulated by a user through their various DCA strategies
     * @param lendingProtocolIndexes Array of lending protocol indexes where the user has positions
     */
    function withdrawAllAccumulatedRbtc(uint256[] calldata lendingProtocolIndexes) external override nonReentrant {
        address[] memory depositedTokens = s_usersDepositedTokens[msg.sender];
        for (uint256 i; i < depositedTokens.length; ++i) {
            for (uint256 j; j < lendingProtocolIndexes.length; ++j) {
                IPurchaseRbtc handler = IPurchaseRbtc(address(_handler(depositedTokens[i], lendingProtocolIndexes[j])));
                if (handler.getAccumulatedRbtcBalance(msg.sender) == 0) continue;
                handler.withdrawAccumulatedRbtc(msg.sender);
            }
        }
    }

    /**
     * @notice withdraw amount for DCA from the contract, as well as the yield generated across all DCA schedules
     * @param token: the token of which to withdraw the specified amount and yield
     * @param scheduleIndex: the index of the schedule to withdraw from
     * @param withdrawalAmount: the amount to withdraw
     * @param lendingProtocolIndex: the lending protocol index
     */
    function withdrawTokenAndInterest(
        address token,
        uint256 scheduleIndex,
        uint256 withdrawalAmount,
        uint256 lendingProtocolIndex
    ) external override nonReentrant {
        _withdrawToken(token, scheduleIndex, withdrawalAmount);
        _withdrawInterest(token, lendingProtocolIndex);
    }

    /**
     * @dev Users can withdraw the stablecoin interests accrued by the deposits they made
     * @param token The address of the token to withdraw
     * @param lendingProtocolIndexes Array of lending protocol indexes to withdraw interest from
     */
    function withdrawAllAccumulatedInterest(address token, uint256[] calldata lendingProtocolIndexes)
        external
        override
        nonReentrant
    {
        for (uint256 i; i < lendingProtocolIndexes.length; ++i) {
            _withdrawInterest(token, lendingProtocolIndexes[i]);
        }
    }

    /**
     * @notice update the admin operations contract
     * @param operationsAdminAddress: the address of admin operations
     */
    function setOperationsAdmin(address operationsAdminAddress) external override onlyOwner {
        s_operationsAdmin = OperationsAdmin(operationsAdminAddress);
        emit DcaManager__OperationsAdminUpdated(operationsAdminAddress);
    }

    /**
     * @notice modify the minimum period between purchases
     * @param minPurchasePeriod: the new period
     */
    function modifyMinPurchasePeriod(uint256 minPurchasePeriod) external override onlyOwner {
        s_minPurchasePeriod = minPurchasePeriod;
        emit DcaManager__MinPurchasePeriodModified(minPurchasePeriod);
    }

    /**
     * @notice modify the maximum number of schedules per token
     * @param maxSchedulesPerToken: the new maximum number of schedules per token
     */
    function modifyMaxSchedulesPerToken(uint256 maxSchedulesPerToken) external override onlyOwner {
        s_maxSchedulesPerToken = maxSchedulesPerToken;
        emit DcaManager__MaxSchedulesPerTokenModified(maxSchedulesPerToken);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice validate that the purchase amount to be set is valid
     * @param token: the token spent on DCA
     * @param purchaseAmount: the purchase amount to validate
     * @param tokenBalance: the current balance of the token in that DCA schedule
     * @param lendingProtocolIndex: the index of the lending protocol
     */
    function _validatePurchaseAmount(
        address token,
        uint256 purchaseAmount,
        uint256 tokenBalance,
        uint256 lendingProtocolIndex
    ) internal {
        if (purchaseAmount < _handler(token, lendingProtocolIndex).getMinPurchaseAmount()) {
            revert DcaManager__PurchaseAmountMustBeGreaterThanMinimum(token);
        }
        /**
         * @notice Purchase amount must be at least twice the balance of the token in the contract to allow at least two DCA purchases
         */
        if (purchaseAmount > (tokenBalance) / 2) {
            revert DcaManager__PurchaseAmountMustBeLowerThanHalfOfBalance();
        }
    }

    /**
     * @notice validate the purchase period
     * @param purchasePeriod the purchase period to validate
     */
    function _validatePurchasePeriod(uint256 purchasePeriod) internal view {
        if (purchasePeriod < s_minPurchasePeriod) revert DcaManager__PurchasePeriodMustBeGreaterThanMinimum();
    }

    /**
     * @notice deposit the full stablecoin amount for DCA on the contract
     * @param token: the token to deposit
     * @param depositAmount: the amount to deposit
     */
    function _validateDeposit(address token, uint256 depositAmount) internal {
        if (depositAmount == 0) revert DcaManager__DepositAmountMustBeGreaterThanZero();
        if (!s_tokenIsDeposited[msg.sender][token]) {
            s_tokenIsDeposited[msg.sender][token] = true;
            s_usersDepositedTokens[msg.sender].push(token);
        }
        if (!s_userRegistered[msg.sender]) {
            s_userRegistered[msg.sender] = true;
            s_users.push(msg.sender);
        }
    }

    /**
     * @notice get the token handler for a token and lending protocol index
     * @param token: the token
     * @param lendingProtocolIndex: the lending protocol index
     * @return the token handler
     */
    function _handler(address token, uint256 lendingProtocolIndex) internal view returns (ITokenHandler) {
        address tokenHandlerAddress = s_operationsAdmin.getTokenHandler(token, lendingProtocolIndex);
        if (tokenHandlerAddress == address(0)) revert DcaManager__TokenNotAccepted();
        return ITokenHandler(tokenHandlerAddress);
    }

    /**
     * @notice checks and effects of the purchase, before interactions take place
     * @param buyer: the address of the buyer
     * @param token: the token
     * @param scheduleIndex: the index of the schedule
     * @param scheduleId: the id of the schedule
     * @return the purchase amount, purchase period, and lending protocol index
     */
    function _rBtcPurchaseChecksEffects(address buyer, address token, uint256 scheduleIndex, bytes32 scheduleId)
        internal
        returns (uint256, uint256)
    {
        DcaDetails storage dcaSchedule = s_dcaSchedules[buyer][token][scheduleIndex];

        if (scheduleId != dcaSchedule.scheduleId) revert DcaManager__ScheduleIdAndIndexMismatch();

        // @notice: If this is not the first purchase for this schedule, check that period has elapsed before making a new purchase
        uint256 lastPurchaseTimestamp = dcaSchedule.lastPurchaseTimestamp;
        uint256 purchasePeriod = dcaSchedule.purchasePeriod;
        if (lastPurchaseTimestamp > 0 && block.timestamp - lastPurchaseTimestamp < purchasePeriod) {
            revert DcaManager__CannotBuyIfPurchasePeriodHasNotElapsed(
                lastPurchaseTimestamp + purchasePeriod - block.timestamp
            );
        }

        if (dcaSchedule.purchaseAmount > dcaSchedule.tokenBalance) {
            revert DcaManager__ScheduleBalanceNotEnoughForPurchase(scheduleIndex, scheduleId, token, dcaSchedule.tokenBalance);
        }
        dcaSchedule.tokenBalance -= dcaSchedule.purchaseAmount;
        emit DcaManager__TokenBalanceUpdated(token, scheduleId, dcaSchedule.tokenBalance);
        // @notice: this way purchases are possible with the wanted periodicity even if a previous purchase was delayed
        dcaSchedule.lastPurchaseTimestamp += lastPurchaseTimestamp == 0 ? block.timestamp : purchasePeriod; 
        emit DcaManager__LastPurchaseTimestampUpdated(token, scheduleId, dcaSchedule.lastPurchaseTimestamp);

        return (dcaSchedule.purchaseAmount, dcaSchedule.lendingProtocolIndex);
    }

    /**
     * @notice withdraw a token from a DCA schedule
     * @param token: the token to withdraw
     * @param scheduleIndex: the index of the schedule
     * @param withdrawalAmount: the amount to withdraw
     */
    function _withdrawToken(address token, uint256 scheduleIndex, uint256 withdrawalAmount) internal {
        if (withdrawalAmount == 0) revert DcaManager__WithdrawalAmountMustBeGreaterThanZero();
        uint256 tokenBalance = s_dcaSchedules[msg.sender][token][scheduleIndex].tokenBalance;
        if (withdrawalAmount > tokenBalance) {
            revert DcaManager__WithdrawalAmountExceedsBalance(token, withdrawalAmount, tokenBalance);
        }
        DcaDetails storage dcaSchedule = s_dcaSchedules[msg.sender][token][scheduleIndex];
        dcaSchedule.tokenBalance -= withdrawalAmount;
        _handler(token, dcaSchedule.lendingProtocolIndex).withdrawToken(msg.sender, withdrawalAmount);
        emit DcaManager__TokenBalanceUpdated(
            token, dcaSchedule.scheduleId, s_dcaSchedules[msg.sender][token][scheduleIndex].tokenBalance
        );
    }

    /**
     * @notice withdraw interest from a lending protocol
     * @param token: the token to withdraw interest from
     * @param lendingProtocolIndex: the lending protocol index
     */
    function _withdrawInterest(address token, uint256 lendingProtocolIndex) internal {
        _checkTokenYieldsInterest(token, lendingProtocolIndex);
        ITokenHandler tokenHandler = _handler(token, lendingProtocolIndex);
        DcaDetails[] memory dcaSchedules = s_dcaSchedules[msg.sender][token];
        uint256 lockedTokenAmount;
        for (uint256 i; i < dcaSchedules.length; ++i) {
            if (dcaSchedules[i].lendingProtocolIndex == lendingProtocolIndex) {
                lockedTokenAmount += dcaSchedules[i].tokenBalance;
            }
        }
        ITokenLending(address(tokenHandler)).withdrawInterest(msg.sender, lockedTokenAmount);
    }

    /**
     * @notice check if a token yields interest
     * @param token: the token to check
     * @param lendingProtocolIndex: the lending protocol index
     */
    function _checkTokenYieldsInterest(address token, uint256 lendingProtocolIndex) internal view {
        bytes32 protocolNameHash =
            keccak256(abi.encodePacked(s_operationsAdmin.getLendingProtocolName(lendingProtocolIndex)));
        if (protocolNameHash == keccak256(abi.encodePacked(""))) revert DcaManager__TokenDoesNotYieldInterest(token);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice get all DCA schedules for the caller
     * @param token: the token to get schedules for
     * @return the DCA schedules
     */
    function getMyDcaSchedules(address token) external view override returns (DcaDetails[] memory) {
        return getDcaSchedules(msg.sender, token);
    }

    /**
     * @notice get all DCA schedules for a specific user
     * @param user: the user to get schedules for
     * @param token: the token to get schedules for
     * @return the DCA schedules
     */
    function getDcaSchedules(address user, address token) public view override returns (DcaDetails[] memory) {
        return s_dcaSchedules[user][token];
    }

    /**
     * @notice get the token balance for a DCA schedule (caller's schedule)
     * @param token: the token to get the balance for
     * @param scheduleIndex: the index of the schedule
     * @return the token balance
     */
    function getMyScheduleTokenBalance(address token, uint256 scheduleIndex)
        external
        view
        override
        returns (uint256)
    {
        return getScheduleTokenBalance(msg.sender, token, scheduleIndex);
    }

    /**
     * @notice get the token balance for a DCA schedule
     * @param user: the user to get the balance for
     * @param token: the token to get the balance for
     * @param scheduleIndex: the index of the schedule
     * @return the token balance
     */
    function getScheduleTokenBalance(address user, address token, uint256 scheduleIndex)
        public
        view
        override
        validateScheduleIndex(user, token, scheduleIndex)
        returns (uint256)
    {
        return s_dcaSchedules[user][token][scheduleIndex].tokenBalance;
    }

    /**
     * @notice get the purchase amount for a DCA schedule (caller's schedule)
     * @param token: the token to get the purchase amount for
     * @param scheduleIndex: the index of the schedule
     * @return the purchase amount
     */
    function getMySchedulePurchaseAmount(address token, uint256 scheduleIndex)
        external
        view
        override
        returns (uint256)
    {
        return getSchedulePurchaseAmount(msg.sender, token, scheduleIndex);
    }

    /**
     * @notice get the purchase amount for a DCA schedule
     * @param user: the user to get the purchase amount for
     * @param token: the token to get the purchase amount for
     * @param scheduleIndex: the index of the schedule
     * @return the purchase amount
     */
    function getSchedulePurchaseAmount(address user, address token, uint256 scheduleIndex)
        public
        view
        override
        validateScheduleIndex(user, token, scheduleIndex)
        returns (uint256)
    {
        return s_dcaSchedules[user][token][scheduleIndex].purchaseAmount;
    }

    /**
     * @notice get the purchase period for a DCA schedule (caller's schedule)
     * @param token: the token to get the purchase period for
     * @param scheduleIndex: the index of the schedule
     * @return the purchase period
     */
    function getMySchedulePurchasePeriod(address token, uint256 scheduleIndex)
        external
        view
        override
        returns (uint256)
    {
        return getSchedulePurchasePeriod(msg.sender, token, scheduleIndex);
    }

    /**
     * @notice get the purchase period for a DCA schedule
     * @param user: the user to get the purchase period for
     * @param token: the token to get the purchase period for
     * @param scheduleIndex: the index of the schedule
     * @return the purchase period
     */
    function getSchedulePurchasePeriod(address user, address token, uint256 scheduleIndex)
        public
        view
        override
        validateScheduleIndex(user, token, scheduleIndex)
        returns (uint256)
    {
        return s_dcaSchedules[user][token][scheduleIndex].purchasePeriod;
    }

    /**
     * @notice get the schedule id for a DCA schedule (caller's schedule)
     * @param token: the token to get the schedule id for
     * @param scheduleIndex: the index of the schedule
     * @return the schedule id
     */
    function getMyScheduleId(address token, uint256 scheduleIndex) external view override returns (bytes32) {
        return getScheduleId(msg.sender, token, scheduleIndex);
    }

    /**
     * @notice get the schedule id for a DCA schedule
     * @param user: the user to get the schedule id for
     * @param token: the token to get the schedule id for
     * @param scheduleIndex: the index of the schedule
     * @return the schedule id
     */
    function getScheduleId(address user, address token, uint256 scheduleIndex)
        public
        view
        override
        validateScheduleIndex(user, token, scheduleIndex)
        returns (bytes32)
    {
        return s_dcaSchedules[user][token][scheduleIndex].scheduleId;
    }

    /**
     * @notice get all users
     * @return the users
     */
    function getUsers() external view override returns (address[] memory) {
        return s_users;
    }

    /**
     * @notice get a user at a specific index
     * @param i: the index of the user
     * @return the user
     */
    function getUserAtIndex(uint256 i) external view override returns (address) {
        if (i >= s_users.length) revert DcaManager__UserIndexOutOfBounds(i);
        return s_users[i];
    }
    /**
     * @notice get the total number of users who ever made a deposit
     * @return the total number of users
     */
    function getAllTimeUserCount() external view override returns (uint256) {
        return s_users.length;
    }

    /**
     * @notice get the admin operations address
     * @return the admin operations address
     */
    function getOperationsAdminAddress() external view override returns (address) {
        return address(s_operationsAdmin);
    }

    /**
     * @notice get the minimum purchase period
     * @return the minimum purchase period
     */
    function getMinPurchasePeriod() external view override returns (uint256) {
        return s_minPurchasePeriod;
    }

    /**
     * @notice get the maximum number of schedules per token
     * @return the maximum number of schedules per token
     */
    function getMaxSchedulesPerToken() external view override returns (uint256) {
        return s_maxSchedulesPerToken;
    }

    /**
     * @notice get the tokens that a user has deposited
     * @param user: the user to get the tokens for
     * @return the tokens
     */
    function getUsersDepositedTokens(address user) external view override returns (address[] memory) {
        return s_usersDepositedTokens[user];
    }

    /**
     * @notice get the interest accrued by the caller with a given stablecoin in a given lending protocol
     * @param token: the token to get the interest for
     * @param lendingProtocolIndex: the lending protocol index to get the interest for
     * @return the interest accrued
     */
    function getMyInterestAccrued(address token, uint256 lendingProtocolIndex) external view override returns (uint256) {
        return getInterestAccrued(msg.sender, token, lendingProtocolIndex);
    }

    /**
     * @notice get the interest accrued by the caller with a given stablecoin in a given lending protocol
     * @param user: the user to get the interest for
     * @param token: the token to get the interest for
     * @param lendingProtocolIndex: the lending protocol index to get the interest for
     * @return the interest accrued
     */
    function getInterestAccrued(address user, address token, uint256 lendingProtocolIndex)
        public
        view
        override
        returns (uint256)
    {
        _checkTokenYieldsInterest(token, lendingProtocolIndex);
        ITokenHandler tokenHandler = _handler(token, lendingProtocolIndex);
        DcaDetails[] memory dcaSchedules = s_dcaSchedules[user][token];
        uint256 lockedTokenAmount;
        for (uint256 i; i < dcaSchedules.length; ++i) {
            if (dcaSchedules[i].lendingProtocolIndex == lendingProtocolIndex) {
                lockedTokenAmount += dcaSchedules[i].tokenBalance;
            }
        }
        return ITokenLending(address(tokenHandler)).getAccruedInterest(user, lockedTokenAmount);
    }
}
