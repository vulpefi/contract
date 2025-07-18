// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { ReentrancyGuard } from "../utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { TransferHelper } from "../libraries/TransferHelper.sol";
import { IV3SwapRouter } from "../interfaces/IV3SwapRouter.sol";
import { IWETH } from "../interfaces/IWETH.sol";

contract V3SwapFacet is ReentrancyGuard {
    // using SafeERC20 for IERC20;

    struct SwapStorage {
        uint256 fee;
        uint256 referralPercentage;
        address feeRecipient;
        mapping(address => bool) approvedDexes;
        mapping(uint256 => address) wrappedNativeTokens;
    }

    event FeeCollected(
        address indexed user,
        address indexed token,
        uint256 totalFee,
        uint256 referralFee,
        address indexed referrer
    );

    event MulticallExecuted(
        address indexed user,
        address indexed router,
        uint256 callCount,
        uint256 totalFee
    );

    event Swapped(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        address router,
        address referrer,
        address receiver
    );

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

    function setWrappedNativeToken(uint256 chainId, address wrappedToken) external {
        require(msg.sender == LibDiamond.contractOwner(), "SwapFacet: Apenas o proprietario");
        require(wrappedToken != address(0), "SwapFacet: Endereco invalido");
        SwapStorage storage ss = swapStorage();
        ss.wrappedNativeTokens[chainId] = wrappedToken;
    }

    function getWrappedNative(uint256 chainId) public view returns (address) {
        SwapStorage storage ss = swapStorage();
        address wrappedToken = ss.wrappedNativeTokens[chainId];
        require(wrappedToken != address(0), "SwapFacet: Wrapped token nao configurado");
        return wrappedToken;
    }

    function _safeApprove(address token, address spender, uint256 amount) internal {
        IERC20 erc20 = IERC20(token);
        uint256 current = erc20.allowance(address(this), spender);
        if (current > 0) {
            erc20.approve(spender, 0);
        }
        erc20.approve(spender, amount);
    }

    function swapExactETHForTokens(
        address _dex,
        address tokenOut,
        uint24 fee,
        uint256 amountOutMin,
        uint160 sqrtPriceLimitX96,
        address referrer,
        address receiver
    ) external payable nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
        require(tokenOut != address(0) && receiver != address(0), "V3SwapFacet: Parametros invalidos");
        require(msg.value > 0, "V3SwapFacet: Valor invalido");

        SwapStorage storage ss = swapStorage();
        uint256 totalFee = (msg.value * ss.fee) / 10000;
        uint256 referralFee = 0;

        if (referrer != address(0) && referrer != msg.sender) {
            referralFee = (totalFee * ss.referralPercentage) / 10000;
            if (referralFee > 0) {
                (bool success,) = referrer.call{value: referralFee}("");
                require(success, "V3SwapFacet: Falha na taxa referral");
            }
        }

        if (totalFee > referralFee) {
            (bool success,) = ss.feeRecipient.call{value: totalFee - referralFee}("");
            require(success, "V3SwapFacet: Falha na taxa feeRecipient");
        }

        uint256 afterFee = msg.value - totalFee;
        address wrapped = getWrappedNative(block.chainid);
        IWETH(wrapped).deposit{value: afterFee}();
        // _safeApprove(wrapped, _dex, afterFee);
        TransferHelper.safeApprove(wrapped, _dex, afterFee);


        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: wrapped,
            tokenOut: tokenOut,
            fee: fee,
            recipient: receiver,
            amountIn: afterFee,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        amountOut = IV3SwapRouter(_dex).exactInputSingle(params);
        // _safeApprove(wrapped, _dex, 0);
        TransferHelper.safeApprove(wrapped, _dex, 0);

    }

    function swapExactTokensForETH(
        address _dex,
        address tokenIn,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMin,
        uint160 sqrtPriceLimitX96,
        address referrer,
        address receiver
    ) external nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
        require(tokenIn != address(0) && receiver != address(0), "V3SwapFacet: Parametros invalidos");

        // IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);

        (uint256 afterFee, uint256 totalFee, uint256 referralFee) = _collectFee(tokenIn, amountIn, referrer);

        address wrapped = getWrappedNative(block.chainid);
        // _safeApprove(tokenIn, _dex, afterFee);
        TransferHelper.safeApprove(tokenIn, _dex, afterFee);



        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: wrapped,
            fee: fee,
            recipient: address(this),
            amountIn: afterFee,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        amountOut = IV3SwapRouter(_dex).exactInputSingle(params);

        IWETH(wrapped).withdraw(amountOut);
        (bool success, ) = receiver.call{value: amountOut}("");
        require(success, "V3SwapFacet: Falha no envio ETH");
        // _safeApprove(tokenIn, _dex, 0);
        TransferHelper.safeApprove(tokenIn, _dex, 0);

        emit Swapped(msg.sender, tokenIn, wrapped, amountIn, amountOut, totalFee, _dex, referrer, receiver);
        emit FeeCollected(msg.sender, tokenIn, totalFee, referralFee, referrer);
    }

      function swapExactInputSingle(
        address _dex,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMin,
        uint160 sqrtPriceLimitX96,
        address referrer,
        address receiver
    ) external nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
        require(tokenIn != address(0) && tokenOut != address(0), "V3SwapFacet: Tokens invalidos");
        require(receiver != address(0), "V3SwapFacet: Destinatario invalido");

        // IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        (uint256 afterFee, uint256 totalFee, uint256 referralFee) = _collectFee(tokenIn, amountIn, referrer);

        // _safeApprove(tokenIn, _dex, afterFee);
        TransferHelper.safeApprove(tokenIn, _dex, afterFee);


        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: receiver,
            amountIn: afterFee,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        amountOut = IV3SwapRouter(_dex).exactInputSingle(params);

        // _safeApprove(tokenIn, _dex, 0);
        TransferHelper.safeApprove(tokenIn, _dex, 0);


        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut, totalFee, _dex, referrer, receiver);
        emit FeeCollected(msg.sender, tokenIn, totalFee, referralFee, referrer);
    }

    function swapExactInput(
        address _dex,
        address tokenIn,
        address tokenOut,
        bytes calldata path,
        uint256 amountIn,
        uint256 amountOutMin,
        address referrer,
        address receiver
    ) external nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
        require(path.length > 0 && tokenIn != address(0), "V3SwapFacet: Caminho invalido");
        // IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        (uint256 afterFee, uint256 totalFee, uint256 referralFee) = _collectFee(tokenIn, amountIn, referrer);

        // _safeApprove(tokenIn, _dex, afterFee);
        TransferHelper.safeApprove(tokenIn, _dex, afterFee);


        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: path,
            recipient: receiver,
            amountIn: afterFee,
            amountOutMinimum: amountOutMin
        });

        amountOut = IV3SwapRouter(_dex).exactInput(params);

        // _safeApprove(tokenIn, _dex, 0);
        TransferHelper.safeApprove(tokenIn, _dex, 0);


        emit Swapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut, totalFee, _dex, referrer, receiver);
        emit FeeCollected(msg.sender, tokenIn, totalFee, referralFee, referrer);
    }

    function swapExactETHForTokensMultihop(
    address _dex,
    bytes calldata path,
    uint256 amountOutMin,
    address referrer,
    address receiver
) external payable nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
    require(path.length > 0 && receiver != address(0), "V3SwapFacet: Parametros invalidos");
    require(msg.value > 0, "V3SwapFacet: Valor invalido");

    SwapStorage storage ss = swapStorage();
    uint256 totalFee = (msg.value * ss.fee) / 10000;
    uint256 referralFee = 0;

    if (referrer != address(0) && referrer != msg.sender) {
        referralFee = (totalFee * ss.referralPercentage) / 10000;
        if (referralFee > 0) {
            (bool success,) = referrer.call{value: referralFee}("");
            require(success, "V3SwapFacet: Falha na taxa referral");
        }
    }

    if (totalFee > referralFee) {
        (bool success,) = ss.feeRecipient.call{value: totalFee - referralFee}("");
        require(success, "V3SwapFacet: Falha na taxa feeRecipient");
    }

    uint256 afterFee = msg.value - totalFee;
    address wrapped = getWrappedNative(block.chainid);
    IWETH(wrapped).deposit{value: afterFee}();
    // _safeApprove(wrapped, _dex, afterFee);
    TransferHelper.safeApprove(wrapped, _dex, afterFee);


    IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
        path: path,
        recipient: receiver,
        amountIn: afterFee,
        amountOutMinimum: amountOutMin
    });

    amountOut = IV3SwapRouter(_dex).exactInput(params);
    // _safeApprove(wrapped, _dex, 0);
    TransferHelper.safeApprove(wrapped, _dex, 0);

}

