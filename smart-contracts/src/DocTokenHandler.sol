// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TokenHandler} from "./TokenHandler.sol";
import {IDocTokenHandler} from "./interfaces/IDocTokenHandler.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title DocTokenHandler
 * @dev Implementation of the ITokenHandler interface for DOC.
 */
contract DocTokenHandler is TokenHandler, IDocTokenHandler {
    //////////////////////
    // State variables ///
    //////////////////////
    IMocProxy public immutable i_mocProxy;
    IERC20 public immutable i_docToken;
    IkDocToken public immutable i_kDocToken;
    mapping(address user => uint256 balance) private s_kDocBalances;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param kDocTokenAddress the address of Tropykus' kDOC token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param minFeeRate the lowest possible fee
     * @param maxFeeRate the highest possible fee
     * @param minAnnualAmount the annual amount below which max fee is applied
     * @param maxAnnualAmount the annual amount above which min fee is applied
     */
    constructor(address dcaManagerAddress, address docTokenAddress, address kDocTokenAddress, uint256 minPurchaseAmount,address feeCollector, address mocProxyAddress, 
                uint256 minFeeRate, uint256 maxFeeRate, uint256 minAnnualAmount, uint256 maxAnnualAmount)
        Ownable(msg.sender)
        TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, minFeeRate, maxFeeRate, minAnnualAmount, maxAnnualAmount)
    {
        i_docToken = IERC20(docTokenAddress);
        i_kDocToken = IkDocToken(kDocTokenAddress);
        i_mocProxy = IMocProxy(mocProxyAddress);
    }
    
    /**
     * @notice deposit the full token amount for DCA on the contract
     * @param user: the address of the user making the deposit
     * @param depositAmount: the amount to deposit
     */
    function depositDocAndLend(address user, uint256 depositAmount) external override onlyDcaManager {
        this.depositToken( user, depositAmount);
        if(i_docToken.allowance(address(this), address(i_kDocToken)) < depositAmount) {
            bool approvalSuccess = i_docToken.approve(address(i_kDocToken), depositAmount);
            require(approvalSuccess, "Approval failed"); // TODO: change this to custom error
        }
        uint256 prevKdocBalance = i_kDocToken.balanceOf(address(this));
        i_kDocToken.mint(depositAmount);
        uint256 postKdocBalance = i_kDocToken.balanceOf(address(this));
        // Aquí asignamos los kDOC recibidos (postkDocBalance - prevkDocBalance) a un mapping hacemos i_kDocToken.transfer(user)
        kDocBalances[user] += postKdocBalance - prevKdocBalance;
    }

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @param purchaseAmount: the amount to spend on rBTC
     * @param purchasePeriod: the period between purchases
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    function buyRbtc(address buyer, uint256 purchaseAmount, uint256 purchasePeriod) external override onlyDcaManager {
        
        // Redeem kDOC for DOC
        _redeemKdoc(purchaseAmount);

        // Charge fee
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(fee);

        // Redeem DOC for rBTC
        (uint256 balancePrev, uint256 balancePost) = _redeemDoc(netPurchaseAmount);

        // // (bool success,) = address(i_mocProxy).call(abi.encodeWithSignature("redeemDocRequest(uint256)", netPurchaseAmount));
        // // if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
        // try i_mocProxy.redeemDocRequest(netPurchaseAmount) {
        // } catch {
        //     revert DocTokenHandler__RedeemDocRequestFailed();
        // }
        // // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        // uint256 balancePrev = address(this).balance;
        // // (success,) = address(i_mocProxy).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", netPurchaseAmount));
        // // if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
        // try i_mocProxy.redeemFreeDoc(netPurchaseAmount) {
        // } catch {
        //     revert DocTokenHandler__RedeemFreeDocFailed();
        // }
        // uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit TokenHandler__RbtcBought(buyer, address(i_docToken), balancePost - balancePrev, netPurchaseAmount);
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docToken));
        }
    }

    function batchBuyRbtc(address[] memory buyers, uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods) external override onlyDcaManager {
        
        uint256 numOfPurchases = buyers.length;

        // Redeem kDOC for DOC
        _redeemKdoc(netDocAmountsToSpend);

        // Calculate net amounts and charge fees
        (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 totalDocAmountToSpend) = _calculateFeeAndNetAmounts(purchaseAmounts, purchasePeriods);
        _transferFee(aggregatedFee);
        
        // Redeem DOC for rBTC
        (uint256 balancePrev, uint256 balancePost) = _redeemDoc(netPurchaseAmount);

        // try i_mocProxy.redeemDocRequest(totalDocAmountToSpend) {
        // } catch {
        //     revert DocTokenHandler__RedeemDocRequestFailed();
        // }
        // uint256 balancePrev = address(this).balance;
        // try i_mocProxy.redeemFreeDoc(totalDocAmountToSpend) {
        // } catch {
        //     revert DocTokenHandler__RedeemFreeDocFailed();
        // }
        // uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            uint256 totalPurchasedRbtc = balancePost - balancePrev;

            for(uint256 i; i < numOfPurchases; ++i){
                uint256 usersPurchasedRbtc = totalPurchasedRbtc * netDocAmountsToSpend[i] / totalDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedRbtc;
                emit TokenHandler__RbtcBought(buyers[i], address(i_docToken), usersPurchasedRbtc, netDocAmountsToSpend[i]);
            }
            emit TokenHandler__SuccessfulRbtcBatchPurchase(address(i_docToken), totalPurchasedRbtc, totalDocAmountToSpend);
        } else {
            revert TokenHandler__RbtcBatchPurchaseFailed(address(i_docToken));
        }
    }

    function _calculateFeeAndNetAmounts(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods) internal view returns (uint256, uint256[] memory, uint256) {
        uint256 fee;
        uint256 aggregatedFee;
        uint256[] memory netDocAmountsToSpend = new uint256[](purchaseAmounts.length);
        uint256 totalDocAmountToSpend;
        for(uint256 i; i < purchaseAmounts.length; ++i){
            fee = _calculateFee(purchaseAmounts[i], purchasePeriods[i]);
            aggregatedFee += fee;
            netDocAmountsToSpend[i] = purchaseAmounts[i] - fee;
            totalDocAmountToSpend += netDocAmountsToSpend[i];
        }        
        return (aggregatedFee, netDocAmountsToSpend, totalDocAmountToSpend);
    }
    
    function _redeemDoc(uint256 docAmountToSpend) internal returns (uint256, uint256) {
        try i_mocProxy.redeemDocRequest(docAmountToSpend) {
        } catch {
            revert DocTokenHandler__RedeemDocRequestFailed();
        }
        uint256 balancePrev = address(this).balance;
        try i_mocProxy.redeemFreeDoc(docAmountToSpend) {
        } catch {
            revert DocTokenHandler__RedeemFreeDocFailed();
        }
        uint256 balancePost = address(this).balance;
        return (balancePrev, balancePost);
    }

    function _redeemKdoc(uint256 amountToRedeem) internal {
        (, uint256 underlyingAmount, ,) = i_kDocToken.getSupplierSnapshotStored(address(this)); // esto devuelve el DOC retirable por la dirección de nuestro contrato en la última actualización de mercado
        require(amountToRedeem <= underlyingAmount, "Cannot withdraw more DOC than balance."); // TODO: change this to custom error
           
        i_kDocToken.redeemUnderlying(amountToRedeem);
    }

    function getUsersKdocBalance(address user) external returns(uint256) {
        return s_kDocBalances[user];
    }

    function withdrawInterest(address user, uint256 lockedDocAmount) external onlyDcaManager {
        uint256 docToRedeem = s_kDocBalances[user].toDoc() - lockedDocAmount; // toDoc() es inventada, buscar función de conversión
        i_kDocToken.redeemUnderlying(docToRedeem);
    }

}
