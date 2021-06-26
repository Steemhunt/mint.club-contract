// DEPLOYED contract: 0x1f3Af095CDa17d63cad238358837321e95FC5915

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "../lib/ERC20Initializable.sol";

contract MintToken is ERC20Initializable { // Deployed as MintClubToken
    bool private _initialized; // false by default
    address private _owner; // Ownable is implemented manually to meke it compatible with `initializable`

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function init(string memory name_, string memory symbol_) external {
        require(_initialized == false, "CONTRACT_ALREADY_INITIALIZED");

        _name = name_;
        _symbol = symbol_;
        _owner = _msgSender();

        _initialized = true;

        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}