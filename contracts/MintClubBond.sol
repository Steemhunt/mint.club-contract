// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./MintClubFactory.sol";
import "./MintClubToken.sol";
import "./lib/Math.sol";

/**
* @title MintClub Bond
*
* Providing liquidity for MintClub tokens with a bonding curve.
*/
contract MintClubBond is Context, MintClubFactory {
    // Bonding Curve: Price = 0.00002 * TokenSupply (Linear)
    uint256 private constant SLOPE = 2; // 0.00002 = SLOPE * 1e18;
    uint256 private constant MAX_SLOPE = 1e23; // SLOPE = 0.00002/1e18

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    IERC20 private RESERVE_TOKEN;

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        RESERVE_TOKEN = IERC20(baseToken);
    }

    // MARK: - Utility functions for external calls

    function tokenSupply(address tokenAddress) external view returns (uint256) {
        return MintClubToken(tokenAddress).totalSupply();
    }

    function reserveTokenAddress() external view returns (address) {
        return address(RESERVE_TOKEN);
    }

    // MARK: - Core bonding curve functions

    modifier _checkBondExists(address tokenAddress) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');
        _;
    }

    function currentPrice(address tokenAddress) public view _checkBondExists(tokenAddress) returns (uint256) {
        return SLOPE * MintClubToken(tokenAddress).totalSupply() * 1e18 / MAX_SLOPE;
    }

    function getMintReward(address tokenAddress, uint256 reserveTokenAmount) public view _checkBondExists(tokenAddress) returns (uint256) {
        uint256 toMint = Math.floorSqrt(2 * MAX_SLOPE * (reserveTokenAmount + reserveBalance[tokenAddress]) / SLOPE);

        require(MintClubToken(tokenAddress).totalSupply() + toMint <= maxSupply[tokenAddress], 'MAX_SUPPLY_LIMIT_EXCEEDED');

        return toMint;
    }

    function getBurnRefund(address tokenAddress, uint256 tokenAmount) public view _checkBondExists(tokenAddress) returns (uint256) {
        uint256 newTokenSupply = MintClubToken(tokenAddress).totalSupply() - tokenAmount;

        // Should be the same as: (SLOPE / (2 * MAX_SLOPE)) * (totalSupply**2 - newTokenSupply**2);
        return reserveBalance[tokenAddress] - (newTokenSupply**2 * SLOPE / (2 * MAX_SLOPE));
    }

    function buy(address tokenAddress, uint256 reserveTokenAmount, uint256 minReward) public {
        uint256 rewardAmount = getMintReward(tokenAddress, reserveTokenAmount);
        require(rewardAmount >= minReward, 'SLIPPAGE_LIMIT_EXCEEDED');

        // Transfer reserve tokens
        require(RESERVE_TOKEN.transferFrom(_msgSender(), address(this), reserveTokenAmount), 'RESERVE_TOKEN_TRANSFER_FAILED');
        reserveBalance[tokenAddress] += reserveTokenAmount;

        // Mint reward tokens to the buyer
        MintClubToken(tokenAddress).mint(_msgSender(), rewardAmount);
    }

    function sell(address tokenAddress, uint256 tokenAmount, uint256 minRefund) public  {
        uint256 refundAmount = getBurnRefund(tokenAddress, tokenAmount);
        require(refundAmount >= minRefund, 'SLIPPAGE_LIMIT_EXCEEDED');

        // Burn token first
        MintClubToken(tokenAddress).burnFrom(_msgSender(), tokenAmount);

        // TODO: Sell Tax

        // Refund reserve tokens to the seller
        reserveBalance[tokenAddress] -= refundAmount;
        require(RESERVE_TOKEN.transfer(_msgSender(), refundAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
    }
}
