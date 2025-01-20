// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IAdminOperations} from "./interfaces/IAdminOperations.sol";
import {ITokenHandler} from "./interfaces/ITokenHandler.sol";
import {IERC165} from "lib/forge-std/src/interfaces/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title AdminOperations
 * @dev Contract to manage administrative tasks and token handlers
 */
contract AdminOperations is IAdminOperations, Ownable, AccessControl /* , InterfaceChecker */ {
    using Address for address;
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant SWAPPER_ROLE = keccak256("SWAPPER");

    mapping(bytes32 tokenProtocolHash => address tokenHandlerContract) private s_tokenHandler;
    // mapping(address token => address swapper) private s_swapper;
    // mapping(address token => string[] protocols) private s_tokenProtocols; // Doesn't seem like we'll need this - TODO: check!
    mapping(string lowerCaseProtocolName => uint256 protocolIndex) private s_protocolIndexes;
    mapping(uint256 protocolIndex => string lowerCaseProtocolName) private s_protocolNames;
    // No lending -> 0
    // "tropykus" -> 1
    // "sovryn" -> 2

    constructor() Ownable() {
        // _grantRole(ADMIN_ROLE, msg.sender);
        // _grantRole(SWAPPER_ROLE, msg.sender);
    }

    /**
     * @dev Assigns a new TokenHandler to a token.
     * @param token The address of the token.
     * @param lendingProtocolIndex The index of the protocol where (if) the token is lent
     * @param handler The address of the TokenHandler.
     * @notice lendingProtocolIndex == 0 means the token is not lent
     */
    function assignOrUpdateTokenHandler(address token, uint256 lendingProtocolIndex, address handler)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (!address(handler).isContract()) revert AdminOperations__EoaCannotBeHandler(handler);
        if (lendingProtocolIndex != 0 && bytes(s_protocolNames[lendingProtocolIndex]).length == 0) {
            revert AdminOperations__LendingProtocolNotAllowed(lendingProtocolIndex);
        }

        IERC165 tokenHandler = IERC165(handler);

        if (tokenHandler.supportsInterface(type(ITokenHandler).interfaceId)) {
            bytes32 key = _encodeKey(token, lendingProtocolIndex);
            s_tokenHandler[key] = handler;
            emit AdminOperations__TokenHandlerUpdated(token, lendingProtocolIndex, handler);
        } else {
            revert AdminOperations__ContractIsNotTokenHandler(handler);
        }
    }

    /**
     * @dev Assigns a new address to the swapper role.
     * @param swapper The swapper address.
     */
    function setSwapperRole(address swapper) external onlyRole(ADMIN_ROLE) {
        _grantRole(SWAPPER_ROLE, swapper);
    }

    /**
     * @dev Assigns a new address to the admin role.
     * @param admin The admin address.
     */
    function setAdminRole(address admin) external onlyOwner {
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @dev Retrieves the handler for a given token.
     * @param token The address of the token.
     * @param lendingProtocolIndex The index of the lending protocol (empty string if token will not be lent)
     * @return The address of the TokenHandler. If address(0) is returned, the tuple token-protocol is not correct
     */
    function getTokenHandler(address token, uint256 lendingProtocolIndex) public view returns (address) {
        bytes32 key = _encodeKey(token, lendingProtocolIndex);
        return s_tokenHandler[key];
    }

    /**
     * @dev Adds a lending protocol to the system by assigning an index to its name
     * @param lowerCaseName The name of the lending protocol in lower case
     * @param index The index to be assigned to it
     * @notice The index cannot be zero, since all elements in a mapping map to 0 by default
     */
    function addOrUpdateLendingProtocol(string memory lowerCaseName, uint256 index) external onlyRole(ADMIN_ROLE) {
        if (index == 0) revert AdminOperations__LendingProtocolIndexCannotBeZero();
        if (bytes(lowerCaseName).length == 0) revert AdminOperations__LendingProtocolNameNotSet();
        s_protocolIndexes[lowerCaseName] = index;
        s_protocolNames[index] = lowerCaseName;
        emit AdminOperations__LendingProtocolAdded(index, lowerCaseName);
    }

    /**
     * @dev Retrieves the index of the lending protocol
     * @param lowerCaseName The name of the lending protocol in lower case
     * @return The index of the lending protocol
     */
    function getLendingProtocolIndex(string memory lowerCaseName) external view returns (uint256) {
        return s_protocolIndexes[lowerCaseName];
    }

    /**
     * @dev Retrieves the index of the lending protocol
     * @param index The index of the lending protocol in lower case
     * @return The name of the lending protocol
     */
    function getLendingProtocolName(uint256 index) external view returns (string memory) {
        return s_protocolNames[index];
    }

    /**
     * @param index The index of the lending protocol in lower case
     * @return Whether the token is lent in any lending protocol
     */
    // function tokenIsLent(uint256 index) external view returns (bool) {
    //     return bytes(s_protocolNames[index]).length != 0;
    // }

    /**
     * @dev Retrieves the swapper for a given token.
     * @param token The address of the token.
     * @return The swapper address for the given token. If address(0) is returned, the token has no assigned swapper.
     */
    // function getSwapper(address token) public view returns (address) {
    //     return s_swapper[token];
    // }

    /**
     * @dev Encodes the token and lending protocol
     * @param token The address of the token.
     * @param lendingProtocolIndex The name of the lending protocol (empty string if token will not be lent)
     */
    function _encodeKey(address token, uint256 lendingProtocolIndex) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(token, lendingProtocolIndex));
    }

    // function supportsFunction(address contractAddress, bytes4 functionSignature) public view returns (bool) {
    //     (bool success, bytes memory data) = contractAddress.staticcall(abi.encodeWithSelector(functionSignature));
    //     return success && data.length > 0;  // success será true si la función existe y no revierte
    // }
}
