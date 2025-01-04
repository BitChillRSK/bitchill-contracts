//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {DocHandlerMoc} from "../../src/DocHandlerMoc.sol";
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
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), TROPYKUS_INDEX, address(dummyERC165Contract));

        vm.expectRevert();
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), TROPYKUS_INDEX, address(dcaManager));
    }

    function testUpdateTokenHandlerFailsIfAddressIsEoa() external {
        address dummyAddress = makeAddr("dummyAddress");
        bytes memory encodedRevert =
            abi.encodeWithSelector(IAdminOperations.AdminOperations__EoaCannotBeHandler.selector, dummyAddress);
        vm.expectRevert(encodedRevert);
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), TROPYKUS_INDEX, dummyAddress);
    }

    function testTokenHandlerUpdated() external {
        address prevDocHandlerMoc = adminOperations.getTokenHandler(address(mockDocToken), TROPYKUS_INDEX);
        vm.startBroadcast();
        DocHandlerMoc newDocHandlerMoc = new DocHandlerMoc(
            address(dcaManager),
            address(mockDocToken),
            address(mockKdocToken),
            MIN_PURCHASE_AMOUNT,
            address(mockMocProxy),
            FEE_COLLECTOR,
            ITokenHandler.FeeSettings({
                minFeeRate: MIN_FEE_RATE,
                maxFeeRate: MAX_FEE_RATE,
                minAnnualAmount: MIN_ANNUAL_AMOUNT,
                maxAnnualAmount: MAX_ANNUAL_AMOUNT
            }),
            DOC_YIELDS_INTEREST
        );
        vm.stopBroadcast();
        assert(prevDocHandlerMoc != address(newDocHandlerMoc));
        // vm.prank(OWNER);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(mockDocToken), TROPYKUS_INDEX, address(newDocHandlerMoc));
        assertEq(adminOperations.getTokenHandler(address(mockDocToken), TROPYKUS_INDEX), address(newDocHandlerMoc));
    }
}