function swapExactTokensForETHMultihop(
    address _dex,
    address tokenIn,
    bytes calldata path,
    uint256 amountIn,
    uint256 amountOutMin,
    address referrer,
    address receiver
) external nonReentrant onlyApprovedDex(_dex) returns (uint256 amountOut) {
    require(path.length > 0 && tokenIn != address(0), "V3SwapFacet: Parametros invalidos");

    // IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
    TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
    (uint256 afterFee, uint256 totalFee, uint256 referralFee) = _collectFee(tokenIn, amountIn, referrer);

    // _safeApprove(tokenIn, _dex, afterFee);
    TransferHelper.safeApprove(tokenIn, _dex, afterFee);


    IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
        path: path,
        recipient: address(this),
        amountIn: afterFee,
        amountOutMinimum: amountOutMin
    });

    amountOut = IV3SwapRouter(_dex).exactInput(params);

    address wrapped = getWrappedNative(block.chainid);
    IWETH(wrapped).withdraw(amountOut);
    (bool success, ) = receiver.call{value: amountOut}("");
    require(success, "V3SwapFacet: Falha no envio ETH");

    // _safeApprove(tokenIn, _dex, 0);
    TransferHelper.safeApprove(tokenIn, _dex, 0);

}


    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results) {
    require(data.length > 0, "V3SwapRouter: Nenhuma chamada fornecida");

    results = new bytes[](data.length);

    for (uint256 i = 0; i < data.length; i++) {
        (bool success, bytes memory returnData) = address(this).delegatecall(data[i]);
        require(success, "V3SwapRouter: Falha na chamada");
        results[i] = returnData;
    }

    emit MulticallExecuted(msg.sender, address(this), data.length, 0);
}

