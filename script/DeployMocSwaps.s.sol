//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployBase} from "./DeployBase.s.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {TropykusDocHandlerMoc} from "../src/TropykusDocHandlerMoc.sol";
import {SovrynDocHandlerMoc} from "../src/SovrynDocHandlerMoc.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import {TokenConfig, TokenConfigs} from "../test/TokenConfigs.sol";
import "../test/Constants.sol";

contract DeployMocSwaps is DeployBase {
    // Struct to group deployment parameters to avoid stack too deep errors
    struct DeployParams {
        Protocol protocol;
        address dcaManager;
        address tokenAddress;
        address lendingToken;
        address mocProxy;
        address feeCollector;
    }

    function deployDocHandlerMoc(DeployParams memory params) public returns (address) {
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE,
            purchaseLowerBound: PURCHASE_LOWER_BOUND,
            purchaseUpperBound: PURCHASE_UPPER_BOUND
        });

        if (params.protocol == Protocol.TROPYKUS) {
            return address(
                new TropykusDocHandlerMoc(
                    params.dcaManager, 
                    params.tokenAddress, 
                    params.lendingToken, 
                    MIN_PURCHASE_AMOUNT, 
                    params.feeCollector, 
                    params.mocProxy, 
                    feeSettings
                )
            );
        } else {
            return address(
                new SovrynDocHandlerMoc(
                    params.dcaManager, 
                    params.tokenAddress, 
                    params.lendingToken, 
                    MIN_PURCHASE_AMOUNT, 
                    params.feeCollector, 
                    params.mocProxy, 
                    feeSettings
                )
            );
        }
    }

    function run() external returns (AdminOperations, address, DcaManager, MocHelperConfig) {
        console.log("==== DeployMocSwaps.run() called ====");
        console.log("LENDING_PROTOCOL (env var):", vm.envString("LENDING_PROTOCOL"));
        console.log("STABLECOIN_TYPE (env var):", vm.envString("STABLECOIN_TYPE"));
        
        // Lots of debugging here
        try vm.envString("LENDING_PROTOCOL") returns (string memory lendingProtocolFromEnv) {
            console.log("Got LENDING_PROTOCOL from env:", lendingProtocolFromEnv);
        } catch {
            console.log("Failed to get LENDING_PROTOCOL from env");
        }
        
        try vm.envString("STABLECOIN_TYPE") returns (string memory stablecoinTypeFromEnv) {
            console.log("Got STABLECOIN_TYPE from env:", stablecoinTypeFromEnv);
        } catch {
            console.log("Failed to get STABLECOIN_TYPE from env");
        }

        // Initialize MocHelperConfig which reads the STABLECOIN_TYPE env var
        MocHelperConfig helperConfig = new MocHelperConfig();
        MocHelperConfig.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

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
        
        // Get the DOC token address
        address docTokenAddress = helperConfig.getStablecoinAddress();
        console.log("DOC token address:", docTokenAddress);
        
        address mocProxyAddress = networkConfig.mocProxyAddress;
        console.log("MoC Proxy address:", mocProxyAddress);

        // Check if stablecoin is supported by the selected protocol
        bool isSovryn = protocol == Protocol.SOVRYN;
        
        if (isSovryn && !tokenConfig.supportedBySovryn) {
            revert(string(abi.encodePacked(tokenConfig.tokenSymbol, " is not supported by Sovryn")));
        }

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        address feeCollector = getFeeCollector(environment);
        address docHandlerMocAddress;

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
                tokenAddress: docTokenAddress,
                lendingToken: lendingTokenAddress,
                mocProxy: mocProxyAddress,
                feeCollector: feeCollector
            });
            
            docHandlerMocAddress = deployDocHandlerMoc(params);

            address owner = adminAddresses[environment];
            adminOperations.transferOwnership(owner);
            dcaManager.transferOwnership(owner);
            Ownable(docHandlerMocAddress).transferOwnership(owner);
        }
        // For live networks (testnet/mainnet), deploy handlers for both lending protocols
        else if (environment == Environment.TESTNET || environment == Environment.MAINNET) {
            console.log("Deploying handlers for lending protocols for live network");

            // First register the lending protocols
            adminOperations.setAdminRole(tx.origin);
            adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, TROPYKUS_INDEX); // index 1
            adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, SOVRYN_INDEX); // index 2

            // Deploy Tropykus handler if there's a valid lending token
            address tropykusLendingToken = networkConfig.kDocAddress;
            
            if (tropykusLendingToken == address(0)) {
                console.log("Warning: Tropykus lending token not available for this stablecoin");
            } else {
                // Deploy Tropykus handler
                DeployParams memory tropykusParams = DeployParams({
                    protocol: Protocol.TROPYKUS,
                    dcaManager: address(dcaManager),
                    tokenAddress: docTokenAddress,
                    lendingToken: tropykusLendingToken,
                    mocProxy: mocProxyAddress,
                    feeCollector: feeCollector
                });
                
                address tropykusHandler = deployDocHandlerMoc(tropykusParams);
                console.log("Tropykus handler deployed at:", tropykusHandler);
                
                // Assign the Tropykus handler
                adminOperations.assignOrUpdateTokenHandler(docTokenAddress, TROPYKUS_INDEX, tropykusHandler);
                
                // If we're deploying for Tropykus, set this as our return handler
                if (protocol == Protocol.TROPYKUS) {
                    docHandlerMocAddress = tropykusHandler;
                }
            }

            // Only deploy Sovryn handler if the stablecoin is supported
            if (tokenConfig.supportedBySovryn) {
                // Get Sovryn lending token address
                address sovrynLendingToken = networkConfig.iSusdAddress;
                
                if (sovrynLendingToken == address(0)) {
                    console.log("Warning: Sovryn lending token not available for this stablecoin");
                } else {
                    // Deploy Sovryn handler
                    DeployParams memory sovrynParams = DeployParams({
                        protocol: Protocol.SOVRYN,
                        dcaManager: address(dcaManager),
                        tokenAddress: docTokenAddress,
                        lendingToken: sovrynLendingToken,
                        mocProxy: mocProxyAddress,
                        feeCollector: feeCollector
                    });
                    
                    address sovrynHandler = deployDocHandlerMoc(sovrynParams);
                    console.log("Sovryn handler deployed at:", sovrynHandler);
                    
                    // Assign the Sovryn handler
                    adminOperations.assignOrUpdateTokenHandler(docTokenAddress, SOVRYN_INDEX, sovrynHandler);
                    
                    // If we're deploying for Sovryn, set this as our return handler
                    if (protocol == Protocol.SOVRYN) {
                        docHandlerMocAddress = sovrynHandler;
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

        return (adminOperations, docHandlerMocAddress, dcaManager, helperConfig);
    }
}
