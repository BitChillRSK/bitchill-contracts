// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IPurchaseUniswap} from "../../src/interfaces/IPurchaseUniswap.sol";
import {IPurchaseRbtc} from "../../src/interfaces/IPurchaseRbtc.sol";
import "../Constants.sol";

contract SlippageSettingsTest is DcaDappTest {

    event PurchaseUniswap_AmountOutMinimumPercentUpdated(uint256 oldValue, uint256 newValue);
    event PurchaseUniswap_AmountOutMinimumSafetyCheckUpdated(uint256 oldValue, uint256 newValue);

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

    function testSetAmountOutMinimumPercentEmitsEvent() public onlyDexSwaps {
        // Set up expected event parameters
        uint256 oldValue = IPurchaseUniswap(address(docHandler)).getAmountOutMinimumPercent();
        uint256 newValue = 0.995 * 1e18; // 99.5%
        
        // Expect the event with the correct parameters
        vm.expectEmit(false, false, false, true);
        emit PurchaseUniswap_AmountOutMinimumPercentUpdated(oldValue, newValue);
        
        // Execute the function that should emit the event
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumPercent(newValue);
    }

    function testSetAmountOutMinimumSafetyCheckEmitsEvent() public onlyDexSwaps {
        // Set up expected event parameters
        uint256 oldValue = IPurchaseUniswap(address(docHandler)).getAmountOutMinimumSafetyCheck();
        uint256 newValue = 0.95 * 1e18; // 95%
        
        // Expect the event with the correct parameters
        vm.expectEmit(false, false, false, true);
        emit PurchaseUniswap_AmountOutMinimumSafetyCheckUpdated(oldValue, newValue);
        
        // Execute the function that should emit the event
        vm.prank(OWNER);
        IPurchaseUniswap(address(docHandler)).setAmountOutMinimumSafetyCheck(newValue);
    }
}
