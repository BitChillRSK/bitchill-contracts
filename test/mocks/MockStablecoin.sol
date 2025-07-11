// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MockStablecoin is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    constructor(address initialOwner) ERC20("Stablecoin", "STC") Ownable() ERC20Permit("Stablecoin") {}

    function mint(address to, uint256 amount) public /*onlyOwner*/ {
        _mint(to, amount);
    }
}
