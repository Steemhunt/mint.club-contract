// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IMintClubBond {
    function getMintReward(
        address tokenAddress,
        uint256 reserveAmount
    ) external view returns (
        uint256 toMint,
        uint256 taxAmount
    );

    function buy(
        address tokenAddress,
        uint256 reserveAmount,
        uint256 minReward,
        address beneficiary
    ) external;

    function createToken(
        string memory name,
        string memory symbol,
        uint256 maxTokenSupply
    ) external returns (
        address tokenAddress
    );
}