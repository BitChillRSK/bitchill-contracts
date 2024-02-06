// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {DCAContract} from "../../src/DCAContract.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// contract Handler is Test {
//     DCAContract public dcaContract;

//     constructor(DecentralizedStableCoin _dsc, DSCEngine _dscEngine) {
//         dsc = _dsc;
//         dscEngine = _dscEngine;
//         address[] memory collateralTokens = dscEngine.getCollateralTokens();
//         weth = ERC20Mock(collateralTokens[0]);
//         wbtc = ERC20Mock(collateralTokens[1]);
//         ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
//     }

//     function despositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         ERC20Mock collateral = _getCollateralTokenFromSeed(collateralSeed);
//         amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

//         vm.startPrank(msg.sender);
//         collateral.mint(msg.sender, amountCollateral);
//         collateral.approve(address(dscEngine), amountCollateral);
//         dscEngine.depositCollateral(address(collateral), amountCollateral);
//         vm.stopPrank();
//         usersWithCollateralDeposited.push(msg.sender);
//     }

//     function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         ERC20Mock collateral = _getCollateralTokenFromSeed(collateralSeed);
//         uint256 maxCollateral = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral));

//         amountCollateral = bound(amountCollateral, 0, maxCollateral);
//         if (amountCollateral == 0) {
//             return;
//         }
//         vm.prank(msg.sender);
//         dscEngine.redeemCollateral(address(collateral), amountCollateral);
//     }

//     function mintDsc(uint256 dscAmount, uint256 addressSeed) public {
//         if (usersWithCollateralDeposited.length == 0) return;
//         address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
//         (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
//         int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
//         if (maxDscToMint < 0) return;
//         dscAmount = bound(dscAmount, 0, uint256(maxDscToMint));
//         if (dscAmount == 0) return;
//         vm.prank(sender);
//         dscEngine.mintDsc(dscAmount);
//         timesMintIsCalled++;
//     }

//     // This breaks our invariant test suite!!
//     // function updateCollateralPrice(uint96 newPrice) public {
//     //     int256 newPriceInt = int256(uint256(newPrice));
//     //     ethUsdPriceFeed.updateAnswer(newPriceInt);
//     // }

//     /// Helper Functions

//     function _getCollateralTokenFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
//         if (collateralSeed % 2 == 0) {
//             return weth;
//         } else {
//             return wbtc;
//         }
//     }
// }
