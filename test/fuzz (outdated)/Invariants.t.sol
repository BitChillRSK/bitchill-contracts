// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {DcaManager} from "src/DcaManager.sol";
// import {AdminOperations} from "src/AdminOperations.sol";
// import {TropykusDocHandlerMoc} from "src/TropykusDocHandlerMoc.sol";
// // import {TropykusDocHandlerMocDex} from "../../src/TropykusDocHandlerMocDex.sol";
// import {IDocHandler} from "src/interfaces/IDocHandler.sol";
// import {MockStablecoin} from "../mocks/MockStablecoin.sol";
// import {MockKdocToken} from "../mocks/MockKdocToken.sol";
// import {MockMocProxy} from "../mocks/MockMocProxy.sol";
// import {DeployMocSwaps} from "../../script/DeployMocSwaps.s.sol";
// import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
// import {Handler} from "./Handler.t.sol";
// import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
// import "../Constants.sol";

// contract InvariantTest is StdInvariant, Test {
//     DcaManager dcaManager;
//     AdminOperations adminOperations;
//     TropykusDocHandlerMoc docHandlerMoc;
//     // TropykusDocHandlerMocDex docHandlerMocDex;
//     MockStablecoin MockStablecoin;
//     MockKdocToken mockKdocToken;
//     MockMocProxy mocProxy;
//     DeployMocSwaps deployer;
//     MocHelperConfig helperConfig;
//     Handler handler;
//     uint256 constant NUM_USERS = 100;
//     address[] public s_users;
//     // address USER = makeAddr("user");
//     address OWNER = makeAddr(OWNER_STRING);
//     address ADMIN = makeAddr(ADMIN_STRING);
//     address SWAPPER = makeAddr(SWAPPER_STRING);
//     uint256 constant USER_TOTAL_AMOUNT = 1_000_000 ether; // 1 million DOC owned by each user in total
//     uint256 constant INITIAL_DOC_DEPOSIT = 1000 ether;
//     uint256 constant INITIAL_PURCHASE_AMOUNT = 100 ether;
//     uint256 constant INITIAL_PURCHASE_PERIOD = 1 weeks;
//     uint256 constant MOC_START_RBTC_BALANCE = 500 ether;
//     uint256 setUpTimestamp;
//     string lendingProtocol = vm.envString("LENDING_PROTOCOL");
//     uint256 s_lendingProtocolIndex;

//     function setUp() external {
//         if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("tropykus"))) {
//             s_lendingProtocolIndex = TROPYKUS_INDEX;
//         } else if (keccak256(abi.encodePacked(lendingProtocol)) == keccak256(abi.encodePacked("sovryn"))) {
//             s_lendingProtocolIndex = SOVRYN_INDEX;
//         } else {
//             revert("Lending protocol not allowed");
//         }

//         setUpTimestamp = block.timestamp;
//         deployer = new DeployMocSwaps();
//         address docHandlerAddress;
//         (adminOperations, docHandlerAddress, dcaManager, helperConfig) = deployer.run();
//         docHandlerMoc = TropykusDocHandlerMoc(payable(docHandlerAddress));
//         (address docTokenAddress, address mocProxyAddress, address kDocToken, ) =
//             helperConfig.activeNetworkConfig();
//         MockStablecoin = MockStablecoin(docTokenAddress);
//         mockKdocToken = MockKdocToken(kDocToken);

//         vm.prank(OWNER);
//         adminOperations.setAdminRole(ADMIN);
//         vm.prank(ADMIN);
//         adminOperations.setSwapperRole(SWAPPER);

//         // Assign DOC token handler
//         // vm.prank(OWNER);
//         vm.prank(ADMIN);
//         adminOperations.assignOrUpdateTokenHandler(docTokenAddress, s_lendingProtocolIndex, address(docHandlerMoc));

