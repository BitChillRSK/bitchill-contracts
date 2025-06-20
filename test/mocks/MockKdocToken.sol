// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IStablecoin} from "../../src/interfaces/IStablecoin.sol";
import {console} from "forge-std/Test.sol";

contract MockKdocToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    IStablecoin immutable i_docToken;
    uint256 constant DECIMALS = 1e18;
    uint256 constant STARTING_EXCHANGE_RATE = 2 * DECIMALS / 100; // Each DOC token deposited mints 50 kDOC tokens, each kDOC token redeems 0.02 DOC tokens
    uint256 immutable i_deploymentTimestamp;
    uint256 constant ANNUAL_INCREASE = 5; // The DOC tokens redeemed by each kDOC token increase by 5% annually (mocking behaviour)
    uint256 constant YEAR_IN_SECONDS = 31536000;

    constructor(address docTokenAddress) ERC20("Tropykus kDOC", "kDOC") Ownable() ERC20Permit("Tropykus kDOC") {
        i_docToken = IStablecoin(docTokenAddress);
        i_deploymentTimestamp = block.timestamp;
    }

    function mint(uint256 amount) public returns (uint256) {
        require(i_docToken.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");
        i_docToken.transferFrom(msg.sender, address(this), amount); // Deposit DOC into Tropykus
        _mint(msg.sender, amount * DECIMALS / exchangeRateCurrent()); //  Mint kDOC to user that deposited DOC (in our case, the DocHandler contract)
        return 0;
    }

    function redeemUnderlying(uint256 amount) public returns (uint256) {
        uint256 kDocToBurn = amount * DECIMALS / exchangeRateCurrent();
        require(balanceOf(msg.sender) >= kDocToBurn, "Insufficient balance");
        i_docToken.transfer(msg.sender, amount);
        _burn(msg.sender, kDocToBurn); // Burn an amount of kDOC equivalent to the amount of DOC divided by the exchange rate (e.g.: 1 DOC redeemed => 1 / 0.02 = 50 kDOC burnt)
        return 0;
    }

    function redeem(uint256 kDocToBurn) public returns (uint256) {
        uint256 docToRedeem = kDocToBurn * exchangeRateCurrent() / DECIMALS;
        require(balanceOf(msg.sender) >= kDocToBurn, "Insufficient balance");
        i_docToken.transfer(msg.sender, docToRedeem);
        _burn(msg.sender, kDocToBurn); // Burn an amount of kDOC equivalent to the amount of DOC divided by the exchange rate (e.g.: 1 DOC redeemed => 1 / 0.02 = 50 kDOC burnt)
        return 0;
    }

    /**
     * @dev Returns the stored exchange rate between DOC and kDOC.
     * The exchange rate increases linearly over time at 5% per year.
     */
    function exchangeRateStored() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - i_deploymentTimestamp; // Time elapsed since deployment in seconds
        uint256 yearsElapsed = (timeElapsed * DECIMALS) / YEAR_IN_SECONDS; // Convert timeElapsed to years with 18 decimals

        // Calculate the rate increase: STARTING_EXCHANGE_RATE * ANNUAL_INCREASE * yearsElapsed
        // Divide by 100 for the percentage and by DECIMALS (1e18) to adjust for the extra decimals on yearsElapsed
        uint256 exchangeRateIncrease = (STARTING_EXCHANGE_RATE * ANNUAL_INCREASE * yearsElapsed) / (100 * DECIMALS);

        return STARTING_EXCHANGE_RATE + exchangeRateIncrease; // Current exchange rate
    }

    /**
     * @dev Returns the current exchange rate between DOC and kDOC. (same mocking behaviour as exchangeRateStored())
     * The exchange rate increases linearly over time at 5% per year.
     */
    function exchangeRateCurrent() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - i_deploymentTimestamp; // Time elapsed since deployment in seconds
        uint256 yearsElapsed = (timeElapsed * DECIMALS) / YEAR_IN_SECONDS; // Convert timeElapsed to years with 18 decimals

        // Calculate the rate increase: STARTING_EXCHANGE_RATE * ANNUAL_INCREASE * yearsElapsed
        // Divide by 100 for the percentage and by DECIMALS (1e18) to adjust for the extra decimals on yearsElapsed
        uint256 exchangeRateIncrease = (STARTING_EXCHANGE_RATE * ANNUAL_INCREASE * yearsElapsed) / (100 * DECIMALS);

        return STARTING_EXCHANGE_RATE + exchangeRateIncrease; // Current exchange rate
    }

    function getSupplierSnapshotStored(address user) external view returns (uint256, uint256, uint256, uint256) {
        uint256 underlyingAmount = balanceOf(user) * exchangeRateCurrent() / DECIMALS;
        return (0, underlyingAmount, 0, 0);
    }
}
