// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockMocProxy {
    uint256 constant BTC_PRICE = 40_000;

    event DocRedeemed(address indexed user, uint256 docAmount, uint256 btcAmount);

    function redeemDocRequest(uint256 docAmount) external {}

    function redeemFreeDoc(uint256 docAmount) external {
        uint256 redeemedRbtc = docAmount / BTC_PRICE;
        (bool success,) = msg.sender.call{value: redeemedRbtc}("");
        if (success) {
            emit DocRedeemed(msg.sender, docAmount, redeemedRbtc);
        }
    }
}
