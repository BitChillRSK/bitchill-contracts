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
        feeCollectorAddresses[Environment.TESTNET] = 0x6804b6C71C055695A6e7Ddf454e12e897885e6f4; // Replace with actual testnet address
        feeCollectorAddresses[Environment.MAINNET] = 0x6804b6C71C055695A6e7Ddf454e12e897885e6f4; // Replace with actual mainnet address
    }

    function getFeeCollector(Environment environment) internal view returns (address) {
        return feeCollectorAddresses[environment];
    }

    function getEnvironment() internal view returns (Environment) {
        if (block.chainid == 31337) return Environment.LOCAL;
        if (isFork()) return Environment.FORK;
        if (block.chainid == 31) return Environment.TESTNET;
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

        MocHelperConfig helperConfig = new MocHelperConfig();
        (address docToken, address mocProxy, address kDocToken, address iSusdToken) = helperConfig.activeNetworkConfig();

        console.log("Protocol:", uint256(protocol)); // 0 for TROPYKUS, 1 for SOVRYN
        console.log("iSusdToken address:", iSusdToken);
        console.log("kDocToken address:", kDocToken);

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));

        address feeCollector = getFeeCollector(environment);

        // Use appropriate lending token based on protocol
        address lendingToken = protocol == Protocol.TROPYKUS ? kDocToken : iSusdToken;
        console.log("Selected lendingToken address:", lendingToken);
        address docHandlerMocAddress =
            deployDocHandler(protocol, address(dcaManager), docToken, lendingToken, mocProxy, feeCollector);

        // Handle ownership and roles based on environment
        if (environment != Environment.MAINNET) {
            address owner = adminAddresses[environment];
            adminOperations.transferOwnership(owner);
            dcaManager.transferOwnership(owner);
            Ownable(docHandlerMocAddress).transferOwnership(owner);
        }

        // Handle testnet-specific setup
        if (environment == Environment.TESTNET) {
            address tropykusHandler =
                deployDocHandler(Protocol.TROPYKUS, address(dcaManager), docToken, kDocToken, mocProxy, feeCollector);
            address sovrynHandler =
                deployDocHandler(Protocol.SOVRYN, address(dcaManager), docToken, iSusdToken, mocProxy, feeCollector);

            adminOperations.setAdminRole(tx.origin);
            adminOperations.assignOrUpdateTokenHandler(docToken, TROPYKUS_INDEX, tropykusHandler);
            adminOperations.assignOrUpdateTokenHandler(docToken, SOVRYN_INDEX, sovrynHandler);
            adminOperations.setAdminRole(adminAddresses[Environment.TESTNET]);
        }

        if (environment == Environment.MAINNET) {
            // See what to do in this case!
        }

        vm.stopBroadcast();

        return (adminOperations, docHandlerMocAddress, dcaManager, helperConfig);
    }
}
