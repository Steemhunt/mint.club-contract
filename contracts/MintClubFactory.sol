// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./MintClubToken.sol";

contract MintClubFactory {
    // Array of all created tokens
    address[] public tokens;

    struct Parameters {
        uint256 initialPrice;
        uint256 maxSupply;
        uint8 connectorWeight; // 0 - 100 (REF: https://bit.ly/3uWdX4S)
    }
    // Token => Parameters
    mapping (address => Parameters) public parameters;

    event TokenCreated(address tokenAddress);

    function createToken(string memory name, string memory symbol, uint256 initialPrice, uint256 maxSupply, uint8 connectorWeight) public {
        MintClubToken token = new MintClubToken(name, symbol);

        address tokenAddress = address(token);
        tokens.push(tokenAddress);
        parameters[tokenAddress].initialPrice = initialPrice;
        parameters[tokenAddress].maxSupply = maxSupply;
        parameters[tokenAddress].connectorWeight = connectorWeight;

        // TODO: initialPrice, maxSupply, bondingCurve

        emit TokenCreated(tokenAddress);
    }

    function tokenCount() public view returns (uint256) {
        return tokens.length;
    }
}
