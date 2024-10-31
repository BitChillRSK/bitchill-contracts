// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {DocHandler} from "./DocHandler.sol";
import {IDocHandlerMoc} from "./interfaces/IDocHandlerMoc.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DocHandler
 * @dev Implementation of the IDocHandler interface.
 * @notice This contract handles swaps of DOC for rBTC directly redeeming the latter from the MoC contract
 */
contract DocHandlerMoc is DocHandler, IDocHandlerMoc {
    using SafeERC20 for IERC20;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param kDocTokenAddress the address of Tropykus' kDOC token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     * @param feeSettings the settings to calculate the fees charged by the protocol
     * @param yieldsInterest whether the token used for DCA yields an interest
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address kDocTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        address mocProxyAddress,
        FeeSettings memory feeSettings,
        bool yieldsInterest
    )
        DocHandler(
            dcaManagerAddress,
            docTokenAddress,
            kDocTokenAddress,
            minPurchaseAmount,
            feeCollector,
            feeSettings,
            yieldsInterest
        )
    {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkDocToken(kDocTokenAddress);
        i_mocProxy = IMocProxy(mocProxyAddress);
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
        _redeemDoc(buyer, purchaseAmount);

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(fee);

        // Redeem rBTC repaying DOC
        (uint256 balancePrev, uint256 balancePost) = _redeemRbtc(netPurchaseAmount);

        // // (bool success,) = address(i_mocProxy).call(abi.encodeWithSignature("redeemDocRequest(uint256)", netPurchaseAmount));
        // // if (!success) revert DocHandler__redeemDocRequestFailed();
        // try i_mocProxy.redeemDocRequest(netPurchaseAmount) {
        // } catch {
        //     revert DocHandler__redeemDocRequestFailed();
        // }
        // // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        // uint256 balancePrev = address(this).balance;
        // // (success,) = address(i_mocProxy).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", netPurchaseAmount));
        // // if (!success) revert DocHandler__RedeemFreeDocFailed();
        // try i_mocProxy.redeemFreeDoc(netPurchaseAmount) {
        // } catch {
        //     revert DocHandler__RedeemFreeDocFailed();
        // }
        // uint256 balancePost = address(this).balance;

        if (balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit TokenHandler__RbtcBought(
                buyer, address(i_docToken), balancePost - balancePrev, scheduleId, netPurchaseAmount
            );
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docToken));
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
        _transferFee(aggregatedFee);

        // Redeem DOC for rBTC
        (uint256 balancePrev, uint256 balancePost) = _redeemRbtc(totalDocAmountToSpend);

        // try i_mocProxy.redeemDocRequest(totalDocAmountToSpend) {
        // } catch {
        //     revert DocHandler__redeemDocRequestFailed();
        // }
        // uint256 balancePrev = address(this).balance;
        // try i_mocProxy.redeemFreeDoc(totalDocAmountToSpend) {
        // } catch {
        //     revert DocHandler__RedeemFreeDocFailed();
        // }
        // uint256 balancePost = address(this).balance;

        if (balancePost > balancePrev) {
            uint256 totalPurchasedRbtc = balancePost - balancePrev;

            for (uint256 i; i < numOfPurchases; ++i) {
                uint256 usersPurchasedRbtc = totalPurchasedRbtc * netDocAmountsToSpend[i] / totalDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedRbtc;
                emit TokenHandler__RbtcBought(
                    buyers[i], address(i_docToken), usersPurchasedRbtc, scheduleIds[i], netDocAmountsToSpend[i]
                );
            }
            emit TokenHandler__SuccessfulRbtcBatchPurchase(
                address(i_docToken), totalPurchasedRbtc, totalDocAmountToSpend
            );
        } else {
            revert TokenHandler__RbtcBatchPurchaseFailed(address(i_docToken));
        }
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
            revert DocHandler__RedeemDocRequestFailed();
        }
        uint256 balancePrev = address(this).balance;
        try i_mocProxy.redeemFreeDoc(docAmountToSpend) {}
        catch {
            revert DocHandler__RedeemFreeDocFailed();
        }
        uint256 balancePost = address(this).balance;
        return (balancePrev, balancePost);
    }
}
