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
    uint256 internal s_maxFeeRate = MAX_FEE_RATE;
    uint256 internal s_minAnnualAmount = MIN_ANNUAL_AMOUNT;
    uint256 internal s_maxAnnualAmount = MAX_ANNUAL_AMOUNT;

    function calculateFee(uint256 purchaseAmount) external view returns (uint256) {

        if (s_minFeeRate == s_maxFeeRate) {
            return purchaseAmount * s_minFeeRate / FEE_PERCENTAGE_DIVISOR;
        }

        uint256 feeRate;

        if (purchaseAmount >= s_maxAnnualAmount) {
            feeRate = s_minFeeRate;
        } else if (purchaseAmount <= s_minAnnualAmount) {
            feeRate = s_maxFeeRate;
        } else {
            // Calculate the linear fee rate
            feeRate = s_maxFeeRate
                - ((purchaseAmount - s_minAnnualAmount) * (s_maxFeeRate - s_minFeeRate))
                    / (s_maxAnnualAmount - s_minAnnualAmount);
        }
        return purchaseAmount * feeRate / FEE_PERCENTAGE_DIVISOR;
    }
}
