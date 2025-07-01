//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IDcaManager} from "../../src/interfaces/IDcaManager.sol";
import "../Constants.sol";

contract DummyERC165Contract {
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == type(IDcaManager).interfaceId; // Check against an interface different from TokenHandler's
    }
}

contract FeeCalculator {
    uint256 internal s_minFeeRate = MIN_FEE_RATE;
    uint256 internal s_maxFeeRate = MAX_FEE_RATE_TEST; // Use test fee rate for testing
    uint256 internal s_feePurchaseLowerBound = FEE_PURCHASE_LOWER_BOUND;
    uint256 internal s_feePurchaseUpperBound = FEE_PURCHASE_UPPER_BOUND;

    function calculateFee(uint256 purchaseAmount) external view returns (uint256) {

        if (s_minFeeRate == s_maxFeeRate) {
            return purchaseAmount * s_minFeeRate / FEE_PERCENTAGE_DIVISOR;
        }

        uint256 feeRate;

        if (purchaseAmount >= s_feePurchaseLowerBound) {
            feeRate = s_minFeeRate;
        } else if (purchaseAmount <= s_feePurchaseLowerBound) {
            feeRate = s_maxFeeRate;
        } else {
            // Calculate the linear fee rate
            feeRate = s_maxFeeRate
                - ((purchaseAmount - s_feePurchaseLowerBound) * (s_maxFeeRate - s_minFeeRate))
                    / (s_feePurchaseUpperBound - s_feePurchaseLowerBound);
        }
        return purchaseAmount * feeRate / FEE_PERCENTAGE_DIVISOR;
    }
}
