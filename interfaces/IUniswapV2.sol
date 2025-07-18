// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IUniswapV2
 * @dev Interface para DEXs que seguem o padrão UniswapV2
 */
interface IUniswapV2 {
    /**
     * @dev Troca tokens por tokens
     * @param amountIn Quantidade de tokens de entrada
     * @param amountOutMin Quantidade mínima de tokens de saída esperada
     * @param path Caminho dos tokens para a troca
     * @param to Endereço que receberá os tokens
     * @param deadline Prazo máximo para a transação
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @dev Troca tokens por tokens com suporte a tokens com taxa
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    /**
     * @dev Troca ETH por tokens
     */
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    /**
     * @dev Troca ETH por tokens com suporte a tokens com taxa
     */
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    /**
     * @dev Troca tokens por ETH
     */
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    /**
     * @dev Troca tokens por ETH com suporte a tokens com taxa
     */
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    /**
     * @dev Retorna os valores esperados para uma troca
     */
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}