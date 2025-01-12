//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IERC165} from "lib/forge-std/src/interfaces/IERC165.sol";
import {IFeeHandler} from "../../src/interfaces/IFeeHandler.sol";
import "../Constants.sol";

contract DocHandlerMocTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////
    ///// Settings tests ///////
    ////////////////////////////

    function testDocHandlerSupportsInterface() external {
        assertEq(IERC165(address(docHandler)).supportsInterface(type(ITokenHandler).interfaceId), true);
    }

    function testDocHandlerModifyMinPurchaseAmount() external {
        vm.prank(OWNER);
        docHandler.modifyMinPurchaseAmount(1000);
        uint256 newPurchaseAmount = docHandler.getMinPurchaseAmount();
        assertEq(newPurchaseAmount, 1000);
    }

    function testDocHandlerSetFeeRateParams() external {
        vm.prank(OWNER);
        IFeeHandler(address(docHandler)).setFeeRateParams(5, 5, 5, 5);
        assertEq(IFeeHandler(address(docHandler)).getMinFeeRate(), 5);
        assertEq(IFeeHandler(address(docHandler)).getMaxFeeRate(), 5);
        assertEq(IFeeHandler(address(docHandler)).getMinAnnualAmount(), 5);
        assertEq(IFeeHandler(address(docHandler)).getMaxAnnualAmount(), 5);
    }

    function testDocHandlerSetFeeCollectorAddress() external {
        address newFeeCollector = makeAddr("newFeeCollector");
        vm.prank(OWNER);
        IFeeHandler(address(docHandler)).setFeeCollectorAddress(newFeeCollector);
        assertEq(IFeeHandler(address(docHandler)).getFeeCollectorAddress(), newFeeCollector);
    }
}
