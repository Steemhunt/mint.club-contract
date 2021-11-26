// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IMintClubBond {
    function reserveBalance(
        address tokenAddress
    ) external view returns (
        uint256 reserveBalance
    );

    function getMintReward(
        address tokenAddress,
        uint256 reserveAmount
    ) external view returns (
        uint256 toMint, // token amount to be minted
        uint256 taxAmount
    );

    function getBurnRefund(
        address tokenAddress,
        uint256 tokenAmount
    ) external view returns (
        uint256 mintToRefund,
        uint256 mintTokenTaxAmount
    );

    function buy(
        address tokenAddress,
        uint256 reserveAmount,
        uint256 minReward,
        address beneficiary
    ) external;

    function sell(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 minRefund,
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