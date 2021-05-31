// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "../MintClubFactory.sol";

// Mock for testing abstract contract
contract MintClubFactoryMock is MintClubFactory {
    constructor(address implementation) MintClubFactory(implementation) {}
}