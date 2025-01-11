//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import "../Constants.sol";

contract DocLendingTest is DcaDappTest {
    uint256 constant KDOC_STARTING_EXCHANGE_RATE = 2e16;

    function setUp() public override {
        super.setUp();
    }

    ////////////////////////////
    ///// DOC Lending tests ////
    ////////////////////////////
    function testDepositedDocIsLent() external {
        super.depositDoc();
        assertEq(docToken.balanceOf(address(docHandler)), 0); // DOC balance in handler contract is 0 because DOC is lent to Tropykus
        assertEq(docToken.balanceOf(address(lendingToken)), 2 * DOC_TO_DEPOSIT); // Twice the DOC to deposit since a schedule is created in setUp()
    }

    function testDocDepositIncreasesKdocBalance() external {
        uint256 prevKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.depositDoc();
        uint256 postKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        assertEq(
            lendingToken.balanceOf(address(docHandler)), 2 * DOC_TO_DEPOSIT * 1e18 / lendingToken.exchangeRateStored()
        );
        assertEq(postKdocBalance - prevKdocBalance, DOC_TO_DEPOSIT * 1e18 / lendingToken.exchangeRateStored());
    }

    function testDocWithdrawalRedeemsKdoc() external {
        uint256 prevKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.withdrawDoc();
        uint256 postKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        assertEq(lendingToken.balanceOf(address(docHandler)), 0);
        assertEq(prevKdocBalance - postKdocBalance, DOC_TO_DEPOSIT * 1e18 / lendingToken.exchangeRateStored());
    }

    function testRbtcPurchaseRedeemsKdoc() external {
        uint256 prevKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("prevKdocBalance:", prevKdocBalance);
        super.makeSinglePurchase();
        uint256 postKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("postKdocBalance:", postKdocBalance);
        console.log("diff:", prevKdocBalance - postKdocBalance);
        assertEq(
            lendingToken.balanceOf(address(docHandler)),
            (
                DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE
                    - DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored()
            )
        );
        assertEq(prevKdocBalance - postKdocBalance, DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored());
    }

    function testSeveralRbtcPurchasesRedeemKdoc() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules();
        uint256 prevKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("kDOC balance before purchases", prevKdocBalance);
        super.makeSeveralPurchasesWithSeveralSchedules();
        uint256 postKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("kDOC balance after purchases", postKdocBalance);
        // @notice In this test we don't use assertEq because calculating the exact number on the right hand side would be too much hassle
        // However, we check that the kDOC spent to redeem DOC to make the rBTC purchases is lower than the amount we would have
        // needed if the exchange rate were constant and greater than the amount necesary if all the redemptions had been made at the latest exchange rate (since as time passes fewer kDOCs are necessary to redeem each DOC)
        assertLe(
            prevKdocBalance - postKdocBalance,
            NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE // kdocToken.exchangeRateStored()
        );
        assertGe(
            prevKdocBalance - postKdocBalance,
            NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored()
        );

        // @notice Similarly, here we check that the remaining kDOC balance of the DOC Token Handler contract is lower
        // than it would have been if the redemptions had been made at the highest exchange rate but greater than
        // if the redemptions had been made at the starting exchange rate
        assertLe(
            lendingToken.balanceOf(address(docHandler)),
            DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE
                - NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored()
        );
        assertGe(
            lendingToken.balanceOf(address(docHandler)),
            DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE
                - NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE
        );
    }

    function testRbtcBatchPurchaseRedeemsKdoc() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules(); // This creates NUM_OF_SCHEDULES schedules with purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES
        uint256 prevKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.makeBatchPurchasesOneUser(); // Batched purchases add up to an amount of DOC_TO_SPEND, this function makes two batch purchases
        uint256 postKdocBalance = docHandler.getUsersLendingTokenBalance(USER);
        // assertEq(
        //     prevKdocBalance - postKdocBalance,
        //     (DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE) + (DOC_TO_SPEND * 1e18 / kdocToken.exchangeRateStored()) // First batch purchase in makeBatchPurchasesOneUser is done with the starting exchange rate, the second after some time has passed
        // );
        assertApproxEqRel( // There will be a slight arithmetic imprecision, so assertEq makes the test fail
            prevKdocBalance - postKdocBalance,
            (DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE)
                + (DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored()), // First batch purchase in makeBatchPurchasesOneUser is done with the starting exchange rate, the second after some time has passed
            0.0001e16 // Allow a maximum difference of 0.0001%
        );
        // assertEq(
        //     kdocToken.balanceOf(address(docHandler)),
        //     DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE - (DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE)
        //         - (DOC_TO_SPEND * 1e18 / kdocToken.exchangeRateStored())
        // );

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            assertEq(
                lendingToken.balanceOf(address(docHandler)),
                DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE
                    - (DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE)
                    - (DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored())
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                lendingToken.balanceOf(address(docHandler)),
                DOC_TO_DEPOSIT * 1e18 / KDOC_STARTING_EXCHANGE_RATE
                    - (DOC_TO_SPEND * 1e18 / KDOC_STARTING_EXCHANGE_RATE)
                    - (DOC_TO_SPEND * 1e18 / lendingToken.exchangeRateStored()),
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }

    function testWithdrawInterest() external {
        vm.warp(block.timestamp + 10 weeks); // Jump to 10 weeks in the future (for example) so that some interest has been generated.
        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceBeforeInterestWithdrawal = docToken.balanceOf(USER);
        assertGt(withdrawableInterest, 0);
        vm.prank(USER);
        dcaManager.withdrawInterestFromTokenHandler(address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceAfterInterestWithdrawal = docToken.balanceOf(USER);
        console.log("userDocBalanceAfterInterestWithdrawal:", userDocBalanceAfterInterestWithdrawal);
        assertEq(userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal, withdrawableInterest);
        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        assertEq(withdrawableInterest, 0);
    }

    function testWithdrawTokenAndInterest() external {
        vm.warp(block.timestamp + 10 weeks); // Jump to 10 weeks in the future (for example) so that some interest has been generated.
        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceBeforeInterestWithdrawal = docToken.balanceOf(USER);
        assertGt(withdrawableInterest, 0);
        vm.prank(USER);
        dcaManager.withdrawTokenAndInterest(address(docToken), 0, DOC_TO_SPEND, s_lendingProtocolIndex); // withdraw, for example, the amount of one periodic purchase
        uint256 userDocBalanceAfterInterestWithdrawal = docToken.balanceOf(USER);
        assertEq(
            userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal,
            withdrawableInterest + DOC_TO_SPEND
        );
        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        assertEq(withdrawableInterest, 0);
    }
}
