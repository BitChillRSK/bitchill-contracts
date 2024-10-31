//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import "../Constants.sol";

contract DocHandlerMocTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////
    ///// Settings tests ///////
    ////////////////////////////

    function testDTHSupportsInterface() external {
        assertEq(docHandlerMoc.supportsInterface(type(ITokenHandler).interfaceId), true);
    }

    function testDTHModifyMinPurchaseAmount() external {
        vm.prank(OWNER);
        docHandlerMoc.modifyMinPurchaseAmount(1000);
        uint256 newPurchaseAmount = docHandlerMoc.getMinPurchaseAmount();
        assertEq(newPurchaseAmount, 1000);
    }

    function testDTHSetFeeRateParams() external {
        vm.prank(OWNER);
        docHandlerMoc.setFeeRateParams(5, 5, 5, 5);
        assertEq(docHandlerMoc.getMinFeeRate(), 5);
        assertEq(docHandlerMoc.getMaxFeeRate(), 5);
        assertEq(docHandlerMoc.getMinAnnualAmount(), 5);
        assertEq(docHandlerMoc.getMaxAnnualAmount(), 5);
    }

    function testDTHSetFeeCollectorAddress() external {
        address newFeeCollector = makeAddr("newFeeCollector");
        vm.prank(OWNER);
        docHandlerMoc.setFeeCollectorAddress(newFeeCollector);
        assertEq(docHandlerMoc.getFeeCollectorAddress(), newFeeCollector);
    }
}
