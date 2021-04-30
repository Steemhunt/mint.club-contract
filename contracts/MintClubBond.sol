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
     * > ReserveWeight = 1 / (Exponent + 1) where n is the exponent
     * > Slope (multiple) = ReserveTokenBalance / (ReserveWeight * TokenSupply ^ (1 / ReserveWeight))
     */
    // uint32 private constant RESERVE_WEIGHT = 400000; // Exponent = 1.5
    // uint256 internal constant INITIAL_SUPPLY = 1e18; // 1 token to creator by default
    // uint256 private constant INITIAL_RESERVE = 1e10; // Slope = 0.000000025

    // => Price = 0.00002 * TokenSupply
    uint256 private constant SLOPE = 2; // 0.00002 = SLOPE * 1e18;
    uint256 private constant MAX_SLOPE = 1e23; // SLOPE = 0.00002/1e18

    // Token => Reserve Balance
    mapping (address => uint256) public reserveBalance;

    IERC20 private RESERVE_TOKEN;

    constructor(address baseToken, address implementation) MintClubFactory(implementation) {
        RESERVE_TOKEN = IERC20(baseToken);
    }

    function createToken(string memory name, string memory symbol, uint256 maxTokenSupply) external {
        // require(maxTokenSupply > INITIAL_SUPPLY, 'INVALID_MAX_TOKEN_SUPPLY');

        address tokenAddress = _createToken(name, symbol, maxTokenSupply);

        // Mint initial supply to the creator
        // MintClubToken(tokenAddress).mint(_msgSender(), INITIAL_SUPPLY);
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
    // function currentPrice(address tokenAddress) public view returns (uint256) {
    //     require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

    //     return 1e18 * reserveBalance[tokenAddress] / (MintClubToken(tokenAddress).totalSupply() * RESERVE_WEIGHT / MAX_WEIGHT);
    // }

    // Price = Slope * x ^ 2 (Slope = 3 * InitialReserve)
    // function currentPrice(address tokenAddress) public view returns (uint256) {
    //     require(exists(tokenAddress), 'TOKEN_NOT_FOUND');


    //     return (3 * INITIAL_RESERVE * (MintClubToken(tokenAddress).totalSupply() / 1e18) ** 2);
    // }

    function currentPrice(address tokenAddress) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');


        return SLOPE * MintClubToken(tokenAddress).totalSupply() * 1e18 / MAX_SLOPE;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function getMintReward(address tokenAddress, uint256 reserveTokenAmount) public view returns (uint256) {
        require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

        return sqrt(2 * MAX_SLOPE * (reserveTokenAmount + reserveBalance[tokenAddress]) / SLOPE);
    }

    // function getMintReward(address tokenAddress, uint256 reserveTokenAmount) public view returns (uint256) {
    //     require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

    //     return purchaseTargetAmount2(
    //         MintClubToken(tokenAddress).totalSupply(),
    //         reserveBalance[tokenAddress],
    //         RESERVE_WEIGHT,
    //         reserveTokenAmount
    //     );
    // }

    // function getBurnRefund(address tokenAddress, uint256 tokenAmount) public view returns (uint256) {
    //     require(exists(tokenAddress), 'TOKEN_NOT_FOUND');

    //     uint256 totalSupply = MintClubToken(tokenAddress).totalSupply();
    //     require(tokenAmount <= totalSupply, 'INVALID_TOKEN_AMOUNT');

    //     return saleTargetAmount(
    //         totalSupply,
    //         reserveBalance[tokenAddress],
    //         RESERVE_WEIGHT,
    //         tokenAmount
    //     );
    // }

    function buy(address tokenAddress, uint256 reserveTokenAmount, uint256 minReward) public {
        uint256 rewardAmount = getMintReward(tokenAddress, reserveTokenAmount);
        require(rewardAmount >= minReward, 'SLIPPAGE_LIMIT_EXCEEDED');

        // Transfer reserve tokens
        require(RESERVE_TOKEN.transferFrom(_msgSender(), address(this), reserveTokenAmount), 'RESERVE_TOKEN_TRANSFER_FAILED');
        reserveBalance[tokenAddress] += reserveTokenAmount;

        // Mint reward tokens to the buyer
        MintClubToken(tokenAddress).mint(_msgSender(), rewardAmount);
    }

    // function sell(address tokenAddress, uint256 tokenAmount, uint256 minRefund) public  {
    //     uint256 refundAmount = getBurnRefund(tokenAddress, tokenAmount);
    //     require(refundAmount >= minRefund, 'SLIPPAGE_LIMIT_EXCEEDED');

    //     // Burn token first
    //     MintClubToken(tokenAddress).burnFrom(_msgSender(), tokenAmount);

    //     // TODO: Sell Tax

    //     // Refund reserve tokens to the seller
    //     reserveBalance[tokenAddress] -= refundAmount;
    //     require(RESERVE_TOKEN.transfer(_msgSender(), refundAmount), "RESERVE_TOKEN_TRANSFER_FAILED");
    // }
}
