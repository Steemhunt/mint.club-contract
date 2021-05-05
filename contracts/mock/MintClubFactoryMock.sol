// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../MintClubFactory.sol";

contract MintClubFactoryMock is MintClubFactory {
    constructor(address implementation) MintClubFactory(implementation) {}

    // function createToken(string memory name, string memory symbol, uint256 maxTokenSupply) external returns (address) {
    //     return _createToken(name, symbol, maxTokenSupply);
    // }
}
