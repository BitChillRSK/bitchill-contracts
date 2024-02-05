//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DCAContract} from "../src/DCAContract.sol";
import {console} from "forge-std/Test.sol";

contract DeployDca is Script {
    address OWNER = makeAddr("owner");

    function run() external returns (DCAContract, HelperConfig) {
        // Before startBroadcast -> not a "real" tx
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        (address docToken, address mocProxy) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        // After startBroadcast -> "real" tx
        DCAContract dcaContract = new DCAContract(docToken, mocProxy);
        // console.log(dcaContract.owner());
        dcaContract.transferOwnership(OWNER);
        // console.log(dcaContract.owner());
        vm.stopBroadcast();
        return (dcaContract, helperConfig);
    }
}
