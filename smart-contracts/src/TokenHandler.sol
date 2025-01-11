// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FeeHandler} from "./FeeHandler.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";

/**
 * @title TokenHandler
 * @dev Base contract for handling various tokens.
 */
abstract contract TokenHandler is ITokenHandler, Ownable, FeeHandler, DcaManagerAccessControl {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    uint256 internal s_minPurchaseAmount; // The minimum amount of this token for periodic purchases
    // mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;
    // uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000; // feeRate will belong to [100, 200], so we need to divide by 10,000 (100 * 100)
    // address public immutable i_stableToken; // The stablecoin token to be deposited
    IERC20 public immutable i_stableToken; // The stablecoin token to be deposited

    // i_yieldsInterest doesn't seem necessary anymore. TODO: REMOVE!!!

    // Store user DCA details generically
    // mapping(address => DcaDetails) public dcaDetails;

    constructor(
        address dcaManagerAddress,
        address tokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    ) FeeHandler(feeCollector, feeSettings) DcaManagerAccessControl(dcaManagerAddress) {
        i_stableToken = IERC20(tokenAddress); // TODO: remove this parameter!!
        s_minPurchaseAmount = minPurchaseAmount;
        s_feeCollector = feeCollector;
        s_minFeeRate = feeSettings.minFeeRate;
        s_maxFeeRate = feeSettings.maxFeeRate;
        s_minAnnualAmount = feeSettings.minAnnualAmount;
        s_maxAnnualAmount = feeSettings.maxAnnualAmount;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable /*onlyMocProxy*/ {} // Cambiar onlyMocProxy por algo que controle que el rbtc venga de fuentes conocidas?

    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositToken(address user, uint256 depositAmount) public virtual override onlyDcaManager {
        // Transfer the selected token from the user to this contract. The user must have called the token contract's
        // approve function with this contract's address and the amount approved
        if (IERC20(i_stableToken).allowance(user, address(this)) < depositAmount) {
            revert TokenHandler__InsufficientTokenAllowance(address(i_stableToken));
        }

        IERC20(i_stableToken).safeTransferFrom(user, address(this), depositAmount);

        // bool depositSuccess = IERC20(i_stableToken).safeTransferFrom(user, address(this), depositAmount);
        // if (!depositSuccess) revert TokenHandler__TokenDepositFailed(i_stableToken);

        emit TokenHandler__TokenDeposited(address(i_stableToken), user, depositAmount);
    }

    /**
     * @notice withdraw some or all of the DOC previously deposited
     * @param withdrawalAmount: the amount of DOC to withdraw
     */
    function withdrawToken(address user, uint256 withdrawalAmount) public virtual override onlyDcaManager {
        // Transfer DOC from this contract back to the user
        IERC20(i_stableToken).safeTransfer(user, withdrawalAmount);

        // bool withdrawalSuccess = IERC20(i_stableToken).safeTransfer(user, withdrawalAmount);
        // if (!withdrawalSuccess) revert TokenHandler__TokenWithdrawalFailed(i_stableToken);

        emit TokenHandler__TokenWithdrawn(address(i_stableToken), user, withdrawalAmount);
    }

    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        return interfaceID == type(ITokenHandler).interfaceId;
    }

    function modifyMinPurchaseAmount(uint256 minPurchaseAmount) external override onlyOwner {
        s_minPurchaseAmount = minPurchaseAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getMinPurchaseAmount() external view returns (uint256) {
        return s_minPurchaseAmount;
    }
}
