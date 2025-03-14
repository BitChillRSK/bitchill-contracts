// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {DeployMocSwaps} from "./DeployMocSwaps.s.sol";
// import {DeployDexSwaps} from "./DeployDexSwaps.s.sol";
// import {MocHelperConfig} from "./MocHelperConfig.s.sol";
// import {DexHelperConfig} from "./DexHelperConfig.s.sol";
// import {DcaManager} from "../src/DcaManager.sol";
// import {TropykusDocHandlerDex} from "../src/TropykusDocHandlerDex.sol";
// import {SovrynDocHandlerDex} from "../src/SovrynDocHandlerDex.sol";
// import {IUniswapPurchase} from "../src/interfaces/IUniswapPurchase.sol";
// import {AdminOperations} from "../src/AdminOperations.sol";
// import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
// import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
// import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
// import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {console} from "forge-std/Test.sol";
// import "../test/Constants.sol";

// contract DeployMocAndUniswap { /*is DeployMocSwaps, DeployDexSwaps*/
//     function run()
//         external
//         returns (
//             // override(DeployMocSwaps, DeployDexSwaps)
//             AdminOperations adOpsMoc,
//             address handlerMoc,
//             DcaManager dcaManMoc,
//             MocHelperConfig helpConfMoc,
//             AdminOperations adOpsUni,
//             address handlerUni,
//             DcaManager dcaManUni,
//             DexHelperConfig helpConfUni
//         )
//     {
//         helpConfMoc = new MocHelperConfig();
//         (address docToken, address mocProxy, address kDocToken, address iSusdToken) = helpConfMoc.activeNetworkConfig();
//         helpConfUni = new DexHelperConfig();
//         DexHelperConfig.NetworkConfig memory networkConfig = helpConfUni.getActiveNetworkConfig();

//         vm.startBroadcast();

//         adOpsMoc = new AdminOperations();
//         dcaManMoc = new DcaManager(address(adOpsMoc));
//         adOpsUni = new AdminOperations();
//         dcaManUni = new DcaManager(address(adOpsUni));
//         address feeCollector = getFeeCollector(environment);
//         // address docToken = networkConfig.docTokenAddress;
//         // address kDocToken = networkConfig.kDocAddress;
//         // address iSusdToken = networkConfig.iSusdAddress;

//         IUniswapPurchase.UniswapSettings memory uniswapSettings = IUniswapPurchase.UniswapSettings({
//             wrBtcToken: IWRBTC(networkConfig.wrbtcTokenAddress),
//             swapRouter02: ISwapRouter02(networkConfig.swapRouter02Address),
//             swapIntermediateTokens: networkConfig.swapIntermediateTokens,
//             swapPoolFeeRates: networkConfig.swapPoolFeeRates,
//             mocOracle: ICoinPairPrice(networkConfig.mocOracleAddress)
//         });

//         // For local or fork environments, deploy only the selected protocol's handler
//         if (environment == Environment.LOCAL || environment == Environment.FORK) {
//             console.log("Deploying", vm.envString("LENDING_PROTOCOL"), "handler for local/fork environment");
//             address lendingToken = protocol == Protocol.TROPYKUS ? kDocToken : iSusdToken;
//             DeployMocSwaps deployMocSwapContracts = new DeployMocSwaps();
//             handlerMoc = deployMocSwapContracts.deployDocHandlerMoc(
//                 protocol, address(dcaManMoc), docToken, lendingToken, mocProxy, feeCollector
//             );

//             DeployDexSwaps deployDexSwapContracts = new DeployDexSwaps();
//             handlerUni = deployDexSwapContracts.deployDocHandlerDex(
//                 protocol, address(dcaManMoc), docToken, lendingToken, uniswapSettings, feeCollector
//             );

//             address owner = adminAddresses[environment];
//             adOpsMoc.transferOwnership(owner);
//             dcaManMoc.transferOwnership(owner);
//             Ownable(handlerMoc).transferOwnership(owner);

//             adOpsUni.transferOwnership(owner);
//             dcaManUni.transferOwnership(owner);
//             Ownable(handlerUni).transferOwnership(owner);
//         }

//         vm.stopBroadcast();

//         // DeployMocSwaps deployMocSwapContracts = new DeployMocSwaps();
//         // (adOpsMoc, handlerMoc, dcaManMoc, helpConfMoc) = deployMocSwapContracts.run();
//         // DeployMocSwaps deployDexSwapContracts = new DeployDexSwaps();
//         // (adOpsUni, handlerUni, dcaManUni, helpConfUni) = deployMocSwapContracts.run();

//         return (adOpsMoc, handlerMoc, dcaManMoc, helpConfMoc, adOpsUni, handlerUni, dcaManUni, helpConfUni);
//     }
// }
