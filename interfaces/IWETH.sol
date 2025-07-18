// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IWETH
 * @dev Interface para tokens wrapped nativos (WETH, WBNB, etc)
 */
interface IWETH {
    /**
     * @dev Converte ETH para WETH
     */
    function deposit() external payable;

    /**
     * @dev Converte WETH para ETH
     */
    function withdraw(uint256 amount) external;

}
