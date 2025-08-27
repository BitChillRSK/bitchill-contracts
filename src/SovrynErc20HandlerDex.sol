// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {PurchaseUniswap} from "./PurchaseUniswap.sol";
import {PurchaseRbtc} from "./PurchaseRbtc.sol";
import {SovrynErc20Handler} from "./SovrynErc20Handler.sol";

/**
 * @title SovrynErc20HandlerDex
 * @dev Implementation of the ISovrynErc20HandlerDex interface.
 */
contract SovrynErc20HandlerDex is SovrynErc20Handler, PurchaseUniswap {
    /**
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param stableTokenAddress the address of the stablecoin on the blockchain of deployment
     * @param iSusdTokenAddress the address of Sovryn' iSUSD token contract
     * @param minPurchaseAmount  the minimum amount of stablecoin for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     * @param amountOutMinimumPercent The minimum percentage of rBTC that must be received from the swap (default: 99.7%)
     * @param amountOutMinimumSafetyCheck The safety check percentage for minimum rBTC output (default: 99%)
     */
    constructor(
        address dcaManagerAddress,
        address stableTokenAddress,
        address iSusdTokenAddress,
        UniswapSettings memory uniswapSettings,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings,
        uint256 amountOutMinimumPercent,
        uint256 amountOutMinimumSafetyCheck,
        uint256 exchangeRateDecimals
    )
        SovrynErc20Handler(
            dcaManagerAddress,
            stableTokenAddress,
            iSusdTokenAddress,
            feeCollector,
            feeSettings,
            exchangeRateDecimals
        )
        PurchaseUniswap(
            stableTokenAddress, 
            uniswapSettings, 
            amountOutMinimumPercent, 
            amountOutMinimumSafetyCheck
        )
    {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Override the _redeemStablecoin function to resolve ambiguity between parent contracts
     * @param user The address of the user for whom stablecoin is being redeemed
     * @param amount The amount of stablecoin to redeem
     */
    function _redeemStablecoin(address user, uint256 amount)
        internal
        override(SovrynErc20Handler, PurchaseRbtc)
        returns (uint256)
    {
        // Call SovrynErc20Handler's version of _redeemStablecoin
        return SovrynErc20Handler._redeemStablecoin(user, amount);
    }

    /**
     * @notice Override the _batchRedeemStablecoin function to resolve ambiguity between parent contracts
     * @param users The array of user addresses for whom stablecoin is being redeemed
     * @param purchaseAmounts The array of amounts of stablecoin to redeem for each user
     * @param totalStablecoinAmountToRedeem The total amount of stablecoin to redeem
     */
    function _batchRedeemStablecoin(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalStablecoinAmountToRedeem)
        internal
        override(SovrynErc20Handler, PurchaseRbtc)
        returns (uint256)
    {
        // Call SovrynErc20Handler's version of _batchRedeemStablecoin
        return SovrynErc20Handler._batchRedeemStablecoin(users, purchaseAmounts, totalStablecoinAmountToRedeem);
    }
}
