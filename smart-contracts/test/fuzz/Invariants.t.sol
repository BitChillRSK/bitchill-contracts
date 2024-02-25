// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {RbtcDca} from "src/RbtcDca.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {DeployRbtcDca} from "../../script/DeployRbtcDca.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    RbtcDca rbtcDca;
    MockDocToken docToken;
    DeployRbtcDca deployer;
    HelperConfig helperConfig;
    Handler handler;

    function setUp() external {
        deployer = new DeployRbtcDca();
        (rbtcDca, helperConfig) = deployer.run();
        (address docTokenAddress,) = helperConfig.activeNetworkConfig();
        docToken = MockDocToken(docTokenAddress);
        handler = new Handler(rbtcDca, docToken);
        targetContract(address(handler));
        // bytes4[] memory selectors = new bytes4[](2);
        // selectors[0] = Handler.despositDOC.selector;
        // selectors[1] = Handler.withdrawDOC.selector;
        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function removeDuplicates(address[] memory arr) public pure returns (address[] memory) {
        uint256 length = arr.length;
        address[] memory result = new address[](length);
        uint256 index = 0;

        for (uint256 i = 0; i < length; i++) {
            bool isDuplicate = false;
            for (uint256 j = 0; j < i; j++) {
                if (arr[i] == arr[j]) {
                    isDuplicate = true;
                    break;
                }
            }
            if (!isDuplicate) {
                result[index] = arr[i];
                index++;
            }
        }

        address[] memory finalResult = new address[](index);
        for (uint256 i = 0; i < index; i++) {
            finalResult[i] = result[i];
        }

        return finalResult;
    }

    function invariant_DcaContractDocBalanceEqualsSumOfAllUsers() public {
        // get the total amount of DOC deposited in the contract
        // compare it to the sum of all users' balances
        address[] memory users = rbtcDca.getUsers();
        users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            sumOfUsersBalances += rbtcDca.getDocBalance();
        }
        assertEq(docToken.balanceOf(address(rbtcDca)), sumOfUsersBalances);
    }

    function invariant_DcaContractRbtcBalanceEqualsSumOfAllUsers() public {
        // get the contract's rBTC balance
        // compare it to the sum of all users' balances
        address[] memory users = rbtcDca.getUsers();
        users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            sumOfUsersBalances += rbtcDca.getRbtcBalance();
        }
        assertEq(address(rbtcDca).balance, sumOfUsersBalances);
    }

    function invariant_gettersCantRevert() public view {
        rbtcDca.getDocBalance();
        rbtcDca.getRbtcBalance();
        rbtcDca.getPurchaseAmount();
        rbtcDca.getPurchasePeriod();
        rbtcDca.getUsersDcaDetails();
        rbtcDca.getUsers();
        rbtcDca.getTotalNumberOfDeposits();
    }
}
