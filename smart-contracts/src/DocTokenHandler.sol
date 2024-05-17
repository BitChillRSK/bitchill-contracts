// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {TokenHandler} from "./TokenHandler.sol";
import {IDocTokenHandler} from "./interfaces/IDocTokenHandler.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DocTokenHandler
 * @dev Implementation of the ITokenHandler interface for DOC.
 */
contract DocTokenHandler is TokenHandler, IDocTokenHandler {
    //////////////////////
    // State variables ///
    //////////////////////
    IMocProxy immutable i_mocProxyContract;
    IERC20 public immutable i_docTokenContract;
    // IkDocToken public immutable kdocToken;
    uint256 constant FEE_PERCENTAGE_DIVISOR = 10_000; // feeRate will belong to [100, 200], so we need to divide by 10,000 (100 * 100)

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param docTokenAddress: the address of the Dollar On Chain token on the blockchain of deployment
     * @param minPurchaseAmount:  the minimum amount of DOC for periodic purchases
     * @param dcaManagerAddress: the address of the DCA Manager contract
     * @param mocProxyAddress: the address of the MoC proxy contract on the blockchain of deployment
     */
    constructor(address docTokenAddress, uint256 minPurchaseAmount, address dcaManagerAddress, address mocProxyAddress /*, address feeCollector*/ )
        Ownable(msg.sender)
        TokenHandler(docTokenAddress, minPurchaseAmount, dcaManagerAddress/*, s_minFeeRate, s_maxFeeRate, s_minAnnualAmount, s_maxAnnualAmount*/)
    {
        i_docTokenContract = IERC20(docTokenAddress);
        i_mocProxyContract = IMocProxy(mocProxyAddress);
        s_minFeeRate = 100; // Minimum fee rate in basis points (1%)
        s_maxFeeRate = 200; // Maximum fee rate in basis points (2%)
        s_minAnnualAmount = 1_000 ether; // Spending below 1,000 DOC annually gets the maximum fee rate
        s_maxAnnualAmount = 100_000 ether; // Spending above 100,000 DOC annually gets the minimum fee rate
        // s_feeCollector = feeCollector;
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
    function buyRbtc(address buyer, uint256 amount) external override onlyDcaManager {
        
        uint256 feeRate = calculateFeeRate(purchaseAmount, purchasePeriod);
        uint256 fee = (purchaseAmount * feeRate) / FEE_PERCENTAGE_DIVISOR;
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(s_feeCollectors[token], fee);

        // Redeem DOC for rBTC
        (bool success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemDocRequest(uint256)", amount));
        if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        (success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", amount));
        if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
        uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit TokenHandler__RbtcBought(buyer, address(i_docTokenContract), balancePost - balancePrev, amount);
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docTokenContract));
        }
    }

    function buyRbtc(address buyer, uint256 purchaseAmount, uint256 purchasePeriod) external override onlyDcaManager {
        
        uint256 feeRate = calculateFeeRate(purchaseAmount, purchasePeriod);
        uint256 fee = (purchaseAmount * feeRate) / FEE_PERCENTAGE_DIVISOR;
        uint256 netPurchaseAmount = purchaseAmount - fee;
        _transferFee(s_feeCollector, fee);

        // Redeem DOC for rBTC
        (bool success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemDocRequest(uint256)", netPurchaseAmount));
        if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        (success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", netPurchaseAmount));
        if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
        uint256 balancePost = address(this).balance;

        if(balancePost > balancePrev) {
            s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);
            emit TokenHandler__RbtcBought(buyer, address(i_docTokenContract), balancePost - balancePrev, netPurchaseAmount);
        } else {
            revert TokenHandler__RbtcPurchaseFailed(buyer, address(i_docTokenContract));
        }
    }
}
