// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {FeeHandler} from "./FeeHandler.sol";
import {IPurchaseRbtc} from "src/interfaces/IPurchaseRbtc.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DcaManagerAccessControl} from "./DcaManagerAccessControl.sol";

/**
 * @title PurchaseMoc
 * @notice This contract handles swaps of DOC for rBTC directly redeeming the latter from the MoC contract
 */
abstract contract PurchaseMoc is FeeHandler, DcaManagerAccessControl, IPurchaseRbtc {
    using SafeERC20 for IERC20;

    //////////////////////
    // State variables ///
    //////////////////////
    IERC20 public immutable i_docToken;
    IMocProxy public immutable i_mocProxy; // TODO: Make immutable again after adapting everything to 0.8.19?
    // address public immutable i_dcaManager; // The DCA manager contract
    mapping(address user => uint256 amount) internal s_usersAccumulatedRbtc;

    // TODO: SEE WHAT TO DO WITH THIS MODIFIER

    //////////////////////
    // Modifiers /////////
    //////////////////////
    // modifier onlyDcaManager() {
    //     if (msg.sender != i_dcaManager) revert( /* TokenHandler__OnlyDcaManagerCanCall*/ );
    //     _;
    // }

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     */
    constructor(
        // address dcaManagerAddress,
        address docTokenAddress,
        // address feeCollector,
        address mocProxyAddress
    ) 
    // FeeSettings memory feeSettings
    /*FeeHandler(feeCollector, feeSettings) DcaManagerAccessControl(dcaManagerAddress)*/
    {
        i_mocProxy = IMocProxy(mocProxyAddress);
        i_docToken = IERC20(docTokenAddress);
        // i_dcaManager = dcaManagerAddress;
    }

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @param purchaseAmount: the amount to spend on rBTC
     * @param purchasePeriod: the period between purchases
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer, bytes32 scheduleId, uint256 purchaseAmount, uint256 purchasePeriod)
        external
        override
        onlyDcaManager
    {
        // Redeem DOC (repaying kDOC)
        purchaseAmount = _redeemDoc(buyer, purchaseAmount); // TODO: Check if this is correct

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(i_docToken, fee);

        // Redeem rBTC repaying DOC
        (uint256 balancePrev, uint256 balancePost) = _redeemRbtc(netPurchaseAmount);

        if (balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit PurchaseRbtc__RbtcBought(
                buyer, address(i_docToken), balancePost - balancePrev, scheduleId, netPurchaseAmount
            );
        } else {
            revert PurchaseRbtc__RbtcPurchaseFailed(buyer, address(i_docToken));
        }
    }

    function batchBuyRbtc(
        address[] memory buyers,
        bytes32[] memory scheduleIds,
        uint256[] memory purchaseAmounts,
        uint256[] memory purchasePeriods
    ) external override onlyDcaManager {
        uint256 numOfPurchases = buyers.length;

        // Calculate net amounts
        (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 totalDocAmountToSpend) =
            _calculateFeeAndNetAmounts(purchaseAmounts, purchasePeriods);

        // Redeem DOC (and repay kDOC)
        _batchRedeemDoc(buyers, purchaseAmounts, totalDocAmountToSpend + aggregatedFee); // total DOC to redeem by repaying kDOC in order to spend it to redeem rBTC is totalDocAmountToSpend + aggregatedFee

        // Charge fees
        _transferFee(i_docToken, aggregatedFee);

        // Redeem DOC for rBTC
        (uint256 balancePrev, uint256 balancePost) = _redeemRbtc(totalDocAmountToSpend);

        if (balancePost > balancePrev) {
            uint256 totalPurchasedRbtc = balancePost - balancePrev;

            for (uint256 i; i < numOfPurchases; ++i) {
                uint256 usersPurchasedRbtc = totalPurchasedRbtc * netDocAmountsToSpend[i] / totalDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedRbtc;
                emit PurchaseRbtc__RbtcBought(
                    buyers[i], address(i_docToken), usersPurchasedRbtc, scheduleIds[i], netDocAmountsToSpend[i]
                );
            }
            emit PurchaseRbtc__SuccessfulRbtcBatchPurchase(
                address(i_docToken), totalPurchasedRbtc, totalDocAmountToSpend
            );
        } else {
            revert PurchaseRbtc__RbtcBatchPurchaseFailed(address(i_docToken));
        }
    }

    /**
     * @notice the user can at any time withdraw the rBTC that has been accumulated through periodical purchases
     * @notice anyone can pay for the transaction to have the rBTC sent to the user
     */
    function withdrawAccumulatedRbtc(address user) external virtual override {
        uint256 rbtcBalance = s_usersAccumulatedRbtc[user];
        if (rbtcBalance == 0) revert PurchaseRbtc__NoAccumulatedRbtcToWithdraw();

        s_usersAccumulatedRbtc[user] = 0;
        // Transfer RBTC from this contract back to the user
        (bool sent,) = user.call{value: rbtcBalance}("");
        if (!sent) revert PurchaseRbtc__rBtcWithdrawalFailed();
        emit PurchaseRbtc__rBtcWithdrawn(user, rbtcBalance);
    }

    function getAccumulatedRbtcBalance() external view override returns (uint256) {
        return s_usersAccumulatedRbtc[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice the guys at Money on Chain mistakenly named their functions as "redeem DOC", when it is rBTC that gets redeemed (by repaying DOC)
     * @param docAmountToSpend the amount of DOC to repay to redeem rBTC
     */
    function _redeemRbtc(uint256 docAmountToSpend) internal returns (uint256, uint256) {
        try i_mocProxy.redeemDocRequest(docAmountToSpend) {}
        catch {
            revert PurchaseRbtc__RedeemDocRequestFailed();
        }
        // i_mocProxy.redeemDocRequest(docAmountToSpend);
        uint256 balancePrev = address(this).balance;
        try i_mocProxy.redeemFreeDoc(docAmountToSpend) {}
        catch {
            revert PurchaseRbtc__RedeemFreeDocFailed();
        }
        uint256 balancePost = address(this).balance;
        return (balancePrev, balancePost);
    }

    // Define abstract functions to be implemented by child contracts
    function _redeemDoc(address buyer, uint256 amount) internal virtual returns (uint256);

    function _batchRedeemDoc(address[] memory buyers, uint256[] memory purchaseAmounts, uint256 totalDocAmountToSpend)
        internal
        virtual
        returns (uint256);

    // function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods)
    //     internal
    //     view
    //     virtual
    //     returns (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 totalDocAmountToSpend);
}
