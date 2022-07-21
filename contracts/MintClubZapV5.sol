// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./lib/IUniswapV2Router02.sol";
import "./lib/IUniswapV2Factory.sol";
import "./lib/IMintClubBond.sol";
import "./lib/IWETH.sol";
import "./lib/Math.sol";

/**
* @title MintClubZapV5 extension contract (5.0.0)
*/

contract MintClubZapV5 is Context {
    using SafeERC20 for IERC20;

    // Copied from MintClubBond
    uint256 private constant BUY_TAX = 3;
    uint256 private constant SELL_TAX = 13;
    uint256 private constant MAX_TAX = 1000;

    address private constant DEFAULT_BENEFICIARY = 0x82CA6d313BffE56E9096b16633dfD414148D66b1;

    // MARK: - Mainnet configs

    IUniswapV2Factory private constant PANCAKE_FACTORY = IUniswapV2Factory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IUniswapV2Router02 private constant PANCAKE_ROUTER = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IMintClubBond private constant BOND = IMintClubBond(0x8BBac0C7583Cc146244a18863E708bFFbbF19975);
    uint256 private constant DEAD_LINE = 0xf000000000000000000000000000000000000000000000000000000000000000;
    address private constant MINT_CONTRACT = address(0x1f3Af095CDa17d63cad238358837321e95FC5915);
    address private constant WBNB_CONTRACT = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);

    // MARK: - Testnet configs

    // IUniswapV2Factory private constant PANCAKE_FACTORY = IUniswapV2Factory(0x6725F303b657a9451d8BA641348b6761A6CC7a17);
    // IUniswapV2Router02 private constant PANCAKE_ROUTER = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
    // IMintClubBond private constant BOND = IMintClubBond(0xB9B492B5D470ae0eB2BB07a87062EC97615d8b09);
    // uint256 private constant DEAD_LINE = 0xf000000000000000000000000000000000000000000000000000000000000000;
    // address private constant MINT_CONTRACT = address(0x4d24BF63E5d6E03708e2DFd5cc8253B3f22FE913);
    // address private constant WBNB_CONTRACT = address(0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd);

    constructor() {
        // Approve infinite MINT tokens spendable by bond contract
        // MINT will be stored temporarily during the swap transaction
        _approveToken(MINT_CONTRACT, address(BOND));
    }

    receive() external payable {}

    // MINT and others (parameter) -> Mint Club Tokens
    function estimateZapIn(address from, address to, uint256 fromAmount) external view returns (uint256 tokensToReceive, uint256 mintTokenTaxAmount) {
        uint256 mintAmount;

        if (from == MINT_CONTRACT) {
            mintAmount = fromAmount;
        } else {
            address[] memory path = _getPathToMint(from);

            mintAmount = PANCAKE_ROUTER.getAmountsOut(fromAmount, path)[path.length - 1];
        }

        return BOND.getMintReward(to, mintAmount);
    }

    // Estimate the bonding curve minting amount when the token does not exist yet (initialization stage)
    function estimateZapInInitial(address from, uint256 fromAmount) external view returns (uint256 tokensToReceive, uint256 mintTokenTaxAmount) {
        uint256 mintAmount;

        if (from == MINT_CONTRACT) {
            mintAmount = fromAmount;
        } else {
            address[] memory path = _getPathToMint(from);

            mintAmount = PANCAKE_ROUTER.getAmountsOut(fromAmount, path)[path.length - 1];
        }

        uint256 taxAmount = mintAmount * BUY_TAX / MAX_TAX;
        uint256 newSupply = Math.floorSqrt(2 * 1e18 * (mintAmount - taxAmount));

        return (newSupply, taxAmount);
    }

    // Get required MINT token amount to buy X amount of Mint Club tokens
    function getReserveAmountToBuy(address tokenAddress, uint256 tokensToBuy) public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);

        uint256 newTokenSupply = token.totalSupply() + tokensToBuy;
        uint256 reserveRequired = (newTokenSupply ** 2 - token.totalSupply() ** 2) / (2 * 1e18);
        reserveRequired = reserveRequired * MAX_TAX / (MAX_TAX - BUY_TAX); // Deduct tax amount

        return reserveRequired;
    }

    // MINT and others -> Mint Club Tokens (parameter)
    function estimateZapInReverse(address from, address to, uint256 tokensToReceive) external view returns (uint256 fromAmountRequired, uint256 mintTokenTaxAmount) {
        uint256 reserveRequired = getReserveAmountToBuy(to, tokensToReceive);

        if (from == MINT_CONTRACT) {
            fromAmountRequired = reserveRequired;
        } else {
            address[] memory path = _getPathToMint(from);

            fromAmountRequired = PANCAKE_ROUTER.getAmountsIn(reserveRequired, path)[0];
        }

        mintTokenTaxAmount = reserveRequired * BUY_TAX / MAX_TAX;
    }

    // Estimate the bonding curve minting amount when the token does not exist yet (initialization stage)
    function estimateZapInReverseInitial(address from, uint256 tokensToReceive) external view returns (uint256 fromAmountRequired, uint256 mintTokenTaxAmount) {
        uint256 reserveRequired = tokensToReceive ** 2 / 2e18;

        if (from == MINT_CONTRACT) {
            fromAmountRequired = reserveRequired;
        } else {
            address[] memory path = _getPathToMint(from);

            fromAmountRequired = PANCAKE_ROUTER.getAmountsIn(reserveRequired, path)[0];
        }

        mintTokenTaxAmount = reserveRequired * BUY_TAX / MAX_TAX;
    }

    // Mint Club Tokens (parameter) -> MINT and others
    function estimateZapOut(address from, address to, uint256 fromAmount) external view returns (uint256 toAmountToReceive, uint256 mintTokenTaxAmount) {
        uint256 mintToRefund;
        (mintToRefund, mintTokenTaxAmount) = BOND.getBurnRefund(from, fromAmount);

        if (to == MINT_CONTRACT) {
            toAmountToReceive = mintToRefund;
        } else {
            address[] memory path = _getPathFromMint(to);

            toAmountToReceive = PANCAKE_ROUTER.getAmountsOut(mintToRefund, path)[path.length - 1];
        }
    }

    // Get amount of Mint Club tokens to receive X amount of MINT tokens
    function getTokenAmountFor(address tokenAddress, uint256 mintTokenAmount) public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);

        uint256 reserveAfterSell = BOND.reserveBalance(tokenAddress) - mintTokenAmount;
        uint256 supplyAfterSell = Math.floorSqrt(2 * 1e18 * reserveAfterSell);

        return token.totalSupply() - supplyAfterSell;
    }

    // Mint Club Tokens -> MINT and others (parameter)
    function estimateZapOutReverse(address from, address to, uint256 toAmount) external view returns (uint256 tokensRequired, uint256 mintTokenTaxAmount) {
        uint256 mintTokenAmount;
        if (to == MINT_CONTRACT) {
            mintTokenAmount = toAmount;
        } else {
            address[] memory path = _getPathFromMint(to);
            mintTokenAmount = PANCAKE_ROUTER.getAmountsIn(toAmount, path)[0];
        }

        mintTokenTaxAmount = mintTokenAmount * SELL_TAX / MAX_TAX;
        tokensRequired = getTokenAmountFor(from, mintTokenAmount + mintTokenTaxAmount);
    }

    function zapInBNB(address to, uint256 minAmountOut, address beneficiary) public payable {
        // First, wrap BNB to WBNB
        IWETH(WBNB_CONTRACT).deposit{value: msg.value}();

        // Swap WBNB to MINT
        uint256 mintAmount = _swap(WBNB_CONTRACT, MINT_CONTRACT, msg.value);

        // Finally, buy target tokens with swapped MINT
        _buyMintClubTokenAndSend(to, mintAmount, minAmountOut, _getBeneficiary(beneficiary));
    }

    function zapIn(address from, address to, uint256 amountIn, uint256 minAmountOut, address beneficiary) public {
        // First, pull tokens to this contract
        IERC20 token = IERC20(from);
        require(token.allowance(_msgSender(), address(this)) >= amountIn, 'NOT_ENOUGH_ALLOWANCE');
        IERC20(from).safeTransferFrom(_msgSender(), address(this), amountIn);

        // Swap to MINT if necessary
        uint256 mintAmount;
        if (from == MINT_CONTRACT) {
            mintAmount = amountIn;
        } else {
            mintAmount = _swap(from, MINT_CONTRACT, amountIn);
        }

        // Finally, buy target tokens with swapped MINT
        _buyMintClubTokenAndSend(to, mintAmount, minAmountOut, _getBeneficiary(beneficiary));
    }

    function createAndZapIn(string memory name, string memory symbol, uint256 maxTokenSupply, address token, uint256 tokenAmount, uint256 minAmountOut, address beneficiary) external {
        address newToken = BOND.createToken(name, symbol, maxTokenSupply);

        // We need `minAmountOut` here token->MINT can be front ran and slippage my happen
        zapIn(token, newToken, tokenAmount, minAmountOut, _getBeneficiary(beneficiary));
    }

    function createAndZapInBNB(string memory name, string memory symbol, uint256 maxTokenSupply, uint256 minAmountOut, address beneficiary) external payable {
        address newToken = BOND.createToken(name, symbol, maxTokenSupply);

        zapInBNB(newToken, minAmountOut, _getBeneficiary(beneficiary));
    }

    function zapOut(address from, address to, uint256 amountIn, uint256 minAmountOut, address beneficiary) external {
        uint256 mintAmount = _receiveAndSwapToMint(from, amountIn, _getBeneficiary(beneficiary));

        // Swap to MINT if necessary
        IERC20 toToken;
        uint256 amountOut;
        if (to == MINT_CONTRACT) {
            toToken = IERC20(MINT_CONTRACT);
            amountOut = mintAmount;
        } else {
            toToken = IERC20(to);
            amountOut = _swap(MINT_CONTRACT, to, mintAmount);
        }

        // Check slippage limit
        require(amountOut >= minAmountOut, 'ZAP_SLIPPAGE_LIMIT_EXCEEDED');

        // Send the token to the user
        require(toToken.transfer(_msgSender(), amountOut), 'BALANCE_TRANSFER_FAILED');
    }

    function zapOutBNB(address from, uint256 amountIn, uint256 minAmountOut, address beneficiary) external {
        uint256 mintAmount = _receiveAndSwapToMint(from, amountIn, _getBeneficiary(beneficiary));

        // Swap to MINT to BNB
        uint256 amountOut = _swap(MINT_CONTRACT, WBNB_CONTRACT, mintAmount);
        IWETH(WBNB_CONTRACT).withdraw(amountOut);

        // Check slippage limit
        require(amountOut >= minAmountOut, 'ZAP_SLIPPAGE_LIMIT_EXCEEDED');

        // TODO: FIXME!!!!!

        // Send BNB to user
        (bool sent, ) = _msgSender().call{value: amountOut}("");
        require(sent, "BNB_TRANSFER_FAILED");
    }

    function _buyMintClubTokenAndSend(address tokenAddress, uint256 mintAmount, uint256 minAmountOut, address beneficiary) internal {
        // Finally, buy target tokens with swapped MINT (can be reverted due to slippage limit)
        BOND.buy(tokenAddress, mintAmount, minAmountOut, _getBeneficiary(beneficiary));

        // BOND.buy doesn't return any value, so we need to calculate the purchased amount
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(_msgSender(), token.balanceOf(address(this))), 'BALANCE_TRANSFER_FAILED');
    }

    function _receiveAndSwapToMint(address from, uint256 amountIn, address beneficiary) internal returns (uint256) {
        // First, pull tokens to this contract
        IERC20 token = IERC20(from);
        require(token.allowance(_msgSender(), address(this)) >= amountIn, 'NOT_ENOUGH_ALLOWANCE');
        IERC20(from).safeTransferFrom(_msgSender(), address(this), amountIn);

        // Approve infinitely to this contract
        if (token.allowance(address(this), address(BOND)) < amountIn) {
            require(token.approve(address(BOND), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff), 'APPROVE_FAILED');
        }

        // Sell tokens to MINT
        // NOTE: ignore minRefund (set as 0) for now, we should check it later on zapOut
        BOND.sell(from, amountIn, 0, _getBeneficiary(beneficiary));
        IERC20 mintToken = IERC20(MINT_CONTRACT);

        return mintToken.balanceOf(address(this));
    }


    function _getPathToMint(address from) internal pure returns (address[] memory path) {
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

    function _getPathFromMint(address to) internal pure returns (address[] memory path) {
        if (to == WBNB_CONTRACT) {
            path = new address[](2);
            path[0] = MINT_CONTRACT;
            path[1] = WBNB_CONTRACT;
        } else {
            path = new address[](3);
            path[0] = MINT_CONTRACT;
            path[1] = WBNB_CONTRACT;
            path[2] = to;
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

        address[] memory path;

        if (to == MINT_CONTRACT) {
            path = _getPathToMint(from);
        } else if (from == MINT_CONTRACT) {
            path = _getPathFromMint(to);
        } else {
            revert('INVALID_PATH');
        }

        // Check if there's a liquidity pool for paths
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

    // Prevent self referral
    function _getBeneficiary(address beneficiary) internal view returns (address) {
        if (beneficiary == address(0) || beneficiary == _msgSender()) {
           return DEFAULT_BENEFICIARY;
        } else {
            return beneficiary;
        }
    }
}
