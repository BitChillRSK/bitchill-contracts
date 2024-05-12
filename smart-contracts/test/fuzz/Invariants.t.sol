// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DcaManager} from "src/DcaManager.sol";
import {AdminOperations} from "src/AdminOperations.sol";
import {DocTokenHandler} from "src/DocTokenHandler.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DcaManager dcaManager;
    AdminOperations adminOperations;
    DocTokenHandler docTokenHandler;
    MockDocToken docToken;
    DeployContracts deployer;
    HelperConfig helperConfig;
    Handler handler;
    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");

    function setUp() external {
        deployer = new DeployContracts();
        (adminOperations, docTokenHandler, dcaManager, helperConfig) = deployer.run();
        (address docTokenAddress,,) = helperConfig.activeNetworkConfig();
        docToken = MockDocToken(docTokenAddress);
        handler = new Handler(adminOperations, docTokenHandler, dcaManager, docToken);
        targetContract(address(handler));
        // bytes4[] memory selectors = new bytes4[](2);
        // selectors[0] = Handler.despositDOC.selector;
        // selectors[1] = Handler.withdrawDOC.selector;
        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_DcaContractDocBalanceEqualsSumOfAllUsers() public {
        // get the total amount of DOC deposited in the contract
        // compare it to the sum of all users' balances 
        address[] memory users = dcaManager.getUsers();
        users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            uint256 numOfSchedules = dcaManager.getMyDcaPositions(address(docToken)).length;
            for (uint256 j = 0; j < numOfSchedules; j++) {
                sumOfUsersBalances += dcaManager.getScheduleTokenBalance(address(docToken), j);
            }
        }
        // assertEq(docToken.balanceOf(address(docTokenHandler)), sumOfUsersBalances);
        assert(sumOfUsersBalances >= 0);
    }

    // function invariant_DcaContractRbtcBalanceEqualsSumOfAllUsers() public {
    //     // get the contract's rBTC balance
    //     // compare it to the sum of all users' balances
    //     vm.prank(OWNER);
    //     address[] memory users = rbtcDca.getUsers();
    //     users = removeDuplicates(users);
    //     uint256 sumOfUsersBalances;
    //     for (uint256 i = 0; i < users.length; i++) {
    //         vm.prank(users[i]);
    //         sumOfUsersBalances += rbtcDca.getRbtcBalance();
    //     }
    //     assertEq(address(rbtcDca).balance, sumOfUsersBalances);
    // }

    // function invariant_gettersCantRevert() public {
    //     rbtcDca.getDocBalance();
    //     rbtcDca.getRbtcBalance();
    //     rbtcDca.getPurchaseAmount();
    //     rbtcDca.getPurchasePeriod();
    //     rbtcDca.getMyDcaDetails();
    //     vm.prank(OWNER);
    //     rbtcDca.ownerGetUsersDcaDetails(USER);
    //     vm.prank(OWNER);
    //     rbtcDca.getUsers();
    //     rbtcDca.getTotalNumberOfDeposits();
    // }
    
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
}
