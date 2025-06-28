//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";

contract ModifiersTest is DcaDappTest {
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                            ONLYOWNER TESTS
    //////////////////////////////////////////////////////////////*/
    function testonlyOwnerCanSetOperationsAdmin() external {
        address operationsAdminBefore = dcaManager.getOperationsAdminAddress();
        vm.expectRevert("Ownable: caller is not the owner"); // Adapt to v4.9.3 Ownable contract
        vm.prank(USER); // User can't
        dcaManager.setOperationsAdmin(address(dcaManager)); // dummy address, e.g. that of DcaManager
        address operationsAdminAfter = dcaManager.getOperationsAdminAddress();
        assertEq(operationsAdminBefore, operationsAdminAfter);
        vm.prank(OWNER); // Owner can
        dcaManager.setOperationsAdmin(address(dcaManager));
        operationsAdminAfter = dcaManager.getOperationsAdminAddress();
        assertEq(operationsAdminAfter, address(dcaManager));
    }

    function testonlyOwnerCanModifyMinPurchasePeriod() external {
        uint256 newMinPurchasePeriod = 2 days;
        uint256 minPurchasePeriodBefore = dcaManager.getMinPurchasePeriod();
        vm.expectRevert("Ownable: caller is not the owner"); // Adapt to v4.9.3 Ownable contract
        vm.prank(USER); // User can't
        dcaManager.modifyMinPurchasePeriod(newMinPurchasePeriod); // dummy address, e.g. that of DcaManager
        uint256 minPurchasePeriodAfter = dcaManager.getMinPurchasePeriod();
        assertEq(minPurchasePeriodBefore, minPurchasePeriodAfter);
        vm.prank(OWNER); // Owner can
        dcaManager.modifyMinPurchasePeriod(newMinPurchasePeriod);
        minPurchasePeriodAfter = dcaManager.getMinPurchasePeriod();
        assertEq(minPurchasePeriodAfter, newMinPurchasePeriod);
    }
}
