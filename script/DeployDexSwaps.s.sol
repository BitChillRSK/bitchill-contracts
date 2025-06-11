// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployBase} from "./DeployBase.s.sol";
import {DexHelperConfig} from "./DexHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {TropykusErc20HandlerDex} from "../src/TropykusErc20HandlerDex.sol";
import {SovrynErc20HandlerDex} from "../src/SovrynErc20HandlerDex.sol";
import {IPurchaseUniswap} from "../src/interfaces/IPurchaseUniswap.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {IWRBTC} from "../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployDexSwaps is DeployBase {
    // Struct to group deployment parameters to avoid stack too deep errors
    struct DeployParams {
        Protocol protocol;
        address dcaManager;
        address tokenAddress;
        address lendingToken;
        IPurchaseUniswap.UniswapSettings uniswapSettings;
        address feeCollector;
        uint256 amountOutMinimumPercent;
        uint256 amountOutMinimumSafetyCheck;
    }

    function deployDocHandlerDex(DeployParams memory params) public returns (address) {
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE,
            purchaseLowerBound: PURCHASE_LOWER_BOUND,
            purchaseUpperBound: PURCHASE_UPPER_BOUND
        });

        if (params.protocol == Protocol.TROPYKUS) {
            return address(
                new TropykusErc20HandlerDex(
                    params.dcaManager, 
                    params.tokenAddress, 
                    params.lendingToken, 
                    params.uniswapSettings, 
                    MIN_PURCHASE_AMOUNT, 
                    params.feeCollector, 
                    feeSettings,
                    params.amountOutMinimumPercent,
                    params.amountOutMinimumSafetyCheck
                )
            );
        } else {
            return address(
                new SovrynErc20HandlerDex(
                    params.dcaManager, 
                    params.tokenAddress, 
                    params.lendingToken, 
                    params.uniswapSettings, 
                    MIN_PURCHASE_AMOUNT, 
                    params.feeCollector, 
                    feeSettings,
                    params.amountOutMinimumPercent,
                    params.amountOutMinimumSafetyCheck
                )
            );
        }
    }

    function run() external returns (AdminOperations, address, DcaManager, DexHelperConfig) {
        DexHelperConfig helperConfig = new DexHelperConfig();
        DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        address feeCollector = getFeeCollector(environment);
        address docToken = networkConfig.docTokenAddress;
        address kDocToken = networkConfig.kDocAddress;
        address iSusdToken = networkConfig.iSusdAddress;
        address docHandlerDexAddress;

        IPurchaseUniswap.UniswapSettings memory uniswapSettings = IPurchaseUniswap.UniswapSettings({
            wrBtcToken: IWRBTC(networkConfig.wrbtcTokenAddress),
            swapRouter02: ISwapRouter02(networkConfig.swapRouter02Address),
            swapIntermediateTokens: networkConfig.swapIntermediateTokens,
            swapPoolFeeRates: networkConfig.swapPoolFeeRates,
            mocOracle: ICoinPairPrice(networkConfig.mocOracleAddress)
        });

        // For local or fork environments, deploy only the selected protocol's handler
        if (environment == Environment.LOCAL || environment == Environment.FORK) {
            console.log("Deploying single handler for local/fork environment");
            address lendingToken = protocol == Protocol.TROPYKUS ? kDocToken : iSusdToken;
            
            DeployParams memory params = DeployParams({
                protocol: protocol,
                dcaManager: address(dcaManager),
                tokenAddress: docToken,
                lendingToken: lendingToken,
                uniswapSettings: uniswapSettings,
                feeCollector: feeCollector,
                amountOutMinimumPercent: networkConfig.amountOutMinimumPercent,
                amountOutMinimumSafetyCheck: networkConfig.amountOutMinimumSafetyCheck
            });
            
            docHandlerDexAddress = deployDocHandlerDex(params);

            address owner = adminAddresses[environment];
            adminOperations.transferOwnership(owner);
            dcaManager.transferOwnership(owner);
            Ownable(docHandlerDexAddress).transferOwnership(owner);
        }
        // For live networks (testnet/mainnet), deploy both handlers
        else if (environment == Environment.TESTNET || environment == Environment.MAINNET) {
            console.log("Deploying both handlers for live network");

            // First register the lending protocols
            adminOperations.setAdminRole(tx.origin);
            adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, TROPYKUS_INDEX); // index 1
            adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, SOVRYN_INDEX); // index 2

            // Deploy Tropykus handler
            DeployParams memory tropykusParams = DeployParams({
                protocol: Protocol.TROPYKUS,
                dcaManager: address(dcaManager),
                tokenAddress: docToken,
                lendingToken: kDocToken,
                uniswapSettings: uniswapSettings,
                feeCollector: feeCollector,
                amountOutMinimumPercent: networkConfig.amountOutMinimumPercent,
                amountOutMinimumSafetyCheck: networkConfig.amountOutMinimumSafetyCheck
            });
            
            address tropykusHandler = deployDocHandlerDex(tropykusParams);
            console.log("Tropykus handler deployed at:", tropykusHandler);

            // Deploy Sovryn handler
            DeployParams memory sovrynParams = DeployParams({
                protocol: Protocol.SOVRYN,
                dcaManager: address(dcaManager),
                tokenAddress: docToken,
                lendingToken: iSusdToken,
                uniswapSettings: uniswapSettings,
                feeCollector: feeCollector,
                amountOutMinimumPercent: networkConfig.amountOutMinimumPercent,
                amountOutMinimumSafetyCheck: networkConfig.amountOutMinimumSafetyCheck
            });
            
            address sovrynHandler = deployDocHandlerDex(sovrynParams);
            console.log("Sovryn handler deployed at:", sovrynHandler);

            // Now assign the handlers
            adminOperations.assignOrUpdateTokenHandler(docToken, TROPYKUS_INDEX, tropykusHandler);
            adminOperations.assignOrUpdateTokenHandler(docToken, SOVRYN_INDEX, sovrynHandler);

            if (environment == Environment.TESTNET) {
                adminOperations.setAdminRole(adminAddresses[Environment.TESTNET]);
            }
            // Return the handler address matching the protocol parameter for consistency
            docHandlerDexAddress = protocol == Protocol.TROPYKUS ? tropykusHandler : sovrynHandler;
        }

        vm.stopBroadcast();

        return (adminOperations, docHandlerDexAddress, dcaManager, helperConfig);
    }
}
