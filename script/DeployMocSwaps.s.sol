//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DeployBase} from "./DeployBase.s.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {TropykusDocHandlerMoc} from "../src/TropykusDocHandlerMoc.sol";
import {SovrynErc20HandlerMoc} from "../src/SovrynErc20HandlerMoc.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployMocSwaps is DeployBase {
    function deployDocHandlerMoc(
        Protocol protocol,
        address dcaManager,
        address docToken,
        address lendingToken,
        address mocProxy,
        address feeCollector
    ) public returns (address) {
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE,
            minAnnualAmount: MIN_ANNUAL_AMOUNT,
            maxAnnualAmount: MAX_ANNUAL_AMOUNT
        });

        if (protocol == Protocol.TROPYKUS) {
            return address(
                new TropykusDocHandlerMoc(
                    dcaManager, docToken, lendingToken, MIN_PURCHASE_AMOUNT, feeCollector, mocProxy, feeSettings
                )
            );
        } else {
            return address(
                new SovrynErc20HandlerMoc(
                    dcaManager, docToken, lendingToken, MIN_PURCHASE_AMOUNT, feeCollector, mocProxy, feeSettings
                )
            );
        }
    }

    function run() external returns (AdminOperations, address, DcaManager, MocHelperConfig) {
        MocHelperConfig helperConfig = new MocHelperConfig();
        (address docToken, address mocProxy, address kDocToken, address iSusdToken) = helperConfig.activeNetworkConfig();

        console.log("iSusdToken address:", iSusdToken);
        console.log("kDocToken address:", kDocToken);

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        address feeCollector = getFeeCollector(environment);
        address docHandlerMocAddress;

        // For local or fork environments, deploy only the selected protocol's handler
        if (environment == Environment.LOCAL || environment == Environment.FORK) {
            console.log("Deploying single handler for local/fork environment");
            address lendingToken = protocol == Protocol.TROPYKUS ? kDocToken : iSusdToken;
            docHandlerMocAddress =
                deployDocHandlerMoc(protocol, address(dcaManager), docToken, lendingToken, mocProxy, feeCollector);

            address owner = adminAddresses[environment];
            adminOperations.transferOwnership(owner);
            dcaManager.transferOwnership(owner);
            Ownable(docHandlerMocAddress).transferOwnership(owner);
        }
        // For live networks (testnet/mainnet), deploy both handlers
        else if (environment == Environment.TESTNET || environment == Environment.MAINNET) {
            console.log("Deploying both handlers for live network");

            // First register the lending protocols
            adminOperations.setAdminRole(tx.origin);
            adminOperations.addOrUpdateLendingProtocol(TROPYKUS_STRING, TROPYKUS_INDEX); // index 1
            adminOperations.addOrUpdateLendingProtocol(SOVRYN_STRING, SOVRYN_INDEX); // index 2

            address tropykusHandler =
                deployDocHandlerMoc(Protocol.TROPYKUS, address(dcaManager), docToken, kDocToken, mocProxy, feeCollector);
            console.log("Tropykus handler deployed at:", tropykusHandler);

            address sovrynHandler =
                deployDocHandlerMoc(Protocol.SOVRYN, address(dcaManager), docToken, iSusdToken, mocProxy, feeCollector);
            console.log("Sovryn handler deployed at:", sovrynHandler);

            // Now assign the handlers
            adminOperations.assignOrUpdateTokenHandler(docToken, TROPYKUS_INDEX, tropykusHandler);
            adminOperations.assignOrUpdateTokenHandler(docToken, SOVRYN_INDEX, sovrynHandler);

            if (environment == Environment.TESTNET) {
                adminOperations.setAdminRole(adminAddresses[Environment.TESTNET]);
            }
            // Return the handler address matching the protocol parameter for consistency
            docHandlerMocAddress = protocol == Protocol.TROPYKUS ? tropykusHandler : sovrynHandler;
        }

        vm.stopBroadcast();

        return (adminOperations, docHandlerMocAddress, dcaManager, helperConfig);
    }
}
