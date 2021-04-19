// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MintClubToken.sol";

contract MintClubFactory {
    event TokenCreated(address tokenAddress);

    function createToken(string memory name, string memory symbol) public {
        MintClubToken token = new MintClubToken(name, symbol);

        // TODO: initialPrice, totalSupply, bondingCurve

        emit TokenCreated(address(token));
    }
}