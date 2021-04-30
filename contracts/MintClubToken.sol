// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./lib/ERC20Initializable.sol";

contract MintClubToken is ERC20Initializable {
    address private _owner;
    bool private _initialized; // false by default

    function init(string memory name_, string memory symbol_) external {
        require(_initialized == false, 'CONTRACT_ALREADY_INITIALIZED');

        _name = name_;
        _symbol = symbol_;
        _owner = _msgSender();

        _initialized = true;
    }

    function mint(address to, uint256 amount) public {
        require(_owner == _msgSender(), 'PERMISSION_DENIED');
        _mint(to, amount);
    }

    function owner() external view returns (address) {
        return _owner;
    }
}