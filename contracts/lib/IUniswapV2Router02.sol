// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external
        returns (
            uint256[] memory amounts
        );

    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) external view
        returns (
            uint[] memory amounts
        );

    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) external view
        returns (
            uint[] memory amounts
        );
}