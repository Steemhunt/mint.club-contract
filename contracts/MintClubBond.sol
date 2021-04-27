// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./MintClubFactory.sol";
import "./MintClubToken.sol";
import "./lib/BancorFormula.sol";

/**
* @title MintClub Bond
*
* Providing liquidity for MintClub tokens with a bonding curve.
*  Bonding Curve with Reserve Weight (aka: Connector Weight, Reserve Ratio)
*      - ReserveWeight = ReserveTokenBalance / MarketCap
*      - MarketCap = Price * TokenSupply
*      - Price = ReserveBalance / (TokenSupply * ReserveWeight)
*
*      > PurchaseReturn = TokenSupply * ((1 + ReserveTokensReceived / ReserveTokenBalance) ^ (ReserveRatio) - 1)
*      > SaleReturn = ReserveTokenBalance * (1 - (1 - TokensReceived / TokenSupply) ^ (1 / (ReserveRatio)))
*      > ReserveTokenRequired = ReserveTokenBalance * (((TokenSupply + TokenToPurchase) / TokenSupply) ^ (MAX_WEIGHT / ReserveWeight) - 1)
*
*  References:
*      - https://yos.io/2018/11/10/bonding-curves/
*      - https://blog.relevant.community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
*      - https://medium.com/thoughtchains/on-single-bonding-curves-for-continuous-token-models-a167f5ffef89
*      - https://billyrennekamp.medium.com/converting-between-bancor-and-bonding-curve-price-formulas-9c11309062f5
*      - https://storage.googleapis.com/website-bancor/2018/04/01ba8253-bancor_protocol_whitepaper_en.pdf
*      - https://medium.com/simondlr/tokens-2-0-curved-token-bonding-in-curation-markets-1764a2e0bee5
*      - https://blog.bancor.network/how-liquid-tokens-work-a4ba30f2482b
*
*  Code References:
*      - https://github.com/bancorprotocol
*      - https://github.com/yosriady/continuous-token
*          > https://github.com/superarius/token-bonding-curves
*/
contract MintClubBond is Context, MintClubFactory, BancorFormula {
    /**
     * @dev Reserve Weight, represented in ppm, 1-1000000
     * - 1/3 corresponds to y= multiple * x^2
     * - 1/2 corresponds to y= multiple * x
     * - 2/3 corresponds to y= multiple * x^1/2
     *
     * > ReserveWeight = 1 / (n + 1) where n is the exponent
     * > Slope (multiple) = ReserveTokenBalance / (ReserveWeight * TokenSupply ^ (1 / ReserveWeight))
     */
    uint32 private constant RESERVE_WEIGHT = 333333;

    uint256 internal constant INITIAL_SUPPLY = 1e18; // 1 token to creator by default
    // TODO: Set proper reserve
    uint256 private constant INITIAL_RESERVE = 1e18 / 1000; // Slope = 3 * RB = 0.003 (= Bitclout)

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    IERC20 private RESERVE_TOKEN;

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        RESERVE_TOKEN = IERC20(baseToken);
    }

    function createToken(string memory name, string memory symbol, uint256 maxTokenSupply) external {
        require(maxTokenSupply > INITIAL_SUPPLY, 'INVALID_MAX_TOKEN_SUPPLY');

        address tokenAddress = _createToken(name, symbol, maxTokenSupply);

        // TODO: Is it okay to add a fake reserve balance at the beginning?
        // Probably okay because it is not sellable anyway
        reserveBalance[tokenAddress] = INITIAL_RESERVE;

        // Mint initial supply to the creator
        MintClubToken(tokenAddress).mint(_msgSender(), INITIAL_SUPPLY);
    }

    // MARK: - Utility functions for external calls

    function tokenSupply(address tokenAddress) external view returns (uint256) {
        return MintClubToken(tokenAddress).totalSupply();
    }

    function reserveTokenAddress() external view returns (address) {
        return address(RESERVE_TOKEN);
    }

    // MARK: - Core bonding curve functions

    // Price = ReserveBalance / (TokenSupply * ReserveWeight)
    function currentPrice(address tokenAddress) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        return 1e18 * reserveBalance[tokenAddress] / (MintClubToken(tokenAddress).totalSupply() * RESERVE_WEIGHT / MAX_WEIGHT);
    }

    function getMintReward(address tokenAddress, uint256 reserveTokenAmount) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        return purchaseTargetAmount(
            MintClubToken(tokenAddress).totalSupply(),
            reserveBalance[tokenAddress],
            RESERVE_WEIGHT,
            reserveTokenAmount
        );
    }

    function getBurnRefund(address tokenAddress, uint256 tokenAmount) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        uint256 totalSupply = MintClubToken(tokenAddress).totalSupply();
        require(tokenAmount <= totalSupply - INITIAL_SUPPLY, 'INVALID_TOKEN_AOUNT');

        return saleTargetAmount(
            totalSupply,
            reserveBalance[tokenAddress],
            RESERVE_WEIGHT,
            tokenAmount
        );
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
