// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/Test.sol";
import {BitChillMini} from "../../src/chainlink-workshop/BitChillMini.sol";
import "../../script/Constants.sol";

/**
 * @title DeployBitChillMini
 * @author BitChill team: Antonio Rodríguez-Ynyesto
 * @notice Deployment script for BitChillMini contract on RSK testnet
 * @dev This script deploys the simplified BitChill contract for educational purposes
 */
contract DeployBitChillMini is Script {
    
    // RSK Testnet addresses
    address constant DOC_TOKEN_ADDRESS = 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0; // DOC token on testnet
    address constant K_DOC_ADDRESS = 0x71e6B108d823C2786f8EF63A3E0589576B4F3914; // kDOC proxy on testnet
    address constant MOC_PROXY_ADDRESS = 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F; // MOC proxy on testnet
    address constant FEE_COLLECTOR_ADDRESS = 0x226E865Ab298e542c5e5098694eFaFfe111F93D3; // Fee collector on testnet
    
    event DeployBitChillMini__ContractDeployed(address indexed contractAddress, address indexed owner);
    event DeployBitChillMini__DeploymentCompleted(address indexed contractAddress, uint256 chainId);

    function run() external returns (BitChillMini) {
        console.log("==== DeployBitChillMini.run() called ====");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        
        // Validate we're on RSK testnet
        if (block.chainid != RSK_TESTNET_CHAIN_ID) {
            console.log("WARNING: This script is designed for RSK testnet (chain ID 31)");
            console.log("Current chain ID:", block.chainid);
            console.log("Continuing deployment anyway...");
        }
        
        // Log deployment parameters
        console.log("Deployment parameters:");
        console.log("  DOC Token:", DOC_TOKEN_ADDRESS);
        console.log("  kDOC Token:", K_DOC_ADDRESS);
        console.log("  MoC Proxy:", MOC_PROXY_ADDRESS);
        console.log("  Fee Collector:", FEE_COLLECTOR_ADDRESS);
        
        vm.startBroadcast();
        
        // Deploy BitChillMini contract
        BitChillMini bitChillMini = new BitChillMini(
            DOC_TOKEN_ADDRESS,
            K_DOC_ADDRESS,
            MOC_PROXY_ADDRESS,
            FEE_COLLECTOR_ADDRESS
        );
        
        // Transfer ownership to deployer
        bitChillMini.transferOwnership(msg.sender);
        
        vm.stopBroadcast();
        
        // Log deployment results
        console.log("==== Deployment Completed ====");
        console.log("BitChillMini deployed at:", address(bitChillMini));
        console.log("Owner:", bitChillMini.owner());
        console.log("DOC Token:", address(bitChillMini.i_docToken()));
        console.log("kDOC Token:", address(bitChillMini.i_kDocToken()));
        console.log("MoC Proxy:", address(bitChillMini.i_mocProxy()));
        console.log("Fee Collector:", bitChillMini.i_feeCollector());
        console.log("Fee Rate:", bitChillMini.FEE_RATE_BPS(), "bps (1%)");
        
        emit DeployBitChillMini__ContractDeployed(address(bitChillMini), bitChillMini.owner());
        emit DeployBitChillMini__DeploymentCompleted(address(bitChillMini), block.chainid);
        
        return bitChillMini;
    }
    
    /**
     * @notice Verify the deployment by checking contract state
     * @param contractAddress Address of the deployed contract
     */
    function verifyDeployment(address contractAddress) external view {
        BitChillMini bitChillMini = BitChillMini(payable(contractAddress));
        
        console.log("==== Deployment Verification ====");
        console.log("Contract Address:", contractAddress);
        console.log("Owner:", bitChillMini.owner());
        console.log("DOC Token:", address(bitChillMini.i_docToken()));
        console.log("kDOC Token:", address(bitChillMini.i_kDocToken()));
        console.log("MoC Proxy:", address(bitChillMini.i_mocProxy()));
        console.log("Fee Collector:", bitChillMini.i_feeCollector());
        console.log("Fee Rate:", bitChillMini.FEE_RATE_BPS(), "bps");
        
        // Verify addresses match expected values
        require(address(bitChillMini.i_docToken()) == DOC_TOKEN_ADDRESS, "DOC token address mismatch");
        require(address(bitChillMini.i_kDocToken()) == K_DOC_ADDRESS, "kDOC token address mismatch");
        require(address(bitChillMini.i_mocProxy()) == MOC_PROXY_ADDRESS, "MoC proxy address mismatch");
        require(bitChillMini.i_feeCollector() == FEE_COLLECTOR_ADDRESS, "Fee collector address mismatch");
        require(bitChillMini.FEE_RATE_BPS() == 100, "Fee rate should be 100 bps (1%)");
        
        console.log("All verifications passed!");
    }
    
    /**
     * @notice Get deployment summary for documentation
     * @return summary Deployment summary string
     */
    function getDeploymentSummary() external pure returns (string memory summary) {
        return string(abi.encodePacked(
            "BitChillMini Deployment Summary:\n",
            "- Network: RSK Testnet (Chain ID 31)\n",
            "- DOC Token: 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0\n",
            "- kDOC Token: 0x71e6B108d823C2786f8EF63A3E0589576B4F3914\n",
            "- MoC Proxy: 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F\n",
            "- Fee Collector: 0x226E865Ab298e542c5e5098694eFaFfe111F93D3\n",
            "- Fee Rate: 1% (100 bps)\n",
            "- Features: DOC deposit, Tropykus lending, MoC rBTC redemption"
        ));
    }
}