function multicallWithValue(bytes[] calldata data, uint256[] calldata values) external payable returns (bytes[] memory results) {
    require(data.length == values.length, "V3SwapRouter: mismatch inputs");
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; i++) {
        (bool success, bytes memory returnData) = address(this).call{value: values[i]}(data[i]);
        require(success, "V3SwapRouter: call failed");
        results[i] = returnData;
    }

    emit MulticallExecuted(msg.sender, address(this), data.length, msg.value);
}
  


    function _collectFee(
        address token,
        uint256 amount,
        address referrer
    ) internal returns (uint256 afterFee, uint256 totalFee, uint256 referralFee) {
        SwapStorage storage ss = swapStorage();
        totalFee = (amount * ss.fee) / 10000;
        referralFee = 0;

        if (referrer != address(0) && referrer != msg.sender) {
            referralFee = (totalFee * ss.referralPercentage) / 10000;
            if (referralFee > 0) {
                // IERC20(token).safeTransfer(referrer, referralFee);
                TransferHelper.safeTransfer(token, referrer, referralFee);

            }
        }
        

        if (totalFee > referralFee) {
            // IERC20(token).safeTransfer(ss.feeRecipient, totalFee - referralFee);
            TransferHelper.safeTransfer(token, ss.feeRecipient, totalFee - referralFee);
        }

        afterFee = amount - totalFee;
    }

    receive() external payable {}
}
