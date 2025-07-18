// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title IERC20Extended
 * @dev Interface for ERC20 tokens with decimals function
 */
interface IERC20Extended {
    /**
     * @dev Returns the number of decimals used by the token
     */
    function decimals() external view returns (uint8);
    
    /**
     * @dev Returns the amount of tokens owned by `account`
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}
     */
    function allowance(address owner, address spender) external view returns (uint256);
    
    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens
     */
    function approve(address spender, uint256 amount) external returns (bool);
    
    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    /**
     * @dev Returns the amount of tokens in existence
     */
    function totalSupply() external view returns (uint256);
    
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`)
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}