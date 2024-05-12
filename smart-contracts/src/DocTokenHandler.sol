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

    /**
     * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
     * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
     * @param docTokenAddress: the address of the Dollar On Chain token on the blockchain of deployment
     * @param mocProxyAddress: the address of the MoC proxy contract on the blockchain of deployment
     */
    constructor(address docTokenAddress, address dcaManagerAddress, address mocProxyAddress /*, address _kdocToken*/ )
        Ownable(msg.sender)
        TokenHandler(docTokenAddress, dcaManagerAddress)
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
    function buyRbtc(address buyer, uint256 amount) external override onlyDcaManager {
        // Redeem DOC for rBTC
        (bool success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemDocRequest(uint256)", amount));
        if (!success) revert DocTokenHandler__RedeemDocRequestFailed();
        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        uint256 balancePrev = address(this).balance;
        (success,) = address(i_mocProxyContract).call(abi.encodeWithSignature("redeemFreeDoc(uint256)", amount));
        if (!success) revert DocTokenHandler__RedeemFreeDocFailed();
        uint256 balancePost = address(this).balance;

        s_usersAccumulatedRbtc[buyer] += (balancePost - balancePrev);

        emit TokenHandler__RbtcBought(buyer, amount, balancePost - balancePrev);
    }
}
