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
        uint256 ltDocBalanceBeforeDeposit = docToken.balanceOf(address(lendingToken));
        super.depositDoc();
        uint256 ltDocBalanceAfterDeposit = docToken.balanceOf(address(lendingToken));
        assertEq(docToken.balanceOf(address(docHandler)), 0); // DOC balance in handler contract is 0 because DOC is lent to lending protocol
        assertEq(ltDocBalanceAfterDeposit - ltDocBalanceBeforeDeposit, DOC_TO_DEPOSIT);
    }

    function testDocDepositIncreasesLendingTokenBalance() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.depositDoc();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();

        // assertEq(lendingToken.balanceOf(address(docHandler)), 2 * DOC_TO_DEPOSIT * 1e18 / exchangeRate);
        assertApproxEqRel(
            lendingToken.balanceOf(address(docHandler)),
            2 * DOC_TO_DEPOSIT * 1e18 / exchangeRate,
            1 // Allow a maximum difference of 1e-18%
        );

        assertEq(postLendingTokenBalance - prevLendingTokenBalance, DOC_TO_DEPOSIT * 1e18 / exchangeRate);
    }

    function testDocWithdrawalBurnsLendingToken() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.withdrawDoc();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();
        assertEq(lendingToken.balanceOf(address(docHandler)), 0); // @notice: In this test no time has passed, therefore, no interest accrued, so the lending token balance is 0
        assertEq(prevLendingTokenBalance - postLendingTokenBalance, DOC_TO_DEPOSIT * 1e18 / exchangeRate);
    }

    function testRbtcPurchaseBurnsLendingToken() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("prevLendingTokenBalance:", prevLendingTokenBalance);
        super.makeSinglePurchase();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        console.log("postLendingTokenBalance:", postLendingTokenBalance);
        console.log("diff:", prevLendingTokenBalance - postLendingTokenBalance);
        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            startingExchangeRate = lendingToken.exchangeRateCurrent();
            updateTropykusExchangeRate();
        }
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();

        // assertEq(
        //     lendingToken.balanceOf(address(docHandler)),
        //     (DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - DOC_TO_SPEND * 1e18 / exchangeRate)
        // );
        // assertEq(prevLendingTokenBalance - postLendingTokenBalance, DOC_TO_SPEND * 1e18 / exchangeRate);

        assertApproxEqRel(
            lendingToken.balanceOf(address(docHandler)),
            (DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - DOC_TO_SPEND * 1e18 / exchangeRate),
            0.3e16 // Allow a maximum difference of 0.3%
        );

        assertApproxEqRel(
            prevLendingTokenBalance - postLendingTokenBalance,
            DOC_TO_SPEND * 1e18 / exchangeRate,
            0.3e16 // Allow a maximum difference of 0.3%
        );
    }

    function testSeveralRbtcPurchasesBurnLendingToken() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules();
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.makeSeveralPurchasesWithSeveralSchedules();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;
        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            startingExchangeRate = lendingToken.exchangeRateCurrent();
            updateTropykusExchangeRate();
        }
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();
        // @notice In this test we don't use assertEq because calculating the exact number on the right hand side would be too much hassle
        // However, we check that the kDOC spent to redeem DOC to make the rBTC purchases is lower than the amount we would have
        // needed if the exchange rate were constant and greater than the amount necesary if all the redemptions had been made at the latest exchange rate (since as time passes fewer kDOCs are necessary to redeem each DOC)
        assertLe(
            prevLendingTokenBalance - postLendingTokenBalance,
            NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / startingExchangeRate // lendingTokenToken.exchangeRateCurrent()
        );
        assertGe(
            prevLendingTokenBalance - postLendingTokenBalance, NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / exchangeRate
        );

        // @notice Similarly, here we check that the remaining kDOC balance of the DOC Token Handler contract is lower
        // than it would have been if the redemptions had been made at the highest exchange rate but greater than
        // if the redemptions had been made at the starting exchange rate
        assertLe(
            lendingToken.balanceOf(address(docHandler)),
            DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / exchangeRate
        );
        assertGe(
            lendingToken.balanceOf(address(docHandler)),
            DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - NUM_OF_SCHEDULES * DOC_TO_SPEND * 1e18 / startingExchangeRate
        );
    }

    function testRbtcBatchPurchaseBurnsLendingToken() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules(); // This creates NUM_OF_SCHEDULES schedules with purchaseAmount = DOC_TO_SPEND / NUM_OF_SCHEDULES
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.makeBatchPurchasesOneUser(); // Batched purchases add up to an amount of DOC_TO_SPEND, this function makes two batch purchases
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            startingExchangeRate = lendingToken.exchangeRateCurrent();
            updateTropykusExchangeRate();
        }
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();
        // assertEq(
        //     prevLendingTokenBalance - postLendingTokenBalance,
        //     (DOC_TO_SPEND * 1e18 / startingExchangeRate) + (DOC_TO_SPEND * 1e18 / lendingTokenToken.exchangeRateCurrent()) // First batch purchase in makeBatchPurchasesOneUser is done with the starting exchange rate, the second after some time has passed
        // );
        assertApproxEqRel( // There will be a slight arithmetic imprecision, so assertEq makes the test fail
            prevLendingTokenBalance - postLendingTokenBalance,
            (DOC_TO_SPEND * 1e18 / startingExchangeRate) + (DOC_TO_SPEND * 1e18 / exchangeRate), // First batch purchase in makeBatchPurchasesOneUser is done with the starting exchange rate, the second after some time has passed
            0.1e16 // Allow a maximum difference of 0.1%
        );
        // assertEq(
        //     lendingTokenToken.balanceOf(address(docHandler)),
        //     DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - (DOC_TO_SPEND * 1e18 / startingExchangeRate)
        //         - (DOC_TO_SPEND * 1e18 / lendingTokenToken.exchangeRateCurrent())
        // );

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            // assertEq(
            //     lendingToken.balanceOf(address(docHandler)),
            //     DOC_TO_DEPOSIT * 1e18 / startingExchangeRate
            //         - (DOC_TO_SPEND * 1e18 / startingExchangeRate) - (DOC_TO_SPEND * 1e18 / exchangeRate)
            // );
            assertApproxEqRel(
                lendingToken.balanceOf(address(docHandler)),
                DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - (DOC_TO_SPEND * 1e18 / startingExchangeRate)
                    - (DOC_TO_SPEND * 1e18 / exchangeRate),
                0.1e16 // Allow a maximum difference of 0.1%
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                lendingToken.balanceOf(address(docHandler)),
                DOC_TO_DEPOSIT * 1e18 / startingExchangeRate - (DOC_TO_SPEND * 1e18 / startingExchangeRate)
                    - (DOC_TO_SPEND * 1e18 / exchangeRate),
                0.5e16 // Allow a maximum difference of 0.5%
            );
        }
    }

    function testWithdrawInterest() external {
        vm.warp(block.timestamp + 10 days); // Jump to 10 days in the future (for example) so that some interest has been generated.

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            updateTropykusExchangeRate();
        }

        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceBeforeInterestWithdrawal = docToken.balanceOf(USER);
        assertGt(withdrawableInterest, 0);
        vm.prank(USER);
        dcaManager.withdrawInterestFromTokenHandler(address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceAfterInterestWithdrawal = docToken.balanceOf(USER);
        console.log("userDocBalanceAfterInterestWithdrawal:", userDocBalanceAfterInterestWithdrawal);
        // assertEq(userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal, withdrawableInterest);
        assertApproxEqRel(
            userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal,
            withdrawableInterest,
            1 // Allow a maximum difference of 1e-18%
        );
        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        if (withdrawableInterest == 1) withdrawableInterest--;
        assertEq(withdrawableInterest, 0);
        // assertApproxEqRel(
        //     withdrawableInterest, // Allow a difference of 1 wei due to precision loss
        //     0,
        //     1 // Allow a maximum difference of 1e-18%
        // );
    }

    function testIfNoYieldWithdrawInterestFails() external {
        vm.warp(block.timestamp + 10 days); // Jump to 10 days into the future (for example) so that some interest has been generated.t has been generated.

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            updateTropykusExchangeRate();
        }

        uint256 withdrawableInterestBeforeWithdrawal =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceBeforeInterestWithdrawal = docToken.balanceOf(USER);
        assertGt(withdrawableInterestBeforeWithdrawal, 0);
        bytes memory encodedRevert =
            abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, address(docToken));
        vm.expectRevert(encodedRevert);
        vm.prank(USER);
        dcaManager.withdrawInterestFromTokenHandler(address(docToken), 0);
        uint256 userDocBalanceAfterInterestWithdrawal = docToken.balanceOf(USER);
        assertEq(userDocBalanceAfterInterestWithdrawal, userDocBalanceBeforeInterestWithdrawal);
        uint256 withdrawableInterestAfterWithdrawal =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        assertEq(withdrawableInterestBeforeWithdrawal, withdrawableInterestAfterWithdrawal);
    }

    function testWithdrawTokenAndInterest() external {
        vm.warp(block.timestamp + 10 days); // Jump to 10 days in the future (for example) so that some interest has been generated.

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != 31337 && s_lendingProtocolIndex == TROPYKUS_INDEX) {
            updateTropykusExchangeRate();
        }

        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        uint256 userDocBalanceBeforeInterestWithdrawal = docToken.balanceOf(USER);
        assertGt(withdrawableInterest, 0);
        vm.prank(USER);
        dcaManager.withdrawTokenAndInterest(address(docToken), 0, DOC_TO_SPEND, s_lendingProtocolIndex); // withdraw, for example, the amount of one periodic purchase
        uint256 userDocBalanceAfterInterestWithdrawal = docToken.balanceOf(USER);
        // assertEq(
        //     userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal,
        //     withdrawableInterest + DOC_TO_SPEND
        // );
        assertApproxEqRel(
            userDocBalanceAfterInterestWithdrawal - userDocBalanceBeforeInterestWithdrawal,
            withdrawableInterest + DOC_TO_SPEND,
            1 // Allow a maximum difference of 1e-18%
        );
        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(docToken), s_lendingProtocolIndex);
        assertEq(withdrawableInterest, 0);
    }
}