//         // Initialize users and distribute 10000 DOC tokens
//         for (uint256 i = 0; i < NUM_USERS; i++) {
//             // address user = address(uint160(uint256(keccak256(abi.encodePacked("user", i)))));
//             string memory userIndex = Strings.toString(i);
//             string memory userLabel = string(abi.encodePacked("user", userIndex));
//             address user = makeAddr(userLabel);
//             // address user = makeAddr(string(abi.encodePacked("user", i)));
//             // console.log(string(abi.encodePacked("user", i)));
//             s_users.push(user);
//             MockStablecoin.mint(user, USER_TOTAL_AMOUNT);
//         }

//         // Mint 10000 DOC for the user
//         // MockStablecoin.mint(USER, USER_TOTAL_AMOUNT);

//         // Deal rBTC to MoC proxy contract
//         vm.deal(mocProxyAddress, MOC_START_RBTC_BALANCE);

//         // Give the MoC proxy contract allowance to move DOC from docHandlerMoc (this is mocking behaviour -> check that such approval is not necessary in production)
//         vm.prank(address(docHandlerMoc));
//         MockStablecoin.approve(mocProxyAddress, type(uint256).max);

//         // Deploy the invariant tests handler contract and set it as target contract for the tests
//         handler = new Handler(adminOperations, docHandlerMoc, dcaManager, MockStablecoin, s_users);
//         targetContract(address(handler));

//         // vm.startPrank(USER);
//         // // Here we make the starting point of the invariant tests that the user has created a DCA schedule depositing 1000 DOC to spend 100 DOC every week
//         // MockStablecoin.approve(address(docHandlerMoc), USER_TOTAL_AMOUNT);
//         // dcaManager.createOrUpdateDcaSchedule(docTokenAddress, 0, INITIAL_DOC_DEPOSIT, INITIAL_PURCHASE_AMOUNT, INITIAL_PURCHASE_PERIOD);
//         // vm.stopPrank();

//         // bytes4[] memory selectors = new bytes4[](2);
//         // selectors[0] = Handler.despositDOC.selector;
//         // selectors[1] = Handler.withdrawDOC.selector;
//         // targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
//     }

//     function invariant_kDocContractDocBalanceGreaterOrEqualsSumOfAllUsers() public {
//         // get the total amount of DOC deposited in the kDOC contract
//         // compare it to the sum of all users' balances
//         vm.prank(OWNER);
//         address[] memory users = dcaManager.getUsers();
//         uint256 sumOfUsersDepositedDoc;
//         for (uint256 i; i < users.length; ++i) {
//             vm.startPrank(users[i]);
//             uint256 numOfSchedules = dcaManager.getMyDcaSchedules(address(MockStablecoin)).length;
//             for (uint256 j; j < numOfSchedules; ++j) {
//                 sumOfUsersDepositedDoc += dcaManager.getScheduleTokenBalance(address(MockStablecoin), j);
//             }
//             vm.stopPrank();
//         }
//         // DOC deposited in Bitchill is immediately lent in Tropykus
//         assertEq(MockStablecoin.balanceOf(address(docHandlerMoc)), 0); // No DOC in TropykusDocHandlerMoc

//         // Update the amount of DOC in the mock kDOC contract according to the interest that has been generated
//         uint256 interestFactor = 1e18 + (block.timestamp - setUpTimestamp) * 5 * 1e18 / (100 * 31536000); // 1 + timeInYears * yearlyIncrease
//         uint256 currentDocBalanceInTropykus = MockStablecoin.balanceOf(address(mockKdocToken));
//         uint256 docToAdd = currentDocBalanceInTropykus * interestFactor / 1e18 - currentDocBalanceInTropykus;
//         MockStablecoin.mint(address(mockKdocToken), docToAdd);

