// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {TropykusDocHandler} from "./TropykusDocHandler.sol";
import {TokenLending} from "./TokenLending.sol";
import {PurchaseMoc} from "src/PurchaseMoc.sol";
import {IkDocToken} from "./interfaces/IkDocToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TropykusDocHandlerMoc
 * @notice This contract handles swaps of DOC for rBTC directly redeeming the latter from the MoC contract
 */
contract TropykusDocHandlerMoc is TropykusDocHandler, PurchaseMoc {
    using SafeERC20 for IERC20;

    /**
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param kDocTokenAddress the address of Tropykus' kDOC token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     * @param feeSettings the settings to calculate the fees charged by the protocol
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address kDocTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        address mocProxyAddress,
        FeeSettings memory feeSettings
    )
        TropykusDocHandler(
            dcaManagerAddress,
            docTokenAddress,
            kDocTokenAddress,
            minPurchaseAmount,
            feeCollector,
            feeSettings
        )
        /*dcaManagerAddress, */
        PurchaseMoc(docTokenAddress, mocProxyAddress /*, feeSettings*/ )
    {}

    /**
     * @notice Override the _redeemDoc function to resolve ambiguity between parent contracts
     * @param user The address of the user for whom DOC is being redeemed
     * @param amount The amount of DOC to redeem
     */
    function _redeemDoc(address user, uint256 amount)
        internal
        override(TropykusDocHandler, PurchaseMoc)
        returns (uint256)
    {
        // Call TropykusDocHandler's version of _redeemDoc
        return TropykusDocHandler._redeemDoc(user, amount);
    }

    /**
     * @notice Override the _batchRedeemDoc function to resolve ambiguity between parent contracts
     * @param users The array of user addresses for whom DOC is being redeemed
     * @param purchaseAmounts The array of amounts of DOC to redeem for each user
     * @param totalDocAmountToSpend The total amount of DOC to redeem
     */
    function _batchRedeemDoc(address[] memory users, uint256[] memory purchaseAmounts, uint256 totalDocAmountToSpend)
        internal
        override(TropykusDocHandler, PurchaseMoc)
    {
        // Call TropykusDocHandler's version of _batchRedeemDoc
        TropykusDocHandler._batchRedeemDoc(users, purchaseAmounts, totalDocAmountToSpend);
    }
}
