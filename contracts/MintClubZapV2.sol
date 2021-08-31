// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./lib/IUniswapV2Router02.sol";
import "./lib/IUniswapV2Factory.sol";
import "./lib/IMintClubBond.sol";
import "./lib/IWETH.sol";

/**
* @title MintClubZapV2 extension contract (2.1.0)
*/

contract MintClubZapV2 is Context {
    using SafeERC20 for IERC20;

    // Pancakeswap Router
    IUniswapV2Factory private constant PANCAKE_FACTORY = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IUniswapV2Router02 private constant PANCAKE_ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMintClubBond private constant BOND = IMintClubBond(0x8BBac0C7583Cc146244a18863E708bFFbbF19975);

    // Unix timestamp after which the transaction will revert.
    uint256 private constant DEAD_LINE = 0xf000000000000000000000000000000000000000000000000000000000000000;
    address private constant MINT_CONTRACT = address(0x1f3Af095CDa17d63cad238358837321e95FC5915);
    address private constant WBNB_CONTRACT = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    constructor() {
        // Approve infinite MINT tokens spendable by bond contract
        // MINT will be stored temporarily during the swap transaction
        _approveToken(MINT_CONTRACT, address(BOND));
    }

    function getAmountOut(address from, address to, uint256 amount) external view returns (uint256 tokenToReceive, uint256 mintTokenTaxAmount) {
        uint256 mintAmount;

        if (from == MINT_CONTRACT) {
            mintAmount = amount;
        } else {
            address[] memory path = _getPath(from);

            mintAmount = PANCAKE_ROUTER.getAmountsOut(amount, path)[path.length - 1];
        }

        return BOND.getMintReward(to, mintAmount);
    }

    function zapInBNB(address to, uint256 minAmountOut, address beneficiary) public payable {
        // First, wrap BNB to WBNB
        IWETH(WBNB_CONTRACT).deposit{value: msg.value}();

        // Swap WBNB to MINT
        uint256 mintAmount = _swap(WBNB_CONTRACT, MINT_CONTRACT, msg.value);

        // Finally, buy target tokens with swapped MINT
        _buyMintClubTokenAndSend(to, mintAmount, minAmountOut, beneficiary);
    }

    function zapIn(address from, address to, uint256 amount, uint256 minAmountOut, address beneficiary) public {
        // First, pull tokens to this contract
        IERC20 token = IERC20(from);
        require(token.allowance(_msgSender(), address(this)) >= amount, 'NOT_ENOUGH_ALLOWANCE');
        IERC20(from).safeTransferFrom(_msgSender(), address(this), amount);

        // Swap to MINT if necessary
        uint256 mintAmount;
        if (from == MINT_CONTRACT) {
            mintAmount = amount;
        } else {
            mintAmount = _swap(from, MINT_CONTRACT, amount);
        }

        // Finally, buy target tokens with swapped MINT
        _buyMintClubTokenAndSend(to, mintAmount, minAmountOut, beneficiary);
    }

    function createAndZapIn(string memory name, string memory symbol, uint256 maxTokenSupply, address token, uint256 tokenAmount, uint256 minAmountOut, address beneficiary) external {
        address newToken = BOND.createToken(name, symbol, maxTokenSupply);

        // We need `minAmountOut` here token->MINT can be front ran and slippage my happen
        zapIn(token, newToken, tokenAmount, minAmountOut, beneficiary);
    }

    function createAndZapInBNB(string memory name, string memory symbol, uint256 maxTokenSupply, uint256 minAmountOut, address beneficiary) external payable {
        address newToken = BOND.createToken(name, symbol, maxTokenSupply);

        zapInBNB(newToken, minAmountOut, beneficiary);
    }

    function _buyMintClubTokenAndSend(address tokenAddress, uint256 mintAmount, uint256 minAmountOut, address beneficiary) internal {
        // Finally, buy target tokens with swapped MINT
        BOND.buy(tokenAddress, mintAmount, minAmountOut, beneficiary);

        // BOND.buy doesn't return any value, so we need to calculate the purchased amount
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(_msgSender(), token.balanceOf(address(this))), 'BALANCE_TRANSFER_FAILED');
    }

    function _getPath(address from) internal pure returns (address[] memory path) {
        if (from == WBNB_CONTRACT) {
            path = new address[](2);
            path[0] = WBNB_CONTRACT;
            path[1] = MINT_CONTRACT;
        } else {
            path = new address[](3);
            path[0] = from;
            path[1] = WBNB_CONTRACT;
            path[2] = MINT_CONTRACT;
        }
    }

    function _approveToken(address tokenAddress, address spender) internal {
        IERC20 token = IERC20(tokenAddress);
        if (token.allowance(address(this), spender) > 0) {
            return;
        } else {
            token.safeApprove(spender, type(uint256).max);
        }
    }

    /**
        @notice This function is used to swap ERC20 <> ERC20
        @param from The token address to swap from.
        @param to The token address to swap to.
        @param amount The amount of tokens to swap
        @return boughtAmount The quantity of tokens bought
    */
    function _swap(address from, address to, uint256 amount) internal returns (uint256 boughtAmount) {
        if (from == to) {
            return amount;
        }

        _approveToken(from, address(PANCAKE_ROUTER));

        address[] memory path = _getPath(from);

        // path.length is always 2 or 3
        for (uint8 i = 0; i < path.length - 1; i++) {
            address pair = PANCAKE_FACTORY.getPair(path[i], path[i + 1]);
            require(pair != address(0), 'INVALID_SWAP_PATH');
        }

        boughtAmount = PANCAKE_ROUTER.swapExactTokensForTokens(
            amount,
            1, // amountOutMin
            path,
            address(this), // to: Recipient of the output tokens
            DEAD_LINE
        )[path.length - 1];

        require(boughtAmount > 0, 'SWAP_ERROR');
    }
}
