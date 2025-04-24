// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployMocSwaps} from "../../script/DeployMocSwaps.s.sol";
import {AdminOperations} from "../../src/AdminOperations.sol";
import {DcaManager} from "../../src/DcaManager.sol";
import {TropykusDocHandlerMoc} from "../../src/TropykusDocHandlerMoc.sol";
import {SovrynErc20HandlerMoc} from "../../src/SovrynErc20HandlerMoc.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import "../Constants.sol";

contract BaseDeploymentTest is Test {
    // Core contracts
    AdminOperations public adminOperations;
    DcaManager public dcaManager;
    address public docHandlerMocAddress;
    MocHelperConfig public helperConfig;
    address OWNER = makeAddr(OWNER_STRING);
    address ADMIN = makeAddr(ADMIN_STRING);
    
    // For validating the handler type
    TropykusDocHandlerMoc public tropykusHandler;
    SovrynErc20HandlerMoc public sovrynHandler;

    function setUp() public virtual {
        // Set up environment variables for deployment
        vm.setEnv("REAL_DEPLOYMENT", "false");
        vm.setEnv("LENDING_PROTOCOL", "tropykus");
        
        // Deploy the core protocol
        DeployMocSwaps deployer = new DeployMocSwaps();
        (adminOperations, docHandlerMocAddress, dcaManager, helperConfig) = deployer.run();
        
        // Check which handler type was deployed based on the lending protocol
        string memory lendingProtocol = vm.envString("LENDING_PROTOCOL");
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            tropykusHandler = TropykusDocHandlerMoc(payable(docHandlerMocAddress));
        } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
            sovrynHandler = SovrynErc20HandlerMoc(payable(docHandlerMocAddress));
        }

        // Grant admin role to test contract and register the handler
        vm.prank(OWNER);
        adminOperations.setAdminRole(ADMIN);
        vm.prank(ADMIN);
        adminOperations.addOrUpdateLendingProtocol(
            "tropykus",
            TROPYKUS_INDEX
        );
    }
    
    function testCoreProtocolDeployment() public {
        // Verify AdminOperations deployment
        assertNotEq(address(adminOperations), address(0), "AdminOperations not deployed");
        
        // Verify DcaManager deployment
        assertNotEq(address(dcaManager), address(0), "DcaManager not deployed");
        
        // Verify DocHandler deployment
        assertNotEq(docHandlerMocAddress, address(0), "DocHandler not deployed");
        
        // Check ownership
        assertEq(adminOperations.owner(), makeAddr(OWNER_STRING), "AdminOperations owner not set correctly");
        assertEq(dcaManager.owner(), makeAddr(OWNER_STRING), "DcaManager owner not set correctly");
        
        // Verify DcaManager reference in handler
        string memory lendingProtocol = vm.envString("LENDING_PROTOCOL");
        if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
            assertEq(tropykusHandler.i_dcaManager(), address(dcaManager), "TropykusHandler doesn't reference DcaManager");
            assertEq(TropykusDocHandlerMoc(payable(docHandlerMocAddress)).owner(), makeAddr(OWNER_STRING), "Handler owner not set correctly");
        } else {
            assertEq(sovrynHandler.i_dcaManager(), address(dcaManager), "SovrynHandler doesn't reference DcaManager");
            assertEq(SovrynErc20HandlerMoc(payable(docHandlerMocAddress)).owner(), makeAddr(OWNER_STRING), "Handler owner not set correctly");
        }
    }
}
