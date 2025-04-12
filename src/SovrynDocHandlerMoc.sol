// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {PurchaseMoc} from "./PurchaseMoc.sol";
import {TokenLending} from "./TokenLending.sol";
import {SovrynDocHandler} from "./SovrynDocHandler.sol";
import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
import {IMocProxy} from "./interfaces/IMocProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DocHandler
 * @dev Implementation of the IDocHandler interface.
 * @notice This contract handles swaps of DOC for rBTC directly redeeming the latter from the MoC contract
 */
contract SovrynDocHandlerMoc is SovrynDocHandler, PurchaseMoc {
    using SafeERC20 for IERC20;

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param dcaManagerAddress the address of the DCA Manager contract
     * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
     * @param iSusdTokenAddress the address of Tropykus' iSUSD token contract
     * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
     * @param mocProxyAddress the address of the MoC proxy contract on the blockchain of deployment
     * @param feeSettings the settings to calculate the fees charged by the protocol
     */
    constructor(
        address dcaManagerAddress,
        address docTokenAddress,
        address iSusdTokenAddress,
        uint256 minPurchaseAmount,
        address feeCollector,
        address mocProxyAddress,
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
        PurchaseMoc(docTokenAddress, mocProxyAddress)
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
        override(SovrynDocHandler, PurchaseMoc)
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
        override(SovrynDocHandler, PurchaseMoc)
        returns (uint256)
    {
        // Call SovrynDocHandler's version of _batchRedeemStablecoin
        return SovrynDocHandler._batchRedeemStablecoin(users, purchaseAmounts, totalDocAmountToSpend);
    }
}
