//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MocHelperConfig} from "./MocHelperConfig.s.sol";
import {DcaManager} from "../src/DcaManager.sol";
import {TropykusDocHandlerMoc} from "../src/TropykusDocHandlerMoc.sol";
import {SovrynDocHandlerMoc} from "../src/SovrynDocHandlerMoc.sol";
import {AdminOperations} from "../src/AdminOperations.sol";
import {ICoinPairPrice} from "../src/interfaces/ICoinPairPrice.sol";
import {ITokenHandler} from "../src/interfaces/ITokenHandler.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Test.sol";
import "../test/Constants.sol";

contract DeployMocSwaps is Script {
    address OWNER = makeAddr(OWNER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    address docHandlerMocAddress;

    function run() external returns (AdminOperations, address, DcaManager, MocHelperConfig) {
        MocHelperConfig helperConfig = new MocHelperConfig();
        (address docToken, address mocProxy, address kDocToken) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            TropykusDocHandlerMoc docHandlerMoc = new TropykusDocHandlerMoc(
                address(dcaManager),
                docToken,
                kDocToken,
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                mocProxy,
                ITokenHandler.FeeSettings({
                    minFeeRate: MIN_FEE_RATE,
                    maxFeeRate: MAX_FEE_RATE,
                    minAnnualAmount: MIN_ANNUAL_AMOUNT,
                    maxAnnualAmount: MAX_ANNUAL_AMOUNT
                }),
                DOC_YIELDS_INTEREST // TODO: remove this parameter!!
            );
            docHandlerMocAddress = address(docHandlerMoc);
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            SovrynDocHandlerMoc docHandlerMoc = new SovrynDocHandlerMoc(
                address(dcaManager),
                docToken,
                kDocToken,
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                mocProxy,
                ITokenHandler.FeeSettings({
                    minFeeRate: MIN_FEE_RATE,
                    maxFeeRate: MAX_FEE_RATE,
                    minAnnualAmount: MIN_ANNUAL_AMOUNT,
                    maxAnnualAmount: MAX_ANNUAL_AMOUNT
                }),
                DOC_YIELDS_INTEREST
            );
            docHandlerMocAddress = address(docHandlerMoc);
        } else {
            revert("Invalid deploy environment");
        }

        // For local or fork tests:
        if (block.chainid == 31337 || block.chainid == 30 || block.chainid == 31) {
            // adminOperations.setAdminRole(ADMIN); // Only for tests!!!
            // adminOperations.setSwapperRole(SWAPPER); // Only for tests!!!
            adminOperations.transferOwnership(OWNER); // Only for tests!!!
            dcaManager.transferOwnership(OWNER); // Only for tests!!!
            Ownable(docHandlerMocAddress).transferOwnership(OWNER); // Only for tests!!!
        }

        // For back-end and front-end devs to test:
        // rbtcDca.transferOwnership(0x8191c3a9DF486A09d8087E99A1b2b6885Cc17214); // Carlos
        // rbtcDca.transferOwnership(0x03B1E454F902771A7071335f44042A3233836BB3); // Pau

        vm.stopBroadcast();
        return (adminOperations, docHandlerMocAddress, dcaManager, helperConfig);
    }
}
