// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../src/Constants.sol";
import {MockWrbtcToken} from "./MockWrbtcToken.sol";

// Minimal mock interface for Uniswap V3 SwapRouter
interface IV3SwapRouter {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

// Mock implementation of SwapRouter02 (V3 Router)
contract MockSwapRouter02 is IV3SwapRouter {
    MockWrbtcToken s_mockWrbtcToken;
    uint256 private s_outputTokenPrice;

    constructor(MockWrbtcToken mockWrbtcToken, uint256 _outputTokenPrice) {
        s_mockWrbtcToken = mockWrbtcToken;
        s_outputTokenPrice = _outputTokenPrice;
    }

    // Mock function to simulate exactInput swap
    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        require(params.amountIn > 0, "AmountIn must be greater than zero");

        amountOut = (params.amountIn * 997) / (1000 * s_outputTokenPrice);

        require(params.amountOutMinimum <= amountOut, "Insufficient output amount");

        // To simulate the DocHandlerDex contract receiving WRBTC when exactInput is called, we deposit rBTC in the WRBTC contract here
        // msg.sender is the DocHandlerDex contract
        s_mockWrbtcToken.deposit{value: amountOut}(msg.sender);

        return amountOut;
    }

    // Allow changing the price of the output token for testing purposes
    function setFixedAmountOut(uint256 _newPrice) external {
        s_outputTokenPrice = _newPrice;
    }
}
