// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IPurchaseUniswap} from "../../src/interfaces/IPurchaseUniswap.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import "../Constants.sol";

contract SlippageSettingsTest is DcaDappTest {
    // Skip tests if not using dexSwaps
    modifier onlyDexSwaps() {
        if (keccak256(abi.encodePacked(swapType)) != keccak256(abi.encodePacked("dexSwaps"))) {
            console.log("Skipping test: only applicable for dexSwaps");
            return;
        }
        _;
    }

    function setUp() public override {
        super.setUp();
    }

    function testSlippageSettings() public onlyDexSwaps {
        // Get the initial values
        uint256 initialPercent = IPurchaseUniswap(address(docHandler)).getAmountOutMinimumPercent();
        uint256 initialSafetyCheck = IPurchaseUniswap(address(docHandler)).getAmountOutMinimumSafetyCheck();
        
        // Verify initial values - should match what we set in the contract
        assertEq(initialPercent, 0.997 * 1e18, "Initial slippage percent should be 99.7%");
        assertEq(initialSafetyCheck, 0.99 * 1e18, "Initial safety check should be 99%");
        
        // Set new values
        uint256 newPercent = 0.995 * 1e18; // 99.5%
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(newPercent);
        
        // Verify the new value was set
        assertEq(
            IPurchaseUniswap(address(docHandler)).getAmountOutMinimumPercent(), 
            newPercent, 
            "Slippage percent should be updated"
        );
    }
    
    function testSetAmountOutMinimumPercentRevertsIfTooHigh() public onlyDexSwaps {
        // Try to set slippage too high (over 100%)
        vm.expectRevert(IPurchaseUniswap.PurchaseUniswap__AmountOutMinimumPercentTooHigh.selector);
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(1.01e18);
    }
    
    function testSetAmountOutMinimumPercentRevertsIfTooLow() public onlyDexSwaps {
        // Get the safety check value
        uint256 safetyCheck = IPurchaseUniswap(address(docHandler)).getAmountOutMinimumSafetyCheck();
        
        // Try to set slippage below safety check
        vm.expectRevert(IPurchaseUniswap.PurchaseUniswap__AmountOutMinimumPercentTooLow.selector);
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(safetyCheck - 1);
    }
    
    function testSetAmountOutMinimumSafetyCheck() public onlyDexSwaps {
        // Set new safety check
        uint256 newSafetyCheck = 0.95 * 1e18; // 95%
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumSafetyCheck(newSafetyCheck);
        
        // Verify it was set
        assertEq(
            IPurchaseUniswap(address(docHandler)).getAmountOutMinimumSafetyCheck(), 
            newSafetyCheck, 
            "Safety check should be updated"
        );
        
        // Now we can set a lower slippage percent
        uint256 newPercent = 0.96 * 1e18; // 96%
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(newPercent);
        
        // Verify it was set
        assertEq(
            IPurchaseUniswap(address(docHandler)).getAmountOutMinimumPercent(), 
            newPercent, 
            "Slippage percent should be updated to lower value"
        );
    }
    
    function testSetAmountOutMinimumSafetyCheckRevertsIfTooHigh() public onlyDexSwaps {
        // Try to set safety check too high
        vm.expectRevert(IPurchaseUniswap.PurchaseUniswap__AmountOutMinimumSafetyCheckTooHigh.selector);
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumSafetyCheck(1.01e18);
    }
    
    function testOnlyOwnerCanSetSlippageSettings() public onlyDexSwaps {
        // Try to set slippage as non-owner
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(0.98e18);
        
        // Try to set safety check as non-owner
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumSafetyCheck(0.95e18);
    }
}
