// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockDocToken} from "../mocks/MockDocToken.sol";

contract MockMocProxy {
    uint256 constant BTC_PRICE = 50_000;
    MockDocToken mockDocToken;
    
    event DocRedeemed(address indexed user, uint256 docAmount, uint256 btcAmount);
    constructor(address docTokenAddress) {
        mockDocToken = MockDocToken(docTokenAddress);
    }
    

    function redeemDocRequest(uint256 docAmount) external {}

    function redeemFreeDoc(uint256 docAmount) external {
        uint256 redeemedRbtc = docAmount / BTC_PRICE;
        mockDocToken.transferFrom(msg.sender, address(this), docAmount);
        (bool success,) = msg.sender.call{value: redeemedRbtc}("");
        if (success) {
            emit DocRedeemed(msg.sender, docAmount, redeemedRbtc);
        }
    }
}
