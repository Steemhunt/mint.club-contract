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
    uint256 private constant BUY_TAX = 3; // 0.3%
    uint256 private constant SELL_TAX = 13; // 1.3%
    uint256 private constant MAX_TAX = 1000;

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    MintClubToken private RESERVE_TOKEN; // MINT: IERC20 + burnable

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        RESERVE_TOKEN = MintClubToken(baseToken);
    }

    // MARK: - Utility functions for external calls

    function reserveTokenAddress() external view returns (address) {
        return address(RESERVE_TOKEN);
    }

    // MARK: - Core bonding curve functions

    modifier _checkBondExists(address tokenAddress) {
        require(exists(tokenAddress), "TOKEN_NOT_FOUND");
        _;
    }

    /**
     * @dev Use the simplest bonding curve (y = x) as we can adjust total supply of reserve tokens to adjust slope
     * Price = SLOPE * totalSupply = totalSupply (where slope = 1)
     */
    function currentPrice(address tokenAddress) public view _checkBondExists(tokenAddress) returns (uint256) {
        return MintClubToken(tokenAddress).totalSupply();
    }

    function getMintReward(address tokenAddress, uint256 reserveAmount) public view _checkBondExists(tokenAddress) returns (uint256, uint256) {
        uint256 taxAmount = reserveAmount * BUY_TAX / MAX_TAX;
        uint256 toMint = Math.floorSqrt(2 * 1e18 * ((reserveAmount - taxAmount) + reserveBalance[tokenAddress]));

        require(MintClubToken(tokenAddress).totalSupply() + toMint <= maxSupply[tokenAddress], "EXCEEDED_MAX_SUPPLY");

        return (toMint, taxAmount);
    }

    function getBurnRefund(address tokenAddress, uint256 tokenAmount) public view _checkBondExists(tokenAddress) returns (uint256, uint256) {
        uint256 newTokenSupply = MintClubToken(tokenAddress).totalSupply() - tokenAmount;

        // Should be the same as: (SLOPE / (2 * MAX_SLOPE)) * (totalSupply**2 - newTokenSupply**2);
        uint256 reserveAmount = reserveBalance[tokenAddress] - (newTokenSupply**2 / (2 * 1e18));
        uint256 taxAmount = reserveAmount * SELL_TAX / MAX_TAX;

        return (reserveAmount - taxAmount, taxAmount);
    }

    function buy(address tokenAddress, uint256 reserveAmount, uint256 minReward, address referral) public {
        (uint256 rewardTokens, uint256 taxAmount) = getMintReward(tokenAddress, reserveAmount);
        require(rewardTokens >= minReward, "SLIPPAGE_LIMIT_EXCEEDED");

        // Transfer reserve tokens
        require(RESERVE_TOKEN.transferFrom(_msgSender(), address(this), reserveAmount - taxAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
        reserveBalance[tokenAddress] += (reserveAmount - taxAmount);

        // Mint reward tokens to the buyer
        MintClubToken(tokenAddress).mint(_msgSender(), rewardTokens);

        // Pay tax to the referral / Burn if referral is not set (or abused)
        if (referral == address(0) || referral == _msgSender()) {
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
        reserveBalance[tokenAddress] -= (refundAmount + taxAmount);
        require(RESERVE_TOKEN.transfer(_msgSender(), refundAmount), "RESERVE_TOKEN_TRANSFER_FAILED");

        // Pay tax to the referral / Burn if referral is not set (or abused)
        if (referral == address(0) || referral == _msgSender()) {
            RESERVE_TOKEN.burn(taxAmount);
        } else {
            RESERVE_TOKEN.transfer(referral, taxAmount);
        }
    }
}
