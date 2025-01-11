// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
// import {TokenHandler} from "./TokenHandler.sol";
// // import {ISovrynDocLending} from "./interfaces/ISovrynDocLending.sol";
// import {IiSusdToken} from "./interfaces/IiSusdToken.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {TokenLending} from "src/TokenLending.sol";

// /**
//  * @title SovrynDocHandler
//  * @notice This abstract contract contains the DOC related functions that are common regardless of the method used to swap DOC for rBTC
//  */
// abstract contract SovrynDocHandler is TokenHandler, TokenLending /*, ISovrynDocLending*/ {
//     using SafeERC20 for IERC20;

//     //////////////////////
//     // State variables ///
//     //////////////////////
//     // IERC20 public immutable i_docToken;
//     IiSusdToken public immutable i_iSusdToken;
//     mapping(address user => uint256 balance) internal s_iSusdBalances;
//     uint256 constant EXCHANGE_RATE_DECIMALS = 1e18;

//     /**
//      * @notice the contract is ownable and after deployment its ownership shall be transferred to the wallet associated to the CRON job
//      * @notice the DCA contract inherits from OZ's Ownable, which is the secure, standard way to handle ownership
//      * @param dcaManagerAddress the address of the DCA Manager contract
//      * @param docTokenAddress the address of the Dollar On Chain token on the blockchain of deployment
//      * @param iSusdTokenAddress the address of Tropykus' iSusd token contract
//      * @param minPurchaseAmount  the minimum amount of DOC for periodic purchases
//      * @param feeCollector the address of to which fees will sent on every purchase
//      * @param feeSettings struct with the settings for fee calculations
//      */
//     constructor(
//         address dcaManagerAddress,
//         address docTokenAddress,
//         address iSusdTokenAddress,
//         uint256 minPurchaseAmount,
//         address feeCollector,
//         FeeSettings memory feeSettings
//     )
//         TokenHandler(dcaManagerAddress, docTokenAddress, minPurchaseAmount, feeCollector, feeSettings)
//         TokenLending(EXCHANGE_RATE_DECIMALS)
//     {
//         i_iSusdToken = IiSusdToken(iSusdTokenAddress);
//     }

//     /**
//      * @notice deposit the full token amount for DCA on the contract
//      * @param user: the address of the user making the deposit
//      * @param depositAmount: the amount to deposit
//      */
//     function depositToken(address user, uint256 depositAmount)
//         public
//         override(TokenHandler, ITokenHandler)
//         onlyDcaManager
//     {
//         super.depositToken(user, depositAmount);
//         if (i_stableToken.allowance(address(this), address(i_iSusdToken)) < depositAmount) {
//             bool approvalSuccess = i_stableToken.approve(address(i_iSusdToken), depositAmount);
//             if (!approvalSuccess) revert TokenLending__LendingTokenApprovalFailed(user, depositAmount);
//         }
//         uint256 previSusdBalance = i_iSusdToken.balanceOf(address(this));
//         i_iSusdToken.mint(address(this), depositAmount);
//         uint256 postiSusdBalance = i_iSusdToken.balanceOf(address(this));
//         s_iSusdBalances[user] += postiSusdBalance - previSusdBalance;
//     }

//     /**
//      * @notice withdraw the token amount sending it back to the user's address
//      * @param user: the address of the user making the withdrawal
//      * @param withdrawalAmount: the amount to withdraw
//      */
//     function withdrawToken(address user, uint256 withdrawalAmount)
//         public
//         override(TokenHandler, ITokenHandler)
//         onlyDcaManager
//     {
//         uint256 docInTropykus = _lendingTokenToDoc(s_iSusdBalances[user], i_iSusdToken.tokenPrice());
//         if (docInTropykus < withdrawalAmount) {
//             revert TokenLending__WithdrawalAmountExceedsLendingTokenBalance(user, withdrawalAmount, docInTropykus);
//         }
//         _redeemDoc(user, withdrawalAmount);
//         super.withdrawToken(user, withdrawalAmount);
//     }

//     function getUsersLendingTokenBalance(address user) external view override returns (uint256) {
//         return s_iSusdBalances[user];
//     }

//     function withdrawInterest(address user, uint256 docLockedInDcaSchedules) external override onlyDcaManager {
//         uint256 exchangeRate = i_iSusdToken.tokenPrice();
//         uint256 totalDocInLending = _lendingTokenToDoc(s_iSusdBalances[user], exchangeRate);
//         uint256 docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
//         uint256 iSusdToRepay = docInterestAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
//         // _redeemDoc(user, docInterestAmount);
//         s_iSusdBalances[user] -= iSusdToRepay;
//         i_iSusdToken.burn(address(this), iSusdToRepay);
//         // uint256 returnedAmount = i_iSusdToken.burn(address(this), iSusdToRepay);
//         // if (returnedAmount > docInterestAmount * 99 / 100) emit TokenLending__SuccessfulDocRedemption(user, docInterestAmount, iSusdToRepay);
//         // else revert TokenLending__RedeemUnderlyingFailed(returnedAmount); TODO: check if we just remove this altogether
//         emit TokenLending__SuccessfulInterestWithdrawal(user, docInterestAmount, iSusdToRepay);

//         // bool transferSuccess = i_docToken.safeTransfer(user, docInterestAmount);
//         // if (!transferSuccess) revert TokenLending__InterestWithdrawalFailed(user, docInterestAmount);
//     }

//     function getAccruedInterest(address user, uint256 docLockedInDcaSchedules)
//         external
//         view
//         override
//         onlyDcaManager
//         returns (uint256 docInterestAmount)
//     {
//         uint256 totalDocInLending = _lendingTokenToDoc(s_iSusdBalances[user], i_iSusdToken.tokenPrice());
//         docInterestAmount = totalDocInLending - docLockedInDcaSchedules;
//     }

//     /*//////////////////////////////////////////////////////////////
//                            INTERNAL FUNCTIONS
//     //////////////////////////////////////////////////////////////*/
//     // function _redeemDoc(address buyer, uint256 amount) internal virtual;

//     // function _docToiSusd(uint256 docAmount, uint256 exchangeRate) internal pure returns (uint256 iSusdAmount) {
//     //     iSusdAmount = docAmount * EXCHANGE_RATE_DECIMALS / exchangeRate;
//     // }

//     // function _iSusdToDoc(uint256 iSusdAmount, uint256 exchangeRate) internal pure returns (uint256 docAmount) {
//     //     docAmount = iSusdAmount * exchangeRate / EXCHANGE_RATE_DECIMALS;
//     // }
// }
