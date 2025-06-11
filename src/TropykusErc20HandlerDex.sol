// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {PurchaseUniswap} from "./PurchaseUniswap.sol";
import {PurchaseRbtc} from "./PurchaseRbtc.sol";
import {TropykusErc20Handler} from "./TropykusErc20Handler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TropykusErc20HandlerDex
 * @notice This contract handles swaps of stablecoin for rBTC using Uniswap V3
 */
contract TropykusErc20HandlerDex is TropykusErc20Handler, PurchaseUniswap {
    using SafeERC20 for IERC20;

    /**
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param kTokenAddress the address of Tropykus' kToken contract
     * @param minPurchaseAmount  the minimum amount of stablecoin for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     * @param amountOutMinimumPercent The minimum percentage of rBTC that must be received from the swap (default: 99.7%)
     * @param amountOutMinimumSafetyCheck The safety check percentage for minimum rBTC output (default: 99%)
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address kTokenAddress,
        UniswapSettings memory uniswapSettings,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        uint256 amountOutMinimumPercent,
        uint256 amountOutMinimumSafetyCheck
    )
        TropykusErc20Handler(
            dcaManagerAddress,
            docTokenAddress,
            kTokenAddress,
            minPurchaseAmount,
            feeCollector,
            feeSettings
        )
        PurchaseUniswap(
            docTokenAddress, 
            uniswapSettings, 
            amountOutMinimumPercent, 
            amountOutMinimumSafetyCheck
        )
    {}

    /**
     * @notice Override the _redeemStablecoin function to resolve ambiguity between parent contracts
     * @param user The address of the user for whom the stablecoin is being redeemed
     * @param amount The amount of stablecoin to redeem
     */
    function _redeemStablecoin(address user, uint256 amount)
        internal
        override(TropykusErc20Handler, PurchaseRbtc)
        returns (uint256)
    {
        // Call TropykusErc20Handler's version of _redeemStablecoin
        return TropykusErc20Handler._redeemStablecoin(user, amount);
    }

    /**
     * @notice Override the _batchRedeemStablecoin function to resolve ambiguity between parent contracts
     * @param users The array of user addresses for whom the stablecoin is being redeemed
     * @param purchaseAmounts The array of amounts of stablecoin to redeem for each user
     * @param totalDocAmountToSpend The total amount of stablecoin to redeem
     */
    function _batchRedeemStablecoin(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocAmountToSpend)
        internal
        override(TropykusErc20Handler, PurchaseRbtc)
        returns (uint256)
    {
        // Call TropykusErc20Handler's version of _batchRedeemStablecoin
        return TropykusErc20Handler._batchRedeemStablecoin(users, purchaseAmounts, totalDocAmountToSpend);
    }
}