//         assertEq(MockStablecoin.balanceOf(address(mockKdocToken)), sumOfUsersDepositedDoc); // All of the users's deposited DOC is in Tropykus
//         // kDOC to DOC correspondence holds
//         uint256 sumOfUsersKdoc;
//         for (uint256 i; i < users.length; ++i) {
//             sumOfUsersKdoc += docHandlerMoc.getUsersLendingTokenBalance(users[i]);
//         }
//         console.log("Interest Factor: ", interestFactor);
//         console.log("exchangeRateCurrent: ", mockKdocToken.exchangeRateCurrent());
//         console.log("sumOfUsersDepositedDoc: ", sumOfUsersDepositedDoc);
//         console.log("sumOfUsersKdoc: ", sumOfUsersKdoc);
//         console.log(
//             "Total DOC in Tropykus: ", sumOfUsersKdoc * mockKdocToken.exchangeRateCurrent() / EXCHANGE_RATE_DECIMALS
//         );

//         assertGe(
//             sumOfUsersKdoc * mockKdocToken.exchangeRateCurrent() / EXCHANGE_RATE_DECIMALS,
//             // sumOfUsersDepositedDoc * interestFactor / 1e18
//             sumOfUsersDepositedDoc
//         );
//         // console.log("Sum of users' DOC balances:", DepositedDoc);
//         // console.log("DOC balance of the DOC token handler contract:", MockStablecoin.balanceOf(address(docHandlerMoc)));
//     }

//     function invariant_TropykusDocHandlerMocRbtcBalanceNearlyEqualsSumOfAllUsers() public {
//         // get the contract's rBTC balance and compare it to the sum of all users' balances
//         vm.prank(OWNER);
//         address[] memory users = dcaManager.getUsers();
//         uint256 sumOfUsersBalances;
//         for (uint256 i = 0; i < users.length; i++) {
//             vm.prank(users[i]);
//             sumOfUsersBalances += docHandlerMoc.getAccumulatedRbtcBalance();
//         }
//         // We can't just use an assertEq because charging fees causes a slight precision loss
//         assertApproxEqRel(
//             address(docHandlerMoc).balance,
//             sumOfUsersBalances,
//             0.0001e16 // Allow a maximum difference of 0.0001%
//         );
//         // assertGe(address(docHandlerMoc).balance, sumOfUsersBalances); // The rBTC in the DOC token handler contract must be at least as much as the sum balances of the users
//         // assertLe(address(docHandlerMoc).balance * 9999 / 10000, sumOfUsersBalances); // The rBTC in the DOC token handler contract can only be slightly higher than the sum of balances (therefore, 99.99% of said rBTC should be lower than the sum)
//         console.log("Sum of users' rBTC balances:", sumOfUsersBalances);
//         console.log("rBTC balance of the DOC token handler contract:", address(docHandlerMoc).balance);
//     }

//     // function invariant_gettersCantRevert() public {
//     //     rbtcDca.getDocBalance();
//     //     rbtcDca.getRbtcBalance();
//     //     rbtcDca.getPurchaseAmount();
//     //     rbtcDca.getPurchasePeriod();
//     //     rbtcDca.getMyDcaDetails();
//     //     vm.prank(OWNER);
//     //     rbtcDca.ownerGetUsersDcaDetails(USER);
//     //     vm.prank(OWNER);
//     //     rbtcDca.getUsers();
//     // }

//     function removeDuplicates(address[] memory arr) public pure returns (address[] memory) {
//         uint256 length = arr.length;
//         address[] memory result = new address[](length);
//         uint256 index = 0;

//         for (uint256 i = 0; i < length; i++) {
//             bool isDuplicate = false;
//             for (uint256 j = 0; j < i; j++) {
//                 if (arr[i] == arr[j]) {
//                     isDuplicate = true;
//                     break;
//                 }
//             }
//             if (!isDuplicate) {
//                 result[index] = arr[i];
//                 index++;
//             }
//         }

//         address[] memory finalResult = new address[](index);
//         for (uint256 i = 0; i < index; i++) {
//             finalResult[i] = result[i];
//         }

//         return finalResult;
//     }
// }
