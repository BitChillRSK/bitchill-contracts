// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DeployDca} from "../../script/DeployDca.s.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// // import {Handler} from "./Handler.t.sol";

// contract InvariantTest is StdInvariant, Test {
//     // Invariantes
//     // Que el saldo de DOC del contrato siempre sea igual a la suma de los saldos de los usuarios registrados
//     // Que el saldo de rBTC del contrato sea siempre igual a la suma del rBTC acumulado por los usuarios

//     DeployDca deployer;
//     HelperConfig helperConfig;
//     Handler handler;

//     function setUp() external {
//         deployer = new DeployDca();
//         (dcaContract, helperConfig) = deployer.run();
//         (docTokenAddress, mocProxyAddress) = helperConfig.activeNetworkConfig();
//         handler = new Handler(dcaContract, dscEngine);
//         targetContract(address(handler));
//     }

//     function invariant_DcaContractDocBalanceEqualsSumOfAllUsers() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all debt (dsc)
//         uint256 totalSupply = dcaContract.totalSupply();
//         uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
//         uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

//         uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
//         uint256 wbtcValue = dscEngine.getUsdValue(wbtc, totalWbtcDeposited);

//         // if (wethValue + wbtcValue < totalSupply) {
//         console.log("weth value:  ", wethValue);
//         console.log("wbtc value:  ", wbtcValue);
//         console.log("total supply:", totalSupply);
//         console.log("times mint call completed:", handler.timesMintIsCalled());
//         // }

//         assert(wethValue + wbtcValue >= totalSupply);
//     }

//     function invariant_gettersCantRevert() public view {
//         dscEngine.getAdditionalFeedPrecision();
//         dscEngine.getCollateralTokens();
//         dscEngine.getLiquidationBonus();
//         dscEngine.getLiquidationPrecision();
//         dscEngine.getLiquidationThreshold();
//         dscEngine.getMinHealthFactor();
//         dscEngine.getPrecision();
//     }
// }
