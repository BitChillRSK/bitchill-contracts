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
    IMocProxy public immutable i_mocProxyContract;
    IERC20 public immutable i_docTokenContract;
    // IkDocToken public immutable kdocToken;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param minFeeRate the lowest possible fee
     * @param maxFeeRate the highest possible fee
     * @param minAnnualAmount the annual amount below which max fee is applied
     * @param maxAnnualAmount the annual amount above which min fee is applied
     */
    constructor(address docTokenAddress, uint256 minPurchaseAmount, address dcaManagerAddress, address feeCollector, address mocProxyAddress, 
                uint256 minFeeRate, uint256 maxFeeRate, uint256 minAnnualAmount, uint256 maxAnnualAmount)
        Ownable(msg.sender)
        TokenHandler(docTokenAddress, minPurchaseAmount, dcaManagerAddress, feeCollector, minFeeRate, maxFeeRate, minAnnualAmount, maxAnnualAmount)
    {
        i_docTokenContract = IERC20(docTokenAddress);
        i_mocProxyContract = IMocProxy(mocProxyAddress);
    }

    // // DOC-specific functions for interacting with Tropykus
    // function mintKdoc(uint256 depositAmount) external {
    //     require(docToken.approve(tropykusMintAddress, depositAmount), "Approval failed");
    //     // Additional code to interact with the minting function of the Tropykus protocol
    // }

    // function redeemKdoc(uint256 withdrawalAmount) external {
    //     require(kdocToken.approve(tropykusRedeemAddress, withdrawalAmount), "Approval failed");
    //     // Additional code to interact with the redemption function of the Tropykus protocol
    // }

    /**
     * @param buyer: the user on behalf of which the contract is making the rBTC purchase
     * @notice this function will be called periodically through a CRON job running on a web server
     * @notice it is checked that the purchase period has elapsed, as added security on top of onlyOwner modifier
     */
    // function buyRbtc(address buyer, uint256 amount) external override onlyDcaManager {
        
    //     uint256 feeRate = calculateFeeRate(purchaseAmount, purchasePeriod);
    //     uint256 fee = (purchaseAmount * feeRate) / FEE_PERCENTAGE_DIVISOR;
    //     uint256 netPurchaseAmount = purchaseAmount - fee;
    //     _transferFee(s_feeCollectors[token], fee);

    //     // Redeem DOC for rBTC
    //     (bool success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemDocRequest(uint256)", amount));
    //     if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
    //     // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
    //     uint256 balancePrev = address(this).balance;
    //     (success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", amount));
    //     if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
    //     uint256 balancePost = address(this).balance;

    //     if(balancePost > balancePrev) {
    //         s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
    //         emit TokenHandler__RbtcBought(buyer, address(i_docTokenContract), balancePost - balancePrev, amount);
    //     } else {
    //         revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docTokenContract));
    //     }
    // }

    function buyRbtc(address buyer, uint256 purchaseAmount, uint256 purchasePeriod) external override onlyDcaManager {
        
        uint256 fee = _calculateFee(purchaseAmount, purchasePeriod);
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(fee);


        // Redeem DOC for rBTC
        // (bool success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemDocRequest(uint256)", netPurchaseAmount));
        // if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
        try i_mocProxyContract.redeemDocRequest(netPurchaseAmount) {
        } catch {
            revert DocTokenHandler__RedeemDocRequestFailed();
        }
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        // (success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", netPurchaseAmount));
        // if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
        try i_mocProxyContract.redeemFreeDoc(netPurchaseAmount) {
        } catch {
            revert DocTokenHandler__RedeemFreeDocFailed();
        }
        uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit TokenHandler__RbtcBought(buyer, address(i_docTokenContract), balancePost - balancePrev, netPurchaseAmount);
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docTokenContract));
        }
    }

    function batchBuyRbtc(address[] memory buyers, uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods) external override onlyDcaManager {
        
        uint256 numOfPurchases = buyers.length;
        // uint256 fee;
        // uint256 aggregatedFee;
        // uint256[] memory netDocAmountsToSpend = new uint256[](numOfPurchases);
        // uint256 aggregatedDocAmountToSpend;

        // for(uint256 i; i < numOfPurchases; ++i){
        //     fee = _calculateFee(purchaseAmounts[i], purchasePeriods[i]);
        //     aggregatedFee += fee;
        //     netDocAmountsToSpend[i] = purchaseAmounts[i] - fee;
        //     aggregatedDocAmountToSpend += netDocAmountsToSpend[i];
        // }
        
        // _transferFee(aggregatedFee);

        // Calculate fees and net amounts
        (uint256 aggregatedFee, uint256[] memory netDocAmountsToSpend, uint256 aggregatedDocAmountToSpend) = _calculateAndTransferFee(purchaseAmounts, purchasePeriods);



        try i_mocProxyContract.redeemDocRequest(aggregatedDocAmountToSpend) {
        } catch {
            revert DocTokenHandler__RedeemDocRequestFailed();
        }
        uint256 balancePrev = address(this).balance;
        try i_mocProxyContract.redeemFreeDoc(aggregatedDocAmountToSpend) {
        } catch {
            revert DocTokenHandler__RedeemFreeDocFailed();
        }
        uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            uint256 totalPurchasedRbtc = balancePrev - balancePost;

            for(uint256 i; i < numOfPurchases; ++i){
                uint256 usersPurchasedRbtc = totalPurchasedRbtc * netDocAmountsToSpend[i] / aggregatedDocAmountToSpend;
                s_usersAccumulatedRbtc[buyers[i]] += usersPurchasedRbtc;
                emit TokenHandler__RbtcBought(buyers[i], address(i_docTokenContract), usersPurchasedRbtc, netDocAmountsToSpend[i]);
            }
            emit TokenHandler__SuccessfulRbtcBatchPurchase(address(i_docTokenContract), totalPurchasedRbtc, aggregatedDocAmountToSpend);
        } else {
            revert TokenHandler__RbtcBatchPurchaseFailed(address(i_docTokenContract));
        }
    }

    function _calculateAndTransferFee(uint256[] memory purchaseAmounts, uint256[] memory purchasePeriods) internal returns (uint256, uint256[] memory, uint256) {
        uint256 fee;
        uint256 aggregatedFee;
        uint256[] memory netDocAmountsToSpend = new uint256[](purchaseAmounts.length);
        uint256 aggregatedDocAmountToSpend;
        for(uint256 i; i < purchaseAmounts.length; ++i){
            fee = _calculateFee(purchaseAmounts[i], purchasePeriods[i]);
            aggregatedFee += fee;
            netDocAmountsToSpend[i] = purchaseAmounts[i] - fee;
            aggregatedDocAmountToSpend += netDocAmountsToSpend[i];
        }
        
        _transferFee(aggregatedFee);
    return (aggregatedFee, netDocAmountsToSpend, aggregatedDocAmountToSpend);
}

}
