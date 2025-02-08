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
    address OWNER = makeAddr(OWNER_STRING);
    address FEE_COLLECTOR = makeAddr(FEE_COLLECTOR_STRING);
    string lendingProtocol = vm.envString("LENDING_PROTOCOL");
    bool lendingProtocolIsTropykus =
        keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"));
    bool lendingProtocolIsSovryn = keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"));

    address docHandlerMocAddress;

    function run() external returns (AdminOperations, address, DcaManager, MocHelperConfig) {
        MocHelperConfig helperConfig = new MocHelperConfig();
        (address docToken, address mocProxy, address kDocToken, address iSusdToken) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();

        AdminOperations adminOperations = new AdminOperations();
        DcaManager dcaManager = new DcaManager(address(adminOperations));

        if (block.chainid == 31337 || isFork()) {
            if (lendingProtocolIsTropykus) {
                TropykusDocHandlerMoc docHandlerMoc = new TropykusDocHandlerMoc(
                    address(dcaManager),
                    docToken,
                    kDocToken,
                    MIN_PURCHASE_AMOUNT,
                    FEE_COLLECTOR,
                    mocProxy,
                    IFeeHandler.FeeSettings({
                        minFeeRate: MIN_FEE_RATE,
                        maxFeeRate: MAX_FEE_RATE,
                        minAnnualAmount: MIN_ANNUAL_AMOUNT,
                        maxAnnualAmount: MAX_ANNUAL_AMOUNT
                    })
                );
                docHandlerMocAddress = address(docHandlerMoc);
            } else if (lendingProtocolIsSovryn) {
                if (block.chainid != 31337) kDocToken = iSusdToken;
                SovrynDocHandlerMoc docHandlerMoc = new SovrynDocHandlerMoc(
                    address(dcaManager),
                    docToken,
                    kDocToken, // On local tests kDocToken is a place holder for the address of the lending token
                    MIN_PURCHASE_AMOUNT,
                    FEE_COLLECTOR,
                    mocProxy,
                    IFeeHandler.FeeSettings({
                        minFeeRate: MIN_FEE_RATE,
                        maxFeeRate: MAX_FEE_RATE,
                        minAnnualAmount: MIN_ANNUAL_AMOUNT,
                        maxAnnualAmount: MAX_ANNUAL_AMOUNT
                    })
                );
                docHandlerMocAddress = address(docHandlerMoc);
            } else {
                revert("Invalid lending protocol");
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
        } else if (block.chainid == 31 /* || block.chainid == 30*/ ) {
            TropykusDocHandlerMoc tropykusDocHandlerMoc = new TropykusDocHandlerMoc(
                address(dcaManager),
                docToken,
                kDocToken,
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                mocProxy,
                IFeeHandler.FeeSettings({
                    minFeeRate: MIN_FEE_RATE,
                    maxFeeRate: MAX_FEE_RATE,
                    minAnnualAmount: MIN_ANNUAL_AMOUNT,
                    maxAnnualAmount: MAX_ANNUAL_AMOUNT
                })
            );
            docHandlerMocAddress = address(tropykusDocHandlerMoc); // @notice on live networks return values don't matter
            SovrynDocHandlerMoc sovrynDocHandlerMoc = new SovrynDocHandlerMoc(
                address(dcaManager),
                docToken,
                iSusdToken,
                MIN_PURCHASE_AMOUNT,
                FEE_COLLECTOR,
                mocProxy,
                IFeeHandler.FeeSettings({
                    minFeeRate: MIN_FEE_RATE,
                    maxFeeRate: MAX_FEE_RATE,
                    minAnnualAmount: MIN_ANNUAL_AMOUNT,
                    maxAnnualAmount: MAX_ANNUAL_AMOUNT
                })
            );
            adminOperations.setAdminRole(tx.origin);
            adminOperations.assignOrUpdateTokenHandler(docToken, TROPYKUS_INDEX, address(tropykusDocHandlerMoc));
            adminOperations.assignOrUpdateTokenHandler(docToken, SOVRYN_INDEX, address(sovrynDocHandlerMoc));
            adminOperations.setAdminRole(0x226E865Ab298e542c5e5098694eFaFfe111F93D3);
            adminOperations.transferOwnership(0x226E865Ab298e542c5e5098694eFaFfe111F93D3);
            dcaManager.transferOwnership(0x226E865Ab298e542c5e5098694eFaFfe111F93D3);
            vm.stopBroadcast();
        } else {
            revert("Chain not valid!");
        }

        return (adminOperations, docHandlerMocAddress, dcaManager, helperConfig);
    }
}
