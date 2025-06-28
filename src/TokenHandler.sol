// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {FeeHandler} from "./FeeHandler.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";

/**
 * @title TokenHandler
 * @dev Base contract for handling stablecoins.
 */
abstract contract TokenHandler is ITokenHandler, ERC165, Ownable, FeeHandler, DcaManagerAccessControl {
    using SafeERC20 for IERC20;

    uint256 internal s_minPurchaseAmount; // The minimum amount of this token for periodic purchases
    IERC20 public immutable i_stableToken; // The stablecoin token to be deposited

    /**
     * @param dcaManagerAddress: the address of the DCA manager
     * @param tokenAddress: the address of the token to be deposited
     * @param minPurchaseAmount: the minimum amount of the token to be deposited
     * @param feeCollector: the address of the fee collector
     * @param feeSettings: the fee settings
     */
    constructor(
        address dcaManagerAddress,
        address tokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    ) FeeHandler(feeCollector, feeSettings) DcaManagerAccessControl(dcaManagerAddress) {
        i_stableToken = IERC20(tokenAddress);
        s_minPurchaseAmount = minPurchaseAmount;
        s_feeCollector = feeCollector;
        s_minFeeRate = feeSettings.minFeeRate;
        s_maxFeeRate = feeSettings.maxFeeRate;
        s_purchaseLowerBound = feeSettings.purchaseLowerBound;
        s_purchaseUpperBound = feeSettings.purchaseUpperBound;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice deposit the full token amount for DCA on the contract
     * @notice This function transfers the selected token from the user to this contract. The user must have called the token contract's
     * approve function with this contract's address and the amount approved
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositToken(address user, uint256 depositAmount) public virtual override onlyDcaManager {
        i_stableToken.safeTransferFrom(user, address(this), depositAmount);
        emit TokenHandler__TokenDeposited(address(i_stableToken), user, depositAmount);
    }

    /**
     * @notice withdraw some or all of the stablecoin token previously deposited
     * @notice This function transfers stablecoin token from this contract back to the user
     * @param user: the address of the user making the withdrawal
     * @param withdrawalAmount: the amount of stablecoin token to withdraw
     */
    function withdrawToken(address user, uint256 withdrawalAmount) public virtual override onlyDcaManager {
        i_stableToken.safeTransfer(user, withdrawalAmount);
        emit TokenHandler__TokenWithdrawn(address(i_stableToken), user, withdrawalAmount);
    }

    /**
     * @notice check if the contract supports an interface
     * @param interfaceID: the interface ID to check
     * @return true if the contract supports the interface, false otherwise
     */
    function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
        return interfaceID == type(ITokenHandler).interfaceId || super.supportsInterface(interfaceID);
    }

    /**
     * @notice modify the minimum purchase amount
     * @param minPurchaseAmount: the new minimum purchase amount
     */
    function modifyMinPurchaseAmount(uint256 minPurchaseAmount) external override onlyOwner {
        s_minPurchaseAmount = minPurchaseAmount;
        emit TokenHandler__MinPurchaseAmountModified(minPurchaseAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice get the minimum purchase amount
     * @return the minimum purchase amount
     */
    function getMinPurchaseAmount() external view returns (uint256) {
        return s_minPurchaseAmount;
    }
}
