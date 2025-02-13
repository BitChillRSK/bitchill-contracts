//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {TropykusDocHandlerMoc} from "../src/TropykusDocHandlerMoc.sol";
import {SovrynDocHandlerMoc} from "../src/SovrynDocHandlerMoc.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {IFeeHandler} from "../src/interfaces/IFeeHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";
import {console} from "forge-std/Test.sol";

contract DeployMocSwaps is Script {
    enum Environment {
        LOCAL,
        FORK,
        TESTNET,
        MAINNET
    }

    enum Protocol {
        TROPYKUS,
        SOVRYN
    }

    struct DeploymentConfig {
        address owner;
        address feeCollector;
        address admin;
        Protocol protocol;
        Environment environment;
    }

    mapping(Environment => address) private adminAddresses;
    mapping(Environment => address) private feeCollectorAddresses;

    constructor() {
        // Admin addresses
        adminAddresses[Environment.LOCAL] = makeAddr(OWNER_STRING);
        adminAddresses[Environment.FORK] = makeAddr(OWNER_STRING);
        adminAddresses[Environment.TESTNET] = 0x226E865Ab298e542c5e5098694eFaFfe111F93D3;
        adminAddresses[Environment.MAINNET] = 0x226E865Ab298e542c5e5098694eFaFfe111F93D3;

        // Fee collector addresses
        feeCollectorAddresses[Environment.LOCAL] = makeAddr(FEE_COLLECTOR_STRING);
        feeCollectorAddresses[Environment.FORK] = makeAddr(FEE_COLLECTOR_STRING);
        feeCollectorAddresses[Environment.TESTNET] = 0x226E865Ab298e542c5e5098694eFaFfe111F93D3; // 0x6804b6C71C055695A6e7Ddf454e12e897885e6f4
        feeCollectorAddresses[Environment.MAINNET] = 0x226E865Ab298e542c5e5098694eFaFfe111F93D3; // Replace with actual mainnet address
    }

    function getFeeCollector(Environment environment) internal view returns (address) {
        return feeCollectorAddresses[environment];
    }

    function getEnvironment() internal view returns (Environment) {
        // First check if this is a real deployment
        bool isRealDeployment = vm.envOr("REAL_DEPLOYMENT", false);

        if (isRealDeployment) {
            if (block.chainid == 31) return Environment.TESTNET;
            if (block.chainid == 30) return Environment.MAINNET;
            revert("Unsupported chain for deployment");
        }

        // If not a real deployment, handle test environments
        if (block.chainid == 31337) return Environment.LOCAL;
        if (isFork()) return Environment.FORK;
        revert("Unsupported chain");
    }

    function getProtocol() internal view returns (Protocol) {
        string memory lendingProtocol = vm.envString("LENDING_PROTOCOL");
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            return Protocol.TROPYKUS;
        }
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            return Protocol.SOVRYN;
        }
        revert("Invalid lending protocol");
    }

    function deployDocHandler(
        Protocol protocol,
        address dcaManager,
        address docToken,
        address lendingToken,
        address mocProxy,
        address feeCollector
    ) internal returns (address) {
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
                new SovrynDocHandlerMoc(
                    dcaManager, docToken, lendingToken, MIN_PURCHASE_AMOUNT, feeCollector, mocProxy, feeSettings
                )
            );
        }
    }

    function run() external returns (AdminOperations, address, DcaManager, MocHelperConfig) {
        Environment environment = getEnvironment();
        Protocol protocol = getProtocol();

        console.log("Environment:", uint256(environment)); // 0=LOCAL, 1=FORK, 2=TESTNET, 3=MAINNET
        console.log("Protocol:", uint256(protocol)); // 0=TROPYKUS, 1=SOVRYN
        console.log("Chain ID:", block.chainid);

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
                deployDocHandler(protocol, address(dcaManager), docToken, lendingToken, mocProxy, feeCollector);

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
                deployDocHandler(Protocol.TROPYKUS, address(dcaManager), docToken, kDocToken, mocProxy, feeCollector);
            console.log("Tropykus handler deployed at:", tropykusHandler);

            address sovrynHandler =
                deployDocHandler(Protocol.SOVRYN, address(dcaManager), docToken, iSusdToken, mocProxy, feeCollector);
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
