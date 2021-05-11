// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

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
    // Bonding Curve: Price = 0.02 * TokenSupply (Linear)
    uint256 private constant SLOPE = 2; // 0.02 = SLOPE * 1e18;
    uint256 private constant MAX_SLOPE = 1e20; // SLOPE = 0.02/1e18

    uint256 private constant BUY_TAX = 3; // 0.3%
    uint256 private constant SELL_TAX = 13; // 1.3%
    uint256 private constant MAX_TAX = 1000;

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    MintClubToken private RESERVE_TOKEN; // IERC20 + burnable

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        RESERVE_TOKEN = MintClubToken(baseToken);
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
        require(exists(tokenAddress), "TOKEN_NOT_FOUND");
        _;
    }

    function currentPrice(address tokenAddress) public view _checkBondExists(tokenAddress) returns (uint256) {
        return SLOPE * MintClubToken(tokenAddress).totalSupply() * 1e18 / MAX_SLOPE;
    }

    function getMintReward(address tokenAddress, uint256 reserveTokenAmount) public view _checkBondExists(tokenAddress) returns (uint256, uint256) {
        uint256 taxAmount = reserveTokenAmount * BUY_TAX / MAX_TAX;
        uint256 toMint = Math.floorSqrt(2 * MAX_SLOPE * ((reserveTokenAmount - taxAmount) + reserveBalance[tokenAddress]) / SLOPE);

        require(MintClubToken(tokenAddress).totalSupply() + toMint <= maxSupply[tokenAddress], "EXCEEDED_MAX_SUPPLY");

        return (toMint, taxAmount);
    }

    function getBurnRefund(address tokenAddress, uint256 tokenAmount) public view _checkBondExists(tokenAddress) returns (uint256, uint256) {
        uint256 newTokenSupply = MintClubToken(tokenAddress).totalSupply() - tokenAmount;

        // Should be the same as: (SLOPE / (2 * MAX_SLOPE)) * (totalSupply**2 - newTokenSupply**2);
        uint256 refundAmount = reserveBalance[tokenAddress] - (newTokenSupply**2 * SLOPE / (2 * MAX_SLOPE));
        uint256 taxAmount = refundAmount * SELL_TAX / MAX_TAX;

        return (refundAmount - taxAmount, taxAmount);
    }

    function buy(address tokenAddress, uint256 reserveTokenAmount, uint256 minReward, address referral) public {
        (uint256 rewardTokens, uint256 taxAmount) = getMintReward(tokenAddress, reserveTokenAmount);
        require(rewardTokens >= minReward, "SLIPPAGE_LIMIT_EXCEEDED");

        // Transfer reserve tokens
        require(RESERVE_TOKEN.transferFrom(_msgSender(), address(this), reserveTokenAmount - taxAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
        reserveBalance[tokenAddress] += reserveTokenAmount - taxAmount;

        // Mint reward tokens to the buyer
        MintClubToken(tokenAddress).mint(_msgSender(), rewardTokens);

        // Pay tax to the referral / Burn if referral is not set
        if (referral == address(0)) {
            RESERVE_TOKEN.burnFrom(_msgSender(), taxAmount);
        } else {
            RESERVE_TOKEN.transferFrom(_msgSender(), referral, taxAmount);
        }
    }

    function sell(address tokenAddress, uint256 tokenAmount, uint256 minRefund, address referral) public {
        (uint256 refundAmount, uint256 taxAmount) = getBurnRefund(tokenAddress, tokenAmount);
        require(refundAmount >= minRefund, "SLIPPAGE_LIMIT_EXCEEDED");

        // Burn token first
        MintClubToken(tokenAddress).burnFrom(_msgSender(), tokenAmount);

        // Refund reserve tokens to the seller
        reserveBalance[tokenAddress] -= refundAmount;
        require(RESERVE_TOKEN.transfer(_msgSender(), refundAmount), "RESERVE_TOKEN_TRANSFER_FAILED");

        // Pay tax to the referral / Burn if referral is not set
        if (referral == address(0)) {
            RESERVE_TOKEN.burn(taxAmount);
        } else {
            RESERVE_TOKEN.transfer(referral, taxAmount);
        }
    }
}
