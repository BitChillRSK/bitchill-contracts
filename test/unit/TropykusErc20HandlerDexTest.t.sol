// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {HandlerTestHarness} from "./HandlerTestHarness.t.sol";
import {ITokenHandler} from "../../src/interfaces/ITokenHandler.sol";
import {IFeeHandler} from "../../src/interfaces/IFeeHandler.sol";
import {IPurchaseUniswap} from "../../src/interfaces/IPurchaseUniswap.sol";
import {IWRBTC} from "../../src/interfaces/IWRBTC.sol";
import {ISwapRouter02} from "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import {ICoinPairPrice} from "../../src/interfaces/ICoinPairPrice.sol";
import {TropykusErc20HandlerDex} from "../../src/TropykusErc20HandlerDex.sol";
import {MockKdocToken} from "../mocks/MockKdocToken.sol";
import {MockWrbtcToken} from "../mocks/MockWrbtcToken.sol";
import {MockMocOracle} from "../mocks/MockMocOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../script/Constants.sol";

/**
 * @title TropykusErc20HandlerDexTest 
 * @notice Unit tests for TropykusErc20HandlerDex (DEX variant) using shared test harness
 */
contract TropykusErc20HandlerDexTest is HandlerTestHarness {
    
    // Tropykus DEX-specific contracts
    MockKdocToken public kToken;
    MockWrbtcToken public wrbtcToken;
    MockMocOracle public mocOracle;
    TropykusErc20HandlerDex public tropykusDexHandler;
    
    /*//////////////////////////////////////////////////////////////
                           HANDLER-SPECIFIC IMPLEMENTATIONS
    //////////////////////////////////////////////////////////////*/
    
    function deployHandler() internal override returns (ITokenHandler) {
        IFeeHandler.FeeSettings memory feeSettings = IFeeHandler.FeeSettings({
            minFeeRate: MIN_FEE_RATE,
            maxFeeRate: MAX_FEE_RATE_TEST,
            feePurchaseLowerBound: FEE_PURCHASE_LOWER_BOUND,
            feePurchaseUpperBound: FEE_PURCHASE_UPPER_BOUND
        });
        
        address[] memory intermediateTokens = new address[](0); // No intermediate tokens for direct swap
        uint24[] memory poolFeeRates = new uint24[](1);
        poolFeeRates[0] = 3000; // 0.3% fee
        
        IPurchaseUniswap.UniswapSettings memory uniswapSettings = IPurchaseUniswap.UniswapSettings({
            wrBtcToken: IWRBTC(address(wrbtcToken)),
            swapRouter02: ISwapRouter02(address(0x777)), // Mock router address
            swapIntermediateTokens: intermediateTokens,
            swapPoolFeeRates: poolFeeRates,
            mocOracle: ICoinPairPrice(address(mocOracle))
        });
        
        tropykusDexHandler = new TropykusErc20HandlerDex(
            address(dcaManager),
            address(stablecoin),
            address(kToken),
            uniswapSettings,
            MIN_PURCHASE_AMOUNT,
            FEE_COLLECTOR,
            feeSettings,
            9970, // 99.7% minimum output
            9900  // 99% safety check
        );
        
        return ITokenHandler(address(tropykusDexHandler));
    }
    
    function getLendingProtocolIndex() internal pure override returns (uint256) {
        return TROPYKUS_INDEX;
    }
    
    function isDexHandler() internal pure override returns (bool) {
        return true; // This is the DEX variant
    }
    
    function isLendingHandler() internal pure override returns (bool) {
        return true; // Tropykus handlers support lending
    }
    
    function getLendingToken() internal view override returns (IERC20) {
        return IERC20(address(kToken));
    }
    
    function setupHandlerSpecifics() internal override {
        // Deploy mock tokens
        kToken = new MockKdocToken(address(stablecoin));
        wrbtcToken = new MockWrbtcToken();
        mocOracle = new MockMocOracle();
        
        // Note: MockKdocToken has built-in time-based exchange rate calculation
        
        // Note: Oracle price setup would need MockMocProxy price methods
        
        // Give tokens some initial balances
        stablecoin.mint(address(kToken), 1000000 ether);
        wrbtcToken.mint(address(0x777), 1000 ether); // Give router some WBTC
    }
    
    /*//////////////////////////////////////////////////////////////
                           TROPYKUS DEX-SPECIFIC TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_tropykusDex_deployment() public {
        // Verify DEX-specific configuration
        assertEq(tropykusDexHandler.getAmountOutMinimumPercent(), 9970); // 99.7%
        assertEq(tropykusDexHandler.getAmountOutMinimumSafetyCheck(), 9900); // 99%
        assertNotEq(address(tropykusDexHandler.getMocOracle()), address(0));
        assertGt(tropykusDexHandler.getSwapPath().length, 0);
    }
    
    function test_tropykusDex_setAmountOutMinimumPercent_success() public {
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumPercent(9950); // 99.5% in basis points (above safety check)
        
        assertEq(tropykusDexHandler.getAmountOutMinimumPercent(), 9950);
    }
    
    function test_tropykusDex_setAmountOutMinimumPercent_reverts_invalidRange() public {
        // Test upper bound (over 100% in ether scale)
        vm.expectRevert();
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumPercent(1.01 ether); // 101% in ether scale
        
        // Test lower bound (below safety check)
        uint256 safetyCheck = tropykusDexHandler.getAmountOutMinimumSafetyCheck();
        vm.expectRevert();
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumPercent(safetyCheck - 1);
    }
    
    function test_tropykusDex_setAmountOutMinimumPercent_reverts_notOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        tropykusDexHandler.setAmountOutMinimumPercent(9500);
    }
    
    function test_tropykusDex_setAmountOutMinimumSafetyCheck_success() public {
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumSafetyCheck(9000); // 90% in basis points
        
        assertEq(tropykusDexHandler.getAmountOutMinimumSafetyCheck(), 9000);
    }
    
    function test_tropykusDex_setAmountOutMinimumSafetyCheck_reverts_invalidRange() public {
        vm.expectRevert();
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumSafetyCheck(1.01 ether); // 101% in ether scale
    }
    
    function test_tropykusDex_setPurchasePath_success() public {
        address[] memory intermediateTokens = new address[](0); // Direct swap, no intermediates
        uint24[] memory poolFeeRates = new uint24[](1);
        poolFeeRates[0] = 3000; // 0.3%
        
        vm.prank(OWNER);
        tropykusDexHandler.setPurchasePath(intermediateTokens, poolFeeRates);
        
        bytes memory expectedPath = abi.encodePacked(
            address(stablecoin),
            uint24(3000),
            address(wrbtcToken)
        );
        assertEq(tropykusDexHandler.getSwapPath(), expectedPath);
    }
    
    function test_tropykusDex_setPurchasePath_reverts_invalidLength() public {
        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = address(0x123);
        uint24[] memory poolFeeRates = new uint24[](1); // Should be 2 for 1 intermediate token
        poolFeeRates[0] = 3000;
        
        vm.expectRevert();
        vm.prank(OWNER);
        tropykusDexHandler.setPurchasePath(intermediateTokens, poolFeeRates);
    }
    
    function test_tropykusDex_setPurchasePath_reverts_notOwner() public {
        address[] memory intermediateTokens = new address[](0);
        uint24[] memory poolFeeRates = new uint24[](1);
        poolFeeRates[0] = 3000;
        
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(USER);
        tropykusDexHandler.setPurchasePath(intermediateTokens, poolFeeRates);
    }
    
    /*//////////////////////////////////////////////////////////////
                           TROPYKUS DEX ORACLE TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_tropykusDex_oraclePrice() public {
        uint256 price = tropykusDexHandler.getMocOracle().getPrice();
        assertGt(price, 0); // Should be greater than 0 by default
    }
    
    function test_tropykusDex_oraclePriceValidation() public {
        // Set oracle to return 0 (should cause issues)
        mocOracle.setPrice(0);
        
        // This might cause issues in swap calculations
        // The exact behavior depends on implementation
        uint256 price = tropykusDexHandler.getMocOracle().getPrice();
        assertEq(price, 0);
    }
    
    /*//////////////////////////////////////////////////////////////
                           TROPYKUS DEX SWAP PATH TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_tropykusDex_swapPathValidation() public {
        bytes memory path = tropykusDexHandler.getSwapPath();
        assertGt(path.length, 0);
        
        // The path should include both input and output tokens
        // Exact validation depends on how the path is structured
        assertTrue(path.length >= 43); // Minimum for single-hop path (20 + 3 + 20 bytes)
    }
    
    /*//////////////////////////////////////////////////////////////
                           COMBINED FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/
    
    function test_tropykusDex_depositAndLendingCombined() public {
        // Test that DEX handler maintains lending functionality
        vm.prank(address(dcaManager));
        handler.depositToken(USER, DEPOSIT_AMOUNT);
        
        // Check lending balance (inherited from Tropykus base)
        uint256 lendingBalance = tropykusDexHandler.getUsersLendingTokenBalance(USER);
        assertGt(lendingBalance, 0);
        
        // Check kToken balance increased
        uint256 kTokenBalance = kToken.balanceOf(address(handler));
        assertGt(kTokenBalance, 0);
    }
    
    function test_tropykusDex_withdrawWithDexCapabilities() public {
        // Deposit first
        vm.prank(address(dcaManager));
        handler.depositToken(USER, DEPOSIT_AMOUNT);
        
        // Withdraw (should use Tropykus redemption, not DEX)
        uint256 userBalanceBefore = stablecoin.balanceOf(USER);
        
        vm.prank(address(dcaManager));
        handler.withdrawToken(USER, WITHDRAWAL_AMOUNT);
        
        uint256 userBalanceAfter = stablecoin.balanceOf(USER);
        assertGt(userBalanceAfter, userBalanceBefore);
    }
    
    /*//////////////////////////////////////////////////////////////
                           EDGE CASES FOR DEX VARIANT
    //////////////////////////////////////////////////////////////*/
    
    function test_tropykusDex_extremeSlippageSettings() public {
        // Test with extreme but valid slippage settings
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumSafetyCheck(5000); // Lower safety check first
        
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumPercent(5000); // 50% (very high slippage)
        
        assertEq(tropykusDexHandler.getAmountOutMinimumPercent(), 5000);
        
        vm.prank(OWNER);
        tropykusDexHandler.setAmountOutMinimumPercent(9999); // 99.99% (very low slippage)
        
        assertEq(tropykusDexHandler.getAmountOutMinimumPercent(), 9999);
    }
    
    function test_tropykusDex_oracleFailure() public {
        // Test behavior when oracle fails
        // This depends on how the handler deals with oracle failures
        mocOracle.setInvalidPrice();
        
        // Accessing price info should show invalid state
        (, bool isValid, ) = tropykusDexHandler.getMocOracle().getPriceInfo();
        assertFalse(isValid);
    }
    
    function test_tropykusDex_swapPathEdgeCases() public {
        // Test with multi-hop path
        address[] memory intermediateTokens = new address[](1);
        intermediateTokens[0] = address(0x123); // Intermediate token
        uint24[] memory poolFeeRates = new uint24[](2);
        poolFeeRates[0] = 3000;
        poolFeeRates[1] = 3000;
        
        vm.prank(OWNER);
        tropykusDexHandler.setPurchasePath(intermediateTokens, poolFeeRates);
        
        bytes memory expectedPath = abi.encodePacked(
            address(stablecoin),
            uint24(3000),
            address(0x123), // Intermediate token
            uint24(3000), 
            address(wrbtcToken)
        );
        assertEq(tropykusDexHandler.getSwapPath(), expectedPath);
        assertEq(tropykusDexHandler.getSwapPath().length, 66); // 3 addresses + 2 fees
    }
} 