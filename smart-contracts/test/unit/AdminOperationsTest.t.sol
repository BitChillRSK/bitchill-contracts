//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {IFeeHandler} from "../../src/interfaces/IFeeHandler.sol";
import {TropykusDocHandlerMoc} from "../../src/TropykusDocHandlerMoc.sol";
import {IAdminOperations} from "../../src/interfaces/IAdminOperations.sol";
import "./TestsHelper.t.sol";

contract AdminOperationsTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/
    function testUpdateTokenHandlerMustSupportInterface() external {
        vm.startBroadcast();
        DummyERC165Contract dummyERC165Contract = new DummyERC165Contract();
        vm.stopBroadcast();
        bytes memory encodedRevert = abi.encodeWithSelector(
            IAdminOperations.AdminOperations__ContractIsNotTokenHandler.selector, address(dummyERC165Contract)
        );

        vm.expectRevert(encodedRevert);
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(
            address(docToken), s_lendingProtocolIndex, address(dummyERC165Contract)
        );

        vm.expectRevert();
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(docToken), s_lendingProtocolIndex, address(dcaManager));
    }

    function testUpdateTokenHandlerFailsIfAddressIsEoa() external {
        address dummyAddress = makeAddr("dummyAddress");
        bytes memory encodedRevert =
            abi.encodeWithSelector(IAdminOperations.AdminOperations__EoaCannotBeHandler.selector, dummyAddress);
        vm.expectRevert(encodedRevert);
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(docToken), s_lendingProtocolIndex, dummyAddress);
    }

    function testTokenHandlerUpdated() external {
        address prevTropykusDocHandlerMoc = adminOperations.getTokenHandler(address(docToken), s_lendingProtocolIndex);
        vm.startBroadcast();
        TropykusDocHandlerMoc newTropykusDocHandlerMoc = new TropykusDocHandlerMoc(
            address(dcaManager),
            address(docToken),
            address(lendingToken),
            MIN_PURCHASE_AMOUNT,
            address(mockMocProxy),
            FEE_COLLECTOR,
            IFeeHandler.FeeSettings({
                minFeeRate: MIN_FEE_RATE,
                maxFeeRate: MAX_FEE_RATE,
                minAnnualAmount: MIN_ANNUAL_AMOUNT,
                maxAnnualAmount: MAX_ANNUAL_AMOUNT
            })
        );
        vm.stopBroadcast();
        assert(prevTropykusDocHandlerMoc != address(newTropykusDocHandlerMoc));
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(
            address(docToken), s_lendingProtocolIndex, address(newTropykusDocHandlerMoc)
        );
        assertEq(
            adminOperations.getTokenHandler(address(docToken), s_lendingProtocolIndex),
            address(newTropykusDocHandlerMoc)
        );
    }
}
