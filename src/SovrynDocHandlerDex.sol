// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {ISovrynDocLending} from "./interfaces/ISovrynDocLending.sol";
import {TokenHandler} from "./TokenHandler.sol";
import {PurchaseUniswap} from "./PurchaseUniswap.sol";
import {SovrynDocHandler} from "./SovrynDocHandler.sol";
import {IPurchaseUniswap} from "./interfaces/IPurchaseUniswap.sol";
import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
import {IWRBTC} from "./interfaces/IWRBTC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {ICoinPairPrice} from "./interfaces/ICoinPairPrice.sol";

/**
 * @title SovrynDocHandlerDex
 * @dev Implementation of the ISovrynDocHandlerDex interface.
 */
contract SovrynDocHandlerDex is SovrynDocHandler, PurchaseUniswap {
    using SafeERC20 for IERC20;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param iSusdTokenAddress the address of Sovryn' iSUSD token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param feeCollector the address of to which fees will sent on every purchase
     * @param feeSettings struct with the settings for fee calculations
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress, // TODO: modify this to passing the interface
        address iSusdTokenAddress, // TODO: modify this to passing the interface
        UniswapSettings memory uniswapSettings,
        uint256 minPurchaseAmount,
        address feeCollector,
        FeeSettings memory feeSettings
    )
        SovrynDocHandler(
            dcaManagerAddress,
            docTokenAddress,
            iSusdTokenAddress,
            minPurchaseAmount,
            feeCollector,
            feeSettings
        )
        PurchaseUniswap(docTokenAddress, uniswapSettings)
    {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Override the _redeemStablecoin function to resolve ambiguity between parent contracts
     * @param user The address of the user for whom DOC is being redeemed
     * @param amount The amount of DOC to redeem
     */
    function _redeemStablecoin(address user, uint256 amount)
        internal
        override(SovrynDocHandler, PurchaseUniswap)
        returns (uint256)
    {
        // Call SovrynDocHandler's version of _redeemStablecoin
        return SovrynDocHandler._redeemStablecoin(user, amount);
    }

    /**
     * @notice Override the _batchRedeemStablecoin function to resolve ambiguity between parent contracts
     * @param users The array of user addresses for whom DOC is being redeemed
     * @param purchaseAmounts The array of amounts of DOC to redeem for each user
     * @param totalDocAmountToSpend The total amount of DOC to redeem
     */
    function _batchRedeemStablecoin(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocAmountToSpend)
        internal
        override(SovrynDocHandler, PurchaseUniswap)
        returns (uint256)
    {
        // Call SovrynDocHandler's version of _batchRedeemStablecoin
        return SovrynDocHandler._batchRedeemStablecoin(users, purchaseAmounts, totalDocAmountToSpend);
    }
}
