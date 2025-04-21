// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseDeploymentTest} from "./BaseDeploymentTest.t.sol";
import {DeployUsdrifHandler} from "../../script/DeployUsdrifHandler.s.sol";
import {UsdrifHelperConfig} from "../../script/UsdrifHelperConfig.s.sol";
import {TropykusErc20HandlerDex} from "../../src/TropykusErc20HandlerDex.sol";
import {console} from "forge-std/Test.sol";
import "../Constants.sol";

contract NewHandlerDeploymentTest is BaseDeploymentTest {
    // USDRIF handler
    address public usdrifHandlerAddress;
    TropykusErc20HandlerDex public usdrifHandler;
    UsdrifHelperConfig public usdrifHelperConfig;
    
    function setUp() public override {
        // Deploy base protocol first using parent setup
        super.setUp();
        
        // Initialize USDRIF helper config and update with protocol addresses
        usdrifHelperConfig = new UsdrifHelperConfig();
        usdrifHelperConfig.updateProtocolAddresses(address(adminOperations), address(dcaManager));
        
        // Deploy USDRIF handler with our configured helper
        DeployUsdrifHandler usdrifDeployer = new DeployUsdrifHandler();
        console.log("USDRIF handler deployed:", address(usdrifDeployer));
        usdrifHandlerAddress = usdrifDeployer.run(usdrifHelperConfig);
        usdrifHandler = TropykusErc20HandlerDex(payable(usdrifHandlerAddress));
    }
    
    function testUsdrifHandlerDeployment() public {
        // Verify USDRIF handler deployment
        assertNotEq(usdrifHandlerAddress, address(0), "USDRIF handler not deployed");
        
        // Verify handler references the correct DcaManager
        assertEq(usdrifHandler.i_dcaManager(), address(dcaManager), "USDRIF handler doesn't reference DcaManager");
        
        // Verify ownership transferred correctly
        assertEq(usdrifHandler.owner(), makeAddr(OWNER_STRING), "USDRIF handler owner not set correctly");
        
        // Verify handler is registered in AdminOperations
        UsdrifHelperConfig.NetworkConfig memory config = usdrifHelperConfig.getActiveNetworkConfig();
        address registeredHandler = adminOperations.getTokenHandler(config.usdrifTokenAddress, TROPYKUS_INDEX);
        assertEq(registeredHandler, usdrifHandlerAddress, "USDRIF handler not registered in AdminOperations");
    }
}
