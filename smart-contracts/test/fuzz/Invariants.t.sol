// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DcaManager} from "src/DcaManager.sol";
import {AdminOperations} from "src/AdminOperations.sol";
import {DocTokenHandler} from "src/DocTokenHandler.sol";
import {MockDocToken} from "../mocks/MockDocToken.sol";
import {MockMocProxy} from "../mocks/MockMocProxy.sol";
import {DeployContracts} from "../../script/DeployContracts.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Handler} from "./Handler.t.sol";

contract InvariantTest is StdInvariant, Test {
    DcaManager dcaManager;
    AdminOperations adminOperations;
    DocTokenHandler docTokenHandler;
    MockDocToken mockDocToken;
    MockMocProxy mockMocProxy;
    DeployContracts deployer;
    HelperConfig helperConfig;
    Handler handler;
    address USER = makeAddr("user");
    address OWNER = makeAddr("owner");
    uint256 constant USER_TOTAL_DOC = 10000 ether; // 10000 DOC owned by the user in total
    uint256 constant INITIAL_DOC_DEPOSIT = 1000 ether;
    uint256 constant INITIAL_PURCHASE_AMOUNT = 100 ether;
    uint256 constant INITIAL_PURCHASE_PERIOD = 5 seconds;
    uint256 constant MOC_START_RBTC_BALANCE = 500 ether;

    function setUp() external {
        deployer = new DeployContracts();
        (adminOperations, docTokenHandler, dcaManager, helperConfig) = deployer.run();
        (address docTokenAddress, address mocProxyAddress,) = helperConfig.activeNetworkConfig();
        mockDocToken = MockDocToken(docTokenAddress);
        handler = new Handler(adminOperations, docTokenHandler, dcaManager, mockDocToken);
        targetContract(address(handler));
        vm.prank(OWNER);
        adminOperations.assignOrUpdateTokenHandler(docTokenAddress, address(docTokenHandler));

        // Mint 10000 DOC for the user
        mockDocToken.mint(USER, USER_TOTAL_DOC);

        // Deal rBTC to MoC proxy contract
        vm.deal(mocProxyAddress, MOC_START_RBTC_BALANCE);

        // Give the MoC proxy contract allowance to move DOC from docTokenHandler (this is mocking behaviour)
        vm.prank(address(docTokenHandler));
        mockDocToken.approve(mocProxyAddress, type(uint256).max);

        vm.startPrank(USER);
        // Here we make the starting point of the invariant tests that the user has created a DCA schedule depositing 1000 DOC to spend 100 DOC every 5 seconds
        mockDocToken.approve(address(docTokenHandler), USER_TOTAL_DOC);
        dcaManager.createOrUpdateDcaSchedule(docTokenAddress, 0, INITIAL_DOC_DEPOSIT, INITIAL_PURCHASE_AMOUNT, INITIAL_PURCHASE_PERIOD);
        vm.stopPrank();
        // bytes4[] memory selectors = new bytes4[](2);
        // selectors[0] = Handler.despositDOC.selector;
        // selectors[1] = Handler.withdrawDOC.selector;
        // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_DcaContractDocBalanceEqualsSumOfAllUsers() public {
        // get the total amount of DOC deposited in the contract
        // compare it to the sum of all users' balances 
        vm.startPrank(OWNER);
        address[] memory users = dcaManager.getUsers();
        vm.stopPrank();
        // users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            uint256 numOfSchedules = dcaManager.getMyDcaSchedules(address(mockDocToken)).length;
            for (uint256 j = 0; j < numOfSchedules; j++) {
                sumOfUsersBalances += dcaManager.getScheduleTokenBalance(address(mockDocToken), j);
            }
            vm.stopPrank();
        }
        assertEq(mockDocToken.balanceOf(address(docTokenHandler)), sumOfUsersBalances);
    }

    function invariant_DocTokenHandlerRbtcBalanceEqualsSumOfAllUsers() public {
        // get the contract's rBTC balance
        // compare it to the sum of all users' balances
        vm.prank(OWNER);
        address[] memory users = dcaManager.getUsers();
        // users = removeDuplicates(users);
        uint256 sumOfUsersBalances;
        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            sumOfUsersBalances += docTokenHandler.getAccumulatedRbtcBalance();
        }
        assertEq(address(docTokenHandler).balance, sumOfUsersBalances);
    }

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
