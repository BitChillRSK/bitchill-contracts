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
import {TokenConfig, TokenConfigs} from "../test/TokenConfigs.sol";
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
        // Initialize DexHelperConfig which reads the STABLECOIN_TYPE env var
        DexHelperConfig helperConfig = new DexHelperConfig();
        DexHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        // Get stablecoin type (or use default if not specified)
        string memory stablecoinType;
        try vm.envString("STABLECOIN_TYPE") returns (string memory coinType) {
            stablecoinType = coinType;
        } catch {
            stablecoinType = DEFAULT_STABLECOIN;
        }

        // Load token configuration
        TokenConfig memory tokenConfig = TokenConfigs.getTokenConfig(stablecoinType, block.chainid);
        
        console.log("Using stablecoin type:", stablecoinType);

        // Check if stablecoin is supported by the selected protocol
        bool isSovryn = protocol == Protocol.SOVRYN;
        
        if (isSovryn && !tokenConfig.supportedBySovryn) {
            revert(string(abi.encodePacked(tokenConfig.tokenSymbol, " is not supported by Sovryn")));
        }

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        address feeCollector = getFeeCollector(environment);
        
        // Get the stablecoin address
        address stablecoinAddress = helperConfig.getStablecoinAddress();
        console.log("Stablecoin address:", stablecoinAddress);
        
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
            
            // Get the appropriate lending token address based on protocol
            address lendingTokenAddress = helperConfig.getLendingTokenAddress();
            if (lendingTokenAddress == address(0)) {
                revert("Lending token not available for the selected combination");
            }
            
            console.log("Lending token address:", lendingTokenAddress);
            
            DeployParams memory params = DeployParams({
                protocol: protocol,
                dcaManager: address(dcaManager),
                tokenAddress: stablecoinAddress,
                lendingToken: lendingTokenAddress,
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
        // For live networks (testnet/mainnet), deploy handlers for both lending protocols
        else if (environment == Environment.TESTNET || environment == Environment.MAINNET) {
            console.log("Deploying handlers for lending protocols for live network");

            // First register the lending protocols
            adminOperations.setAdminRole(tx.origin);
            adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, TROPYKUS_INDEX); // index 1
            adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, SOVRYN_INDEX); // index 2

            // Deploy Tropykus handler if there's a valid lending token
            address tropykusLendingToken = networkConfig.tropykusLendingToken;
            
            if (tropykusLendingToken == address(0)) {
                console.log("Warning: Tropykus lending token not available for this stablecoin");
            } else {
                // Deploy Tropykus handler
                DeployParams memory tropykusParams = DeployParams({
                    protocol: Protocol.TROPYKUS,
                    dcaManager: address(dcaManager),
                    tokenAddress: stablecoinAddress,
                    lendingToken: tropykusLendingToken,
                    uniswapSettings: uniswapSettings,
                    feeCollector: feeCollector,
                    amountOutMinimumPercent: networkConfig.amountOutMinimumPercent,
                    amountOutMinimumSafetyCheck: networkConfig.amountOutMinimumSafetyCheck
                });
                
                address tropykusHandler = deployDocHandlerDex(tropykusParams);
                console.log("Tropykus handler deployed at:", tropykusHandler);
                
                // Assign the Tropykus handler
                adminOperations.assignOrUpdateTokenHandler(stablecoinAddress, TROPYKUS_INDEX, tropykusHandler);
                
                // If we're deploying for Tropykus, set this as our return handler
                if (protocol == Protocol.TROPYKUS) {
                    docHandlerDexAddress = tropykusHandler;
                }
            }

            // Only deploy Sovryn handler if the stablecoin is supported
            if (tokenConfig.supportedBySovryn) {
                // Get Sovryn lending token address
                address sovrynLendingToken = networkConfig.sovrynLendingToken;
                
                if (sovrynLendingToken == address(0)) {
                    console.log("Warning: Sovryn lending token not available for this stablecoin");
                } else {
                    // Deploy Sovryn handler
                    DeployParams memory sovrynParams = DeployParams({
                        protocol: Protocol.SOVRYN,
                        dcaManager: address(dcaManager),
                        tokenAddress: stablecoinAddress,
                        lendingToken: sovrynLendingToken,
                        uniswapSettings: uniswapSettings,
                        feeCollector: feeCollector,
                        amountOutMinimumPercent: networkConfig.amountOutMinimumPercent,
                        amountOutMinimumSafetyCheck: networkConfig.amountOutMinimumSafetyCheck
                    });
                    
                    address sovrynHandler = deployDocHandlerDex(sovrynParams);
                    console.log("Sovryn handler deployed at:", sovrynHandler);
                    
                    // Assign the Sovryn handler
                    adminOperations.assignOrUpdateTokenHandler(stablecoinAddress, SOVRYN_INDEX, sovrynHandler);
                    
                    // If we're deploying for Sovryn, set this as our return handler
                    if (protocol == Protocol.SOVRYN) {
                        docHandlerDexAddress = sovrynHandler;
                    }
                }
            } else {
                console.log("Skipping Sovryn handler deployment for %s as it's not supported", tokenConfig.tokenSymbol);
            }

            if (environment == Environment.TESTNET) {
                adminOperations.setAdminRole(adminAddresses[Environment.TESTNET]);
            }
        }

        vm.stopBroadcast();

        return (adminOperations, docHandlerDexAddress, dcaManager, helperConfig);
    }
}
