// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenHandler
 * @dev Base contract for handling various tokens.
 */
abstract contract TokenHandler is ITokenHandler, Ownable /*, IERC165*/ {
    //////////////////////
    // State variables ///
    //////////////////////
    address public immutable i_stableToken; // The stablecoin token to be deposited
    uint256 internal s_minPurchaseAmount; // The minimum amount of this token for periodic purchases
    address public immutable i_dcaManager; // The DCA manager contract
    mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;

    // Store user DCA details generically
    // mapping(address => DcaDetails) public dcaDetails;

    //////////////////////
    // Modifiers /////////
    //////////////////////
    modifier onlyDcaManager() {
        if (msg.sender != i_dcaManager) revert TokenHandler__OnlyDcaManagerCanCall();
        _;
    }

    constructor(address tokenAddress, uint256 minPurchaseAmount, address dcaManagerAddress) {
        i_stableToken = tokenAddress;
        i_dcaManager = dcaManagerAddress;
        s_minPurchaseAmount = minPurchaseAmount;
    }

    receive() external payable /*onlyMocProxy*/ {} // Cambiar onlyMocProxy por algo que controle que el rbtc venga de fuentes conocidas?

    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param depositAmount: the amount to deposit
     */
    function depositToken(address user, uint256 depositAmount) external override {
        if (depositAmount <= 0) revert TokenHandler__DepositAmountMustBeGreaterThanZero();

        // Transfer the selected token from the user to this contract. The user must have called the token contract's
        // approve function with this contract's address and the amount approved
        if (IERC20(i_stableToken).allowance(user, address(this)) < depositAmount) {
            revert TokenHandler__InsufficientTokenAllowance(i_stableToken);
        }

        bool depositSuccess = IERC20(i_stableToken).transferFrom(user, address(this), depositAmount);
        if (!depositSuccess) revert TokenHandler__TokenDepositFailed(i_stableToken);

        emit TokenHandler__TokenDeposited(i_stableToken, user, depositAmount);
    }

    /**
     * @notice withdraw some or all of the DOC previously deposited
     * @param withdrawalAmount: the amount of DOC to withdraw
     */
    function withdrawToken(address user, uint256 withdrawalAmount) external override {
        if (withdrawalAmount <= 0) revert TokenHandler__WithdrawalAmountMustBeGreaterThanZero();

        // Transfer DOC from this contract back to the user
        bool withdrawalSuccess = IERC20(i_stableToken).transfer(user, withdrawalAmount);
        if (!withdrawalSuccess) revert TokenHandler__TokenWithdrawalFailed(i_stableToken);

        emit TokenHandler__TokenWithdrawn(i_stableToken, user, withdrawalAmount);
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     */
    function withdrawAccumulatedRbtc(address user) external override {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) revert TokenHandler__NoAccumulatedRbtcToWithdraw();

        s_usersAccumulatedRbtc[user] = 0;
        // Transfer RBTC from this contract back to the user
        (bool sent,) = user.call{value: rbtcBalance}("");
        if (!sent) revert TokenHandler__rBtcWithdrawalFailed();
        emit TokenHandler__rBtcWithdrawn(user, rbtcBalance);
    }

    function getAccumulatedRbtcBalance() external view returns (uint256) {
        return s_usersAccumulatedRbtc[msg.sender];
    }

    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        return interfaceID == type(ITokenHandler).interfaceId;
    }

    function modifyMinPurchaseAmount(uint256 minPurchaseAmount) external onlyOwner {
        s_minPurchaseAmount = minPurchaseAmount;
    }

    function getMinPurchaseAmount() external view returns (uint256) {
        return s_minPurchaseAmount;
    }
}
