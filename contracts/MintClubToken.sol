// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/ERC20Initializable.sol";

contract MintClubToken is ERC20Initializable {
    address private _owner;
    bool public initialized; // false by default

    constructor() ERC20Initializable() {
        _owner = _msgSender();
    }

    function init(string memory name_, string memory symbol_) external {
        require(initialized == false, "Contract already initialized");

        _name = name_;
        _symbol = symbol_;

        initialized = true;
    }

    function mint(address to, uint256 amount) public {
        require(_owner == _msgSender(), 'Permission denied');
        _mint(to, amount);
    }
}