//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

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

    event AdminOperations__LendingProtocolAdded(uint256 indexed index, string indexed name);

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
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(
            address(stablecoin), s_lendingProtocolIndex, address(dummyERC165Contract)
        );

        vm.expectRevert();
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(stablecoin), s_lendingProtocolIndex, address(dcaManager));
    }

    function testUpdateTokenHandlerFailsIfAddressIsEoa() external {
        address dummyAddress = makeAddr("dummyAddress");
        bytes memory encodedRevert =
            abi.encodeWithSelector(IAdminOperations.AdminOperations__EoaCannotBeHandler.selector, dummyAddress);
        vm.expectRevert(encodedRevert);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(stablecoin), s_lendingProtocolIndex, dummyAddress);
    }

    function testTokenHandlerUpdated() external {
        address prevTropykusDocHandlerMoc = adminOperations.getTokenHandler(address(stablecoin), s_lendingProtocolIndex);
        vm.startBroadcast();
        TropykusDocHandlerMoc newTropykusDocHandlerMoc = new TropykusDocHandlerMoc(
            address(dcaManager),
            address(stablecoin),
            address(lendingToken),
            MIN_PURCHASE_AMOUNT,
            FEE_COLLECTOR,
            address(mocProxy),
            IFeeHandler.FeeSettings({
                minFeeRate: MIN_FEE_RATE,
                maxFeeRate: MAX_FEE_RATE,
                purchaseLowerBound: PURCHASE_LOWER_BOUND,
                purchaseUpperBound: PURCHASE_UPPER_BOUND
            })
        );
        vm.stopBroadcast();
        assert(prevTropykusDocHandlerMoc != address(newTropykusDocHandlerMoc));
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(
            address(stablecoin), s_lendingProtocolIndex, address(newTropykusDocHandlerMoc)
        );
        assertEq(
            adminOperations.getTokenHandler(address(stablecoin), s_lendingProtocolIndex),
            address(newTropykusDocHandlerMoc)
        );
    }

    function testSetRoles() external {
        vm.prank(OWNER);
        adminOperations.setAdminRole(address(1));
        assert(adminOperations.hasRole(adminOperations.ADMIN_ROLE(), address(1)));
        vm.prank(ADMIN);
        adminOperations.setSwapperRole(address(2));
        assert(adminOperations.hasRole(adminOperations.SWAPPER_ROLE(), address(2)));
    }

    function testRevokeAdminRole() external {
        vm.prank(OWNER);
        adminOperations.revokeAdminRole(ADMIN);
        assertFalse(adminOperations.hasRole(adminOperations.ADMIN_ROLE(), ADMIN));
    }

    function testRevokeSwapperRole() external {
        vm.prank(ADMIN);
        adminOperations.revokeSwapperRole(SWAPPER);
        assertFalse(adminOperations.hasRole(adminOperations.SWAPPER_ROLE(), address(2)));
    }

    function testRevokeAdminRoleFailsIfNotOwner() external {
        vm.prank(ADMIN);
        vm.expectRevert("Ownable: caller is not the owner");
        adminOperations.revokeAdminRole(ADMIN);
    }

    function testRevokeSwapperRoleFailsIfNotAdmin() external {
        vm.prank(makeAddr("notAdmin"));
        vm.expectRevert();
        adminOperations.revokeSwapperRole(address(2));
    }

    function testAssignTokenHandlerFailsIfLendingProtocolNotAdded() external {
        bytes memory encodedRevert =
            abi.encodeWithSelector(IAdminOperations.AdminOperations__LendingProtocolNotAllowed.selector, 3);
        vm.expectRevert(encodedRevert);
        vm.prank(ADMIN);
        adminOperations.assignOrUpdateTokenHandler(address(stablecoin), 3, address(docHandler));
    }

    function testAddOrUpdateLendingProtocol() external {
        vm.expectEmit(true, true, true, false);
        emit AdminOperations__LendingProtocolAdded(3, "dummyProtocol");
        vm.prank(ADMIN);
        adminOperations.addOrUpdateLendingProtocol("dummyProtocol", 3);
        assertEq(adminOperations.getLendingProtocolIndex("dummyProtocol"), 3);
        assertEq(adminOperations.getLendingProtocolName(3), "dummyProtocol");
    }

    function testLendingProtocolIndexCannotBeZero() external {
        vm.expectRevert(IAdminOperations.AdminOperations__LendingProtocolIndexCannotBeZero.selector);
        vm.prank(ADMIN);
        adminOperations.addOrUpdateLendingProtocol("dummyProtocol", 0);
    }

    function testLendingProtocolStringNonEmpty() external {
        vm.expectRevert(IAdminOperations.AdminOperations__LendingProtocolNameNotSet.selector);
        vm.prank(ADMIN);
        adminOperations.addOrUpdateLendingProtocol("", 3);
    }
}
