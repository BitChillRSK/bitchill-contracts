// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IDcaManagerAccessControl} from "src/interfaces/IDcaManagerAccessControl.sol";

/**
 * @title DcaManagerAccessControl
 * @dev Base contract for handling DCA Manager access control
 */
abstract contract DcaManagerAccessControl is IDcaManagerAccessControl {
    //////////////////////
    // State variables ///
    //////////////////////
    address public immutable i_dcaManager; // The DCA manager contract

    //////////////////////
    // Modifiers /////////
    //////////////////////
    modifier onlyDcaManager() {
        if (msg.sender != i_dcaManager) revert DcaManagerAccessControl__OnlyDcaManagerCanCall();
        _;
    }

    constructor(address dcaManagerAddress) {
        i_dcaManager = dcaManagerAddress;
    }
}
