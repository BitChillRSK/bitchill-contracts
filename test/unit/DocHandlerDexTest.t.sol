//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// import {Test, console} from "forge-std/Test.sol";
// import {DcaDappTest} from "./DcaDappTest.t.sol";
// import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
// import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
// import "../Constants.sol";

// contract DocTokenHandlerDexTest is DcaDappTest {
//     string testEnv = vm.envString("TEST_ENV");

//     function setUp() public override {
//         if (keccak256(abi.encodePacked(testEnv)) != keccak256(abi.encodePacked("dexSwaps"))) {
//             return;
//         }
//         super.setUp();
//     }

//     ////////////////////////////
//     ///// Settings tests ///////
//     ////////////////////////////

//     function testDTHDSupportsInterface() external {
//         if (keccak256(abi.encodePacked(testEnv)) != keccak256(abi.encodePacked("dexSwaps"))) {
//             return;
//         }
//         assertEq(docHandlerDex.supportsInterface(type(ITokenHandler).interfaceId), true);
//     }

//     function testDTHDModifyMinPurchaseAmount() external {
//         if (keccak256(abi.encodePacked(testEnv)) != keccak256(abi.encodePacked("dexSwaps"))) {
//             return;
//         }
//         vm.prank(OWNER);
//         docHandlerDex.modifyMinPurchaseAmount(1000);
//         uint256 newPurchaseAmount = docHandlerDex.getMinPurchaseAmount();
//         assertEq(newPurchaseAmount, 1000);
//     }

//     function testDTHDSetFeeRateParams() external {
//         if (keccak256(abi.encodePacked(testEnv)) != keccak256(abi.encodePacked("dexSwaps"))) {
//             return;
//         }
//         vm.prank(OWNER);
//         docHandlerDex.setFeeRateParams(5, 5, 5, 5);
//         assertEq(docHandlerDex.getMinFeeRate(), 5);
//         assertEq(docHandlerDex.getMaxFeeRate(), 5);
//         assertEq(docHandlerDex.getMinAnnualAmount(), 5);
//         assertEq(docHandlerDex.getMaxAnnualAmount(), 5);
//     }

//     function testDTHDSetFeeCollectorAddress() external {
//         if (keccak256(abi.encodePacked(testEnv)) != keccak256(abi.encodePacked("dexSwaps"))) {
//             return;
//         }
//         address newFeeCollector = makeAddr("newFeeCollector");
//         vm.prank(OWNER);
//         docHandlerDex.setFeeCollectorAddress(newFeeCollector);
//         assertEq(docHandlerDex.getFeeCollectorAddress(), newFeeCollector);
//     }
// }
