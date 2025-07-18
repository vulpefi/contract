// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IUniswapV3 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactInputParamsRouter2 {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
    function exactInput(ExactInputParamsRouter2 calldata params) external payable returns (uint256 amountOut);
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;
}

interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}