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
*  Providing liquidity for MintClub tokens with a bonding curve
*/
contract MintClubBond is Context, MintClubFactory, BancorFormula {
    /**
     *  @dev
     *  Bonding Curve with Reserve Weight (aka: Connector Weight, Reserve Ratio)
     *      - ReserveWeight = ReserveTokenBalance / MarketCap
     *      - MarketCap = Price * TokenSupply
     *      - Price = ReserveBalance / (TokenSupply * ReserveWeight)
     *
     *      > PurchaseReturn = TokenSupply * ((1 + ReserveTokensReceived / ReserveTokenBalance) ^ (ReserveRatio) - 1)
     *      > SaleReturn = ReserveTokenBalance * (1 - (1 - ContinuousTokensReceived / TokenSupply) ^ (1 / (ReserveRatio)))
     *  References:
     *      - https://yos.io/2018/11/10/bonding-curves/
     *      - https://blog.relevant.community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
     *      - https://medium.com/thoughtchains/on-single-bonding-curves-for-continuous-token-models-a167f5ffef89
     *      - https://billyrennekamp.medium.com/converting-between-bancor-and-bonding-curve-price-formulas-9c11309062f5
     *      - https://storage.googleapis.com/website-bancor/2018/04/01ba8253-bancor_protocol_whitepaper_en.pdf
     *      - https://medium.com/simondlr/tokens-2-0-curved-token-bonding-in-curation-markets-1764a2e0bee5
     *      - https://blog.bancor.network/how-liquid-tokens-work-a4ba30f2482b
     *  Code References:
     *      - https://github.com/bancorprotocol
     *      - https://github.com/yosriady/continuous-token
     *          > https://github.com/superarius/token-bonding-curves
     */
    uint32 private constant RESERVE_WEIGHT = 3333333; // represented in ppm (ReserveWeight / 1e6)

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    IERC20 BASE_TOKEN;

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        BASE_TOKEN = IERC20(baseToken);
    }

    // function tokenSupply(address tokenAddress) public view returns (uint256) {
    //     return MintClubToken(tokenAddress).totalSupply();
    // }

    // Price = ReserveBalance / (TokenSupply * ReserveWeight)
    function currentPrice(address tokenAddress) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        if (reserveBalance[tokenAddress] == 0) {
            return 0;
        }

        return reserveBalance[tokenAddress] / (MintClubToken(tokenAddress).totalSupply() * (RESERVE_WEIGHT / MAX_WEIGHT));
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

        return saleTargetAmount(
            MintClubToken(tokenAddress).totalSupply(),
            reserveBalance[tokenAddress],
            RESERVE_WEIGHT,
            tokenAmount
        );
    }

    function buy(address tokenAddress, uint256 reserveTokenAmount, uint256 minReward) public {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        uint256 rewardAmount = getMintReward(tokenAddress, reserveTokenAmount);
        require(rewardAmount >= minReward, 'SLIPPAGE_LIMIT_EXCEEDED');

        // Transfer reserve tokens
        require(reserveToken.transferFrom(_msgSender(), address(this), reserveTokenAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
        // Mint reward tokens to the buyer
        MintClubToken(tokenAddress).mint(_msgSender(), rewardAmount);
    }

    function sell(address tokenAddress, uint256 tokenAmount, uint256 minRefund) public  {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        uint256 refundAmount = getBurnRefund(tokenAddress, tokenAmount);
        require(refundAmount >= minRefund, 'SLIPPAGE_LIMIT_EXCEEDED');

        // Burn token first
        MintClubToken(tokenAddress).burnFrom(_msgSender(), tokenAmount);
        // Refund reserve tokens to the seller
        require(reserveToken.transfer(_msgSender(), refundAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
    }
}
