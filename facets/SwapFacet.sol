// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { IUniswapV2 } from "../interfaces/IUniswapV2.sol";
import { IWETH } from "../interfaces/IWETH.sol";

contract SwapFacet is ReentrancyGuard {

    // Events
    event Swapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        address dex,
        address referrer,
        address receiver,
        bool supportsFeeOnTransfer
    );


    event FeeCollected(
        address indexed user,
        address indexed token,
        uint256 totalFee,
        uint256 referralFee,
        address indexed referrer
    );

    // Storage
    struct SwapStorage {
        uint256 fee;
        uint256 referralPercentage;
        address feeRecipient;
        mapping(address => bool) approvedDexes;
        mapping(uint256 => address) wrappedNativeTokens;
    }

    bytes32 constant SWAP_STORAGE_POSITION = keccak256("diamond.swap.storage");

    function swapStorage() internal pure returns (SwapStorage storage ss) {
        bytes32 position = SWAP_STORAGE_POSITION;
        assembly {
            ss.slot := position
        }
    }

    modifier onlyApprovedDex(address _dex) {
        SwapStorage storage ss = swapStorage();
        require(ss.approvedDexes[_dex], "SwapFacet: DEX nao aprovada");
        _;
    }

    /**
     * @dev Configura o wrapped token nativo para uma chain
     */
    function setWrappedNativeToken(uint256 chainId, address wrappedToken) external {
        require(msg.sender == LibDiamond.contractOwner(), "SwapFacet: Apenas o proprietario");
        require(wrappedToken != address(0), "SwapFacet: Endereco invalido");
        
        SwapStorage storage ss = swapStorage();
        ss.wrappedNativeTokens[chainId] = wrappedToken;
    }

    /**
     * @dev Retorna o wrapped token nativo para uma chain
     */
    function getWrappedNative(uint256 chainId) public view returns (address) {
        SwapStorage storage ss = swapStorage();
        address wrappedToken = ss.wrappedNativeTokens[chainId];
        require(wrappedToken != address(0), "SwapFacet: Wrapped token nao configurado");
        return wrappedToken;
    }

    /**
     * @dev Swap exato de tokens para tokens
     * @param _receiver Endereço que receberá os tokens
     */
    function swapExactTokensForTokens(
        address _dex,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline,
        address _referrer,
        address _receiver,
        bool _supportsFeeOnTransfer
    ) external nonReentrant onlyApprovedDex(_dex) {
        require(_path.length >= 2, "SwapFacet: Caminho invalido");
        require(_receiver != address(0), "SwapFacet: Receiver invalido");
        
        // Transfere tokens do usuário
        TransferHelper.safeTransferFrom(_path[0], msg.sender, address(this), _amountIn);

        
        
        // Calcula e coleta taxa
        (uint256 amountAfterFee, uint256 totalFee, uint256 referralFee) = _collectFee(
            _path[0],
            _amountIn,
            _referrer
        );
        
        // Aprova DEX
        TransferHelper.safeApprove(_path[0], _dex, amountAfterFee);
        
        // Get initial balance of output token
        uint256 balanceBefore = IERC20(_path[_path.length - 1]).balanceOf(_receiver);
        
        // Execute swap
        if (_supportsFeeOnTransfer) {
            IUniswapV2(_dex).swapExactTokensForTokensSupportingFeeOnTransferTokens(
                amountAfterFee,
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        } else {
            IUniswapV2(_dex).swapExactTokensForTokens(
                amountAfterFee,
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        }
        
        // Calculate actual amount received
        uint256 amountOut = IERC20(_path[_path.length - 1]).balanceOf(_receiver) - balanceBefore;
        require(amountOut >= _amountOutMin, "SwapFacet: Insufficient output amount");
        
        // Revoke approval
        TransferHelper.safeApprove(_path[0], _dex, 0);
        
        emit Swapped(
            msg.sender,
            _path[0],
            _path[_path.length - 1],
            _amountIn,
            amountOut,
            totalFee,
            _dex,
            _referrer,
            _receiver,
            _supportsFeeOnTransfer
        );
    }

    /**
     * @dev Swap exato de ETH para tokens
     * @param _receiver Endereço que receberá os tokens
     */
    function swapExactETHForTokens(
        address _dex,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline,
        address _referrer,
        address _receiver,
        bool _supportsFeeOnTransfer
    ) external payable nonReentrant onlyApprovedDex(_dex) {
        require(_path.length >= 2, "SwapFacet: Caminho invalido");
        require(_receiver != address(0), "SwapFacet: Receiver invalido");
        
        // Calcula taxa
        SwapStorage storage ss = swapStorage();
        uint256 totalFee = (msg.value * ss.fee) / 10000;
        uint256 referralFee = 0;
        
        // Processa taxa de referência
        if (_referrer != address(0) && _referrer != msg.sender && ss.referralPercentage > 0) {
            referralFee = (totalFee * ss.referralPercentage) / 10000;
            
            if (referralFee > 0) {
                (bool success, ) = _referrer.call{value: referralFee}("");
                require(success, "SwapFacet: Falha ao enviar taxa de referencia");
            }
        }
        
        // Envia taxa para recipient
        if (totalFee > referralFee) {
            (bool success, ) = ss.feeRecipient.call{value: totalFee - referralFee}("");
            require(success, "SwapFacet: Falha ao enviar taxa");
        }
        
        // Get initial balance of output token
        uint256 balanceBefore = IERC20(_path[_path.length - 1]).balanceOf(_receiver);
        
        // Execute swap
        if (_supportsFeeOnTransfer) {
            IUniswapV2(_dex).swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: msg.value - totalFee
            }(
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        } else {
            IUniswapV2(_dex).swapExactETHForTokens{value: msg.value - totalFee}(
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        }
        
        // Calculate actual amount received
        uint256 amountOut = IERC20(_path[_path.length - 1]).balanceOf(_receiver) - balanceBefore;
        require(amountOut >= _amountOutMin, "SwapFacet: Insufficient output amount");
        
        emit Swapped(
            msg.sender,
            address(0),
            _path[_path.length - 1],
            msg.value,
            amountOut,
            totalFee,
            _dex,
            _referrer,
            _receiver,
            _supportsFeeOnTransfer
        );
        
        emit FeeCollected(
            msg.sender,
            address(0),
            totalFee,
            referralFee,
            _referrer
        );
    }

    /**
     * @dev Swap exato de tokens para ETH
     * @param _receiver Endereço que receberá o ETH
     */
    function swapExactTokensForETH(
        address _dex,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline,
        address _referrer,
        address _receiver,
        bool _supportsFeeOnTransfer
    ) external nonReentrant onlyApprovedDex(_dex) {
        require(_path.length >= 2, "SwapFacet: Caminho invalido");
        require(_receiver != address(0), "SwapFacet: Receiver invalido");
        
        // Transfere tokens do usuário
        TransferHelper.safeTransferFrom(_path[0], msg.sender, address(this), _amountIn);

        
        // Calcula e coleta taxa
        (uint256 amountAfterFee, uint256 totalFee, uint256 referralFee) = _collectFee(
            _path[0],
            _amountIn,
            _referrer
        );
        
        // Aprova DEX
        TransferHelper.safeApprove(_path[0], _dex, amountAfterFee);

        
        // Get initial ETH balance
        uint256 balanceBefore = _receiver.balance;
        
        // Execute swap
        if (_supportsFeeOnTransfer) {
            IUniswapV2(_dex).swapExactTokensForETHSupportingFeeOnTransferTokens(
                amountAfterFee,
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        } else {
            IUniswapV2(_dex).swapExactTokensForETH(
                amountAfterFee,
                _amountOutMin,
                _path,
                _receiver,
                _deadline
            );
        }
        
        // Calculate actual amount received
        uint256 amountOut = _receiver.balance - balanceBefore;
        require(amountOut >= _amountOutMin, "SwapFacet: Insufficient output amount");
        
        // Revoke approval
        TransferHelper.safeApprove(_path[0], _dex, 0);

        
        emit Swapped(
            msg.sender,
            _path[0],
            address(0),
            _amountIn,
            amountOut,
            totalFee,
            _dex,
            _referrer,
            _receiver,
            _supportsFeeOnTransfer
        );
    }

    /**
     * @dev Calcula e coleta taxas
     */
    function _collectFee(
        address _token,
        uint256 _amount,
        address _referrer
    ) internal returns (uint256 amountAfterFee, uint256 totalFee, uint256 referralFee) {
        SwapStorage storage ss = swapStorage();
        
        totalFee = (_amount * ss.fee) / 10000;
        referralFee = 0;
        
        if (_referrer != address(0) && _referrer != msg.sender && ss.referralPercentage > 0) {
            referralFee = (totalFee * ss.referralPercentage) / 10000;
            
            if (referralFee > 0) {
                TransferHelper.safeTransfer(_token, _referrer, referralFee);
            }
        }
        
        if (totalFee > referralFee) {
            TransferHelper.safeTransfer(_token, ss.feeRecipient, totalFee - referralFee);
        }
        
        amountAfterFee = _amount - totalFee;
        
        emit FeeCollected(
            msg.sender,
            _token,
            totalFee,
            referralFee,
            _referrer
        );
        
        return (amountAfterFee, totalFee, referralFee);
    }

    receive() external payable {}
}