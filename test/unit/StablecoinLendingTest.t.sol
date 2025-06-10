//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DcaDappTest} from "./DcaDappTest.t.sol";
import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {TropykusDocHandlerMoc} from "../../src/TropykusDocHandlerMoc.sol";
import {SovrynDocHandlerMoc} from "../../src/SovrynDocHandlerMoc.sol";
import {ILendingToken} from "../interfaces/ILendingToken.sol";
import {IkToken} from "../../src/interfaces/IkToken.sol";
import {MocHelperConfig} from "../../script/MocHelperConfig.s.sol";
import "../../script/Constants.sol";

contract StablecoinLendingTest is DcaDappTest {
    uint256 constant KDOC_STARTING_EXCHANGE_RATE = 2e16;

    function setUp() public override {
        super.setUp();
    }

    /////////////////////////////////////
    ///// Stablecoin Lending tests /////
    /////////////////////////////////////
    function testDepositedStablecoinIsLent() external {
        // Check initial balances
        uint256 ltStablecoinBalanceBeforeDeposit = stablecoin.balanceOf(address(lendingToken));
        
        super.depositDoc();
        
        // Check if stablecoin has been transferred from the handler to the lending token
        uint256 ltStablecoinBalanceAfterDeposit = stablecoin.balanceOf(address(lendingToken));
        
        // Check that the stablecoin handler has 0 balance (all stablecoin was sent to lending token)
        assertEq(stablecoin.balanceOf(address(docHandler)), 0, "Stablecoin balance in handler should be 0");
        
        // Check that the correct amount was added to the lending token
        assertEq(ltStablecoinBalanceAfterDeposit - ltStablecoinBalanceBeforeDeposit, AMOUNT_TO_DEPOSIT, "Incorrect amount deposited in lending token");
    }

    function testStablecoinDepositIncreasesLendingTokenBalance() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.depositDoc();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        uint256 exchangeRate = s_lendingProtocolIndex == TROPYKUS_INDEX 
            ? lendingToken.exchangeRateCurrent() 
            : lendingToken.tokenPrice();

        // Check that the actual lending token (the one used by the stablecoin handler) has the correct balance
        assertApproxEqRel(
            lendingToken.balanceOf(address(docHandler)),
            2 * AMOUNT_TO_DEPOSIT * 1e18 / exchangeRate,
            1 // Allow a maximum difference of 1e-18%
        );

        assertEq(postLendingTokenBalance - prevLendingTokenBalance, AMOUNT_TO_DEPOSIT * 1e18 / exchangeRate);
    }

    function testStablecoinWithdrawalBurnsLendingToken() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.withdrawDoc();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();
        
        assertApproxEqAbs(
            lendingToken.balanceOf(address(docHandler)),
            0,
            100 // Allow a maximum difference of 100e-18%
        );
        assertApproxEqAbs(
            prevLendingTokenBalance - postLendingTokenBalance,
            AMOUNT_TO_DEPOSIT * 1e18 / exchangeRate,
            100 // Allow a maximum difference of 100e-18%
        );
    }

    function testRbtcPurchaseBurnsLendingToken() external {
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        super.makeSinglePurchase();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);
        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != ANVIL_CHAIN_ID) {
            startingExchangeRate = s_lendingProtocolIndex == TROPYKUS_INDEX
                ? lendingToken.exchangeRateCurrent()
                : lendingToken.tokenPrice();
            updateExchangeRate(1);
        }
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();

        assertApproxEqRel(
            lendingToken.balanceOf(address(docHandler)),
            (AMOUNT_TO_DEPOSIT * 1e18 / startingExchangeRate - AMOUNT_TO_SPEND * 1e18 / exchangeRate),
            0.3e16 // Allow a maximum difference of 0.3%
        );

        assertApproxEqRel(
            prevLendingTokenBalance - postLendingTokenBalance,
            AMOUNT_TO_SPEND * 1e18 / exchangeRate,
            0.3e16 // Allow a maximum difference of 0.3%
        );
    }

    function testSeveralRbtcPurchasesBurnLendingToken() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules();
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;
        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != ANVIL_CHAIN_ID) {
            startingExchangeRate = s_lendingProtocolIndex == TROPYKUS_INDEX
                ? lendingToken.exchangeRateCurrent()
                : lendingToken.tokenPrice();
        }

        super.makeSeveralPurchasesWithSeveralSchedules();
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        if (block.chainid != ANVIL_CHAIN_ID) updateExchangeRate(1);
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();

        // @notice In this test we don't use assertEq because calculating the exact number on the right hand side would be too much hassle
        // However, we check that the lending tokens spent to redeem stablecoin to make the rBTC purchases is lower than the amount we would have
        // needed if the exchange rate were constant and greater than the amount necessary if all the redemptions had been made at the latest exchange rate (since as time passes fewer tokens are necessary to redeem each stablecoin)
        assertLe(
            prevLendingTokenBalance - postLendingTokenBalance,
            NUM_OF_SCHEDULES * AMOUNT_TO_SPEND * 1e18 / startingExchangeRate
        );
        assertGe(
            prevLendingTokenBalance - postLendingTokenBalance, NUM_OF_SCHEDULES * AMOUNT_TO_SPEND * 1e18 / exchangeRate
        );

        // @notice Similarly, here we check that the remaining lending token balance of the stablecoin Token Handler contract is lower
        // than it would have been if the redemptions had been made at the highest exchange rate but greater than
        // if the redemptions had been made at the starting exchange rate
        assertLe(
            lendingToken.balanceOf(address(docHandler)),
            AMOUNT_TO_DEPOSIT * 1e18 / startingExchangeRate - NUM_OF_SCHEDULES * AMOUNT_TO_SPEND * 1e18 / exchangeRate
        );
        assertGe(
            lendingToken.balanceOf(address(docHandler)),
            AMOUNT_TO_DEPOSIT * 1e18 / startingExchangeRate - NUM_OF_SCHEDULES * AMOUNT_TO_SPEND * 1e18 / startingExchangeRate
        );
    }

    function testRbtcBatchPurchaseBurnsLendingToken() external {
        // This just for one user, for many users this will get tested in invariant tests
        super.createSeveralDcaSchedules(); // This creates NUM_OF_SCHEDULES schedules with purchaseAmount = AMOUNT_TO_SPEND / NUM_OF_SCHEDULES
        uint256 prevLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        uint256 startingExchangeRate = KDOC_STARTING_EXCHANGE_RATE;
        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        if (block.chainid != ANVIL_CHAIN_ID) {
            startingExchangeRate = s_lendingProtocolIndex == TROPYKUS_INDEX
                ? lendingToken.exchangeRateCurrent()
                : lendingToken.tokenPrice();
        }

        super.makeBatchPurchasesOneUser(); // Batched purchases add up to an amount of AMOUNT_TO_SPEND, this function makes two batch purchases
        uint256 postLendingTokenBalance = docHandler.getUsersLendingTokenBalance(USER);

        if (block.chainid != ANVIL_CHAIN_ID) updateExchangeRate(1);
        uint256 exchangeRate =
            s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();

        assertApproxEqRel( // There will be a slight arithmetic imprecision, so assertEq makes the test fail
            prevLendingTokenBalance - postLendingTokenBalance,
            (AMOUNT_TO_SPEND * 1e18 / startingExchangeRate) + (AMOUNT_TO_SPEND * 1e18 / exchangeRate), // First batch purchase in makeBatchPurchasesOneUser is done with the starting exchange rate, the second after some time has passed
            0.1e16 // Allow a maximum difference of 0.1%
        );

        if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("mocSwaps"))) {
            assertApproxEqRel(
                lendingToken.balanceOf(address(docHandler)),
                AMOUNT_TO_DEPOSIT * 1e18 / startingExchangeRate - (AMOUNT_TO_SPEND * 1e18 / startingExchangeRate)
                    - (AMOUNT_TO_SPEND * 1e18 / exchangeRate),
                0.1e16 // Allow a maximum difference of 0.1%
            );
        } else if (keccak256(abi.encodePacked(swapType)) == keccak256(abi.encodePacked("dexSwaps"))) {
            assertApproxEqRel( // The mock contract that simulates swapping on Uniswap allows for some slippage
                lendingToken.balanceOf(address(docHandler)),
                AMOUNT_TO_DEPOSIT * 1e18 / startingExchangeRate - (AMOUNT_TO_SPEND * 1e18 / startingExchangeRate)
                    - (AMOUNT_TO_SPEND * 1e18 / exchangeRate),
                MAX_SLIPPAGE_PERCENT // Allow a maximum difference of 0.5%
            );
        }
    }

    function testWithdrawInterest() external {
        vm.warp(block.timestamp + 10 days); // Jump to 10 days in the future (for example) so that some interest has been generated.

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        updateExchangeRate(10);

        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        uint256 userStablecoinBalanceBeforeInterestWithdrawal = stablecoin.balanceOf(USER);
        assertGt(withdrawableInterest, 0);
        vm.prank(USER);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = s_lendingProtocolIndex;
        dcaManager.withdrawAllAccumulatedInterest(address(stablecoin), lendingProtocolIndexes);
        uint256 userStablecoinBalanceAfterInterestWithdrawal = stablecoin.balanceOf(USER);
        console.log("userStablecoinBalanceAfterInterestWithdrawal:", userStablecoinBalanceAfterInterestWithdrawal);
        // assertEq(userStablecoinBalanceAfterInterestWithdrawal - userStablecoinBalanceBeforeInterestWithdrawal, withdrawableInterest);
        assertApproxEqRel(
            userStablecoinBalanceAfterInterestWithdrawal - userStablecoinBalanceBeforeInterestWithdrawal,
            withdrawableInterest,
            1 // Allow a maximum difference of 1e-18%
        );
        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        if (withdrawableInterest == 1) withdrawableInterest--;
        assertEq(withdrawableInterest, 0);
    }

    function testIfNoYieldWithdrawInterestFails() external {
        vm.warp(block.timestamp + 10 days); // Jump to 10 days into the future (for example) so that some interest has been generated.t has been generated.

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        updateExchangeRate(10);

        uint256 withdrawableInterestBeforeWithdrawal =
            dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        uint256 userStablecoinBalanceBeforeInterestWithdrawal = stablecoin.balanceOf(USER);
        assertGt(withdrawableInterestBeforeWithdrawal, 0);
        bytes memory encodedRevert =
            abi.encodeWithSelector(IDcaManager.DcaManager__TokenDoesNotYieldInterest.selector, address(stablecoin));
        vm.expectRevert(encodedRevert);
        vm.prank(USER);
        uint256[] memory lendingProtocolIndexes = new uint256[](1);
        lendingProtocolIndexes[0] = 0;
        dcaManager.withdrawAllAccumulatedInterest(address(stablecoin), lendingProtocolIndexes);
        uint256 userStablecoinBalanceAfterInterestWithdrawal = stablecoin.balanceOf(USER);
        assertEq(userStablecoinBalanceAfterInterestWithdrawal, userStablecoinBalanceBeforeInterestWithdrawal);
        uint256 withdrawableInterestAfterWithdrawal =
            dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        assertEq(withdrawableInterestBeforeWithdrawal, withdrawableInterestAfterWithdrawal);
    }

    function testWithdrawTokenAndInterest() external {
        vm.warp(block.timestamp + 10 days);

        // On fork tests we need to simulate some operation on Tropykus so that the exchange rate gets updated
        updateExchangeRate(10);

        uint256 withdrawableInterest =
            dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        uint256 userStablecoinBalanceBeforeInterestWithdrawal = stablecoin.balanceOf(USER);
        assertGt(withdrawableInterest, 0);

        vm.prank(USER);
        dcaManager.withdrawTokenAndInterest(address(stablecoin), 0, AMOUNT_TO_SPEND, s_lendingProtocolIndex);

        uint256 userStablecoinBalanceAfterInterestWithdrawal = stablecoin.balanceOf(USER);
        assertApproxEqRel(
            userStablecoinBalanceAfterInterestWithdrawal - userStablecoinBalanceBeforeInterestWithdrawal,
            withdrawableInterest + AMOUNT_TO_SPEND,
            1 // Allow a maximum difference of 1e-18%
        );

        withdrawableInterest = dcaManager.getInterestAccruedByUser(USER, address(stablecoin), s_lendingProtocolIndex);
        if (withdrawableInterest == 1) withdrawableInterest = 0; // Handle edge case of 1 wei remaining
        assertEq(withdrawableInterest, 0);
    }

    // @notice: This is difficult to test, because the withdrawal amount is adjusted to the balance
    // in the lending protocol, which only happenes in edge cases on mainnet or a live testnet
    // function testWithdrawalAmountAdjustedToBalance() external {
    //     // Add debug logging
    //     console.log("Initial user lending token balance:", docHandler.getUsersLendingTokenBalance(USER));

    //     uint256 exchangeRate =
    //         s_lendingProtocolIndex == TROPYKUS_INDEX ? lendingToken.exchangeRateCurrent() : lendingToken.tokenPrice();
    //     console.log("Exchange rate:", exchangeRate);

    //     uint256 stablecoinInLendingProtocol = docHandler.getUsersLendingTokenBalance(USER) * exchangeRate / 1e18;
    //     console.log("Stablecoin in lending protocol:", stablecoinInLendingProtocol);

    //     uint256 attemptedWithdrawalAmount = stablecoinInLendingProtocol + 1;
    //     console.log("Attempted withdrawal amount:", attemptedWithdrawalAmount);

    //     vm.expectEmit(true, true, true, true);
    //     emit TokenLending__WithdrawalAmountAdjusted(USER, attemptedWithdrawalAmount, stablecoinInLendingProtocol);

    //     vm.prank(USER);
    //     dcaManager.withdrawToken(address(stablecoin), 0, attemptedWithdrawalAmount);

    //     // Verify user received their full balance
    //     assertEq(stablecoin.balanceOf(USER), stablecoinInLendingProtocol);
    //     // Verify lending token balance is now 0
    //     assertEq(docHandler.getUsersLendingTokenBalance(USER), 0);
    // }
} 