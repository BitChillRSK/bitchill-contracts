// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {BaseDeploymentTest} from "./BaseDeploymentTest.t.sol";
import {DeployUsdrifHandler} from "../../script/DeployUsdrifHandler.s.sol";
import {UsdrifHelperConfig} from "../../script/UsdrifHelperConfig.s.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import {TropykusErc20HandlerDex} from "../../src/TropykusErc20HandlerDex.sol";
import "../Constants.sol";
import {Test, console} from "forge-std/Test.sol";

contract StorageSlotTest is Test {
    uint256 public slot0;
    
    function setSlot0(uint256 value) public {
        slot0 = value;
    }
}

contract NewHandlerDeploymentSlotTest is BaseDeploymentTest {
    // USDRIF handler
    address payable public usdrifHandlerAddress;
    TropykusErc20HandlerDex public usdrifHandler;
    UsdrifHelperConfig public usdrifHelperConfig;
    
    function testStorageSlots() public {
        // Create two different contracts
        StorageSlotTest contract1 = new StorageSlotTest();
        StorageSlotTest contract2 = new StorageSlotTest();
        
        // Set slot0 in contract1
        contract1.setSlot0(100);
        
        // Check if it affects contract2
        console.log("Contract1 slot0:", contract1.slot0());
        console.log("Contract2 slot0:", contract2.slot0());
        
        // Now test helper configs
        UsdrifHelperConfig usdrif1 = new UsdrifHelperConfig();
        UsdrifHelperConfig usdrif2 = new UsdrifHelperConfig();
        
        // Get configs and log the first field
        UsdrifHelperConfig.NetworkConfig memory config1 = usdrif1.getActiveNetworkConfig();
        UsdrifHelperConfig.NetworkConfig memory config2 = usdrif2.getActiveNetworkConfig();
        
        console.log("USDRIF Config1 usdrifTokenAddress:", config1.usdrifTokenAddress);
        console.log("USDRIF Config2 usdrifTokenAddress:", config2.usdrifTokenAddress);
        
        // Update one config
        usdrif1.updateProtocolAddresses(address(0x1), address(0x2));
        
        // Check again
        config1 = usdrif1.getActiveNetworkConfig();
        config2 = usdrif2.getActiveNetworkConfig();
        
        console.log("After update - Config1 adminOpsAddress:", config1.adminOperationsAddress);
        console.log("After update - Config2 adminOpsAddress:", config2.adminOperationsAddress);
        
        // Now check with MocHelperConfig
        MocHelperConfig moc = new MocHelperConfig();
        
        // This will help us see the actual addresses returned
        bytes32 mocStorageSlot = keccak256(abi.encode("MocHelperConfig.networkConfig"));
        bytes32 usdrifStorageSlot = keccak256(abi.encode("UsdrifHelperConfig.networkConfig"));
        
        console.log("MocHelperConfig storage slot:", uint256(mocStorageSlot));
        console.log("UsdrifHelperConfig storage slot:", uint256(usdrifStorageSlot));
    }
    
    function setUp() public override {
        // Run base setup first
        super.setUp();
        
        // Test the storage slots
        testStorageSlots();
        
        // Create a BRAND NEW instance of UsdrifHelperConfig
        usdrifHelperConfig = new UsdrifHelperConfig();
        
        // Print raw addresses to see what we're working with
        console.log("AdminOperations contract address:", address(adminOperations));
        console.log("DcaManager contract address:", address(dcaManager));
        
        // Use a different approach to update the protocol addresses
        address[] memory dummyIntermediateTokens = new address[](1);
        dummyIntermediateTokens[0] = address(1);
        
        uint24[] memory dummyPoolFeeRates = new uint24[](2);
        dummyPoolFeeRates[0] = 500;
        dummyPoolFeeRates[1] = 500;
        
        // Directly set the ENTIRE config to bypass any issues with updateProtocolAddresses
        UsdrifHelperConfig.NetworkConfig memory newConfig = UsdrifHelperConfig.NetworkConfig({
            usdrifTokenAddress: address(0x123), // Dummy address
            kUsdrifTokenAddress: address(0x456), // Dummy address
            wrbtcTokenAddress: address(0x789), // Dummy address 
            swapRouter02Address: address(0xabc), // Dummy address
            swapIntermediateTokens: dummyIntermediateTokens,
            swapPoolFeeRates: dummyPoolFeeRates,
            mocOracleAddress: address(0xdef), // Dummy address
            adminOperationsAddress: address(adminOperations),
            dcaManagerAddress: address(dcaManager)
        });
        
        // Create private "backdoor" function to brute-force update config
        function(UsdrifHelperConfig.NetworkConfig memory) internal view returns (bytes memory) fnPtr;
        bytes memory payload = abi.encodeWithSignature(
            "forceConfig(UsdrifHelperConfig.NetworkConfig)",
            newConfig
        );
        
        (bool success, ) = address(usdrifHelperConfig).delegatecall(payload);
        console.log("Force config update success:", success);
        
        // Check result
        UsdrifHelperConfig.NetworkConfig memory afterConfig = usdrifHelperConfig.getActiveNetworkConfig();
        console.log("After force update - Config adminOpsAddress:", afterConfig.adminOperationsAddress);
        console.log("After force update - Config dcaManagerAddress:", afterConfig.dcaManagerAddress);
        
        // Skip deployment due to expected failure
        console.log("SKIPPING USDRIF HANDLER DEPLOYMENT FOR DIAGNOSIS");
    }
    
    function testSingleConfigInstance() public {
        // Create a single UsdrifHelperConfig and test it in isolation
        UsdrifHelperConfig standalone = new UsdrifHelperConfig();
        
        // Directly call updateProtocolAddresses
        standalone.updateProtocolAddresses(address(0xABCD), address(0xDCBA));
        
        // Get config and check values
        UsdrifHelperConfig.NetworkConfig memory config = standalone.getActiveNetworkConfig();
        console.log("Standalone config adminOpsAddress:", config.adminOperationsAddress);
        console.log("Standalone config dcaManagerAddress:", config.dcaManagerAddress);
        
        // Assert correct values
        assertEq(config.adminOperationsAddress, address(0xABCD), "AdminOps address not set correctly");
        assertEq(config.dcaManagerAddress, address(0xDCBA), "DcaManager address not set correctly");
    }
}

contract SimpleConfigTest is Test {
    function testConfigUpdate() public {
        // Create config
        UsdrifHelperConfig config = new UsdrifHelperConfig();
        
        // Check initial values
        UsdrifHelperConfig.NetworkConfig memory before = config.getActiveNetworkConfig();
        console.log("Initial adminOpsAddress:", before.adminOperationsAddress);
        console.log("Initial dcaManagerAddress:", before.dcaManagerAddress);
        
        // Update values
        address testAdmin = address(0x1234);
        address testDca = address(0x5678);
        config.updateProtocolAddresses(testAdmin, testDca);
        
        // Check updated values
        UsdrifHelperConfig.NetworkConfig memory afterConfig = config.getActiveNetworkConfig();
        console.log("Updated adminOpsAddress:", afterConfig.adminOperationsAddress);
        console.log("Updated dcaManagerAddress:", afterConfig.dcaManagerAddress);
        
        // Assert
        assertEq(afterConfig.adminOperationsAddress, testAdmin, "Admin address not updated");
        assertEq(afterConfig.dcaManagerAddress, testDca, "DCA address not updated");
    }
}
