// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IV3SwapRouter
 * @dev Interface para o router de swap do Uniswap V3
 */
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;
    function refundETH() external payable;
}