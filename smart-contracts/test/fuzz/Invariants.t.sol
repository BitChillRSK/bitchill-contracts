// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DCAContract} from "src/DCAContract.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {DeployDca} from "../../script/DeployDca.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DCAContract dcaContract;
    MockDocToken docToken;
    DeployDca deployer;
    HelperConfig helperConfig;
    Handler handler;

    function setUp() external {
        deployer = new DeployDca();
        (dcaContract, helperConfig) = deployer.run();
        (address docTokenAddress,) = helperConfig.activeNetworkConfig();
        docToken = MockDocToken(docTokenAddress);
        handler = new Handler(dcaContract, docToken);
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
        address[] memory users = dcaContract.getUsers();
        users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            sumOfUsersBalances += dcaContract.getDocBalance();
        }
        assertEq(docToken.balanceOf(address(dcaContract)), sumOfUsersBalances);
    }

    function invariant_DcaContractRbtcBalanceEqualsSumOfAllUsers() public {
        // get the contract's rBTC balance
        // compare it to the sum of all users' balances
        address[] memory users = dcaContract.getUsers();
        users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            sumOfUsersBalances += dcaContract.getRbtcBalance();
        }
        assertEq(address(dcaContract).balance, sumOfUsersBalances);
    }

    function invariant_gettersCantRevert() public view {
        dcaContract.getDocBalance();
        dcaContract.getRbtcBalance();
        dcaContract.getPurchaseAmount();
        dcaContract.getPurchasePeriod();
        dcaContract.getUsers();
        dcaContract.getTotalNumberOfDeposits();
    }
}
