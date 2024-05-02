// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAdminOperations} from "./interfaces/IAdminOperations.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title AdminOperations
 * @dev Contract to manage administrative tasks and token handlers
 */
contract AdminOperations is IAdminOperations, Ownable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => address) private tokenHandlers; // Maps token addresses to their respective TokenHandler

    constructor() Ownable(msg.sender) {
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Assigns a new TokenHandler to a token.
     * @param token The address of the token.
     * @param handler The address of the TokenHandler.
     */
    function assignOrUpdateTokenHandler(address token, address handler) public /*onlyRole(ADMIN_ROLE)*/ onlyOwner {
        if (!isContract(handler)) revert AdminOperations__EoaCannotBeHandler(handler);
        tokenHandlers[token] = handler;
        emit AdminOperations__TokenHandlerUpdated(token, handler);
    }

    /**
     * @dev Retrieves the handler for a given token.
     * @param token The address of the token.
     * @return The address of the TokenHandler.
     */
    function getTokenHandler(address token) public view returns (address) {
        return tokenHandlers[token];
    }

    /**
     * @dev Checks if a given address has a smart contract
     * @param addr The address of the token.
     */
    function isContract(address addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }
}
