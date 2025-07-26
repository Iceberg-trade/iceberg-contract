// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AnonymousSwapPool.sol";

// 1inch交换接口（简化版）
interface I1inchRouter {
    function swap(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata data
    ) external returns (uint256 returnAmount);
}

/**
 * @title SwapOperator
 * @dev 后台服务合约，负责执行1inch swap并更新pool状态
 */
contract SwapOperator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    AnonymousSwapPool public immutable pool;
    I1inchRouter public immutable oneInchRouter;
    

    // 事件
    event SwapExecuted(bytes32 indexed nullifierHash, uint256 inputAmount, uint256 outputAmount);

    constructor(
        AnonymousSwapPool _pool,
        I1inchRouter _oneInchRouter
    ) Ownable(msg.sender) {
        pool = _pool;
        oneInchRouter = _oneInchRouter;
    }

    /**
     * @dev 执行swap
     * @param nullifierHash 用户的nullifier hash
     * @param swapConfigId swap配置ID
     * @param oneInchData 1inch交换数据
     */
    function executeSwap(
        bytes32 nullifierHash,
        uint256 swapConfigId,
        bytes calldata oneInchData
    ) external onlyOwner nonReentrant {
        AnonymousSwapPool.SwapConfig memory config = pool.getSwapConfig(swapConfigId);
        require(config.active, "Swap config not active");

        uint256 amountOut;
        
        if (config.tokenIn == address(0)) {
            // ETH -> Token swap
            amountOut = _swapETHForToken(
                config.tokenOut,
                config.fixedAmount,
                oneInchData
            );
        } else if (config.tokenOut == address(0)) {
            // Token -> ETH swap
            amountOut = _swapTokenForETH(
                config.tokenIn,
                config.fixedAmount,
                oneInchData
            );
        } else {
            // Token -> Token swap
            amountOut = _swapTokenForToken(
                config.tokenIn,
                config.tokenOut,
                config.fixedAmount,
                oneInchData
            );
        }

        // 记录swap结果到pool
        pool.recordSwapResult(nullifierHash, amountOut);
        
        emit SwapExecuted(nullifierHash, config.fixedAmount, amountOut);
    }



    /**
     * @dev ETH -> Token swap
     */
    function _swapETHForToken(
        address tokenOut,
        uint256 ethAmount,
        bytes calldata oneInchData
    ) internal returns (uint256) {
        // 调用1inch进行swap
        // 这里简化实现，实际需要解析oneInchData并调用相应接口
        (bool success, bytes memory result) = address(oneInchRouter).call{value: ethAmount}(
            abi.encodeWithSignature(
                "swap(address,address,uint256,uint256,bytes)",
                address(0), // ETH
                tokenOut,
                ethAmount,
                0, // minReturn从oneInchData解析
                oneInchData
            )
        );
        require(success, "1inch swap failed");
        uint256 amountOut = abi.decode(result, (uint256));
        
        return amountOut;
    }

    /**
     * @dev Token -> ETH swap  
     */
    function _swapTokenForETH(
        address tokenIn,
        uint256 tokenAmount,
        bytes calldata oneInchData
    ) internal returns (uint256) {
        IERC20(tokenIn).forceApprove(address(oneInchRouter), tokenAmount);
        
        uint256 amountOut = oneInchRouter.swap(
            tokenIn,
            address(0), // ETH
            tokenAmount,
            0, // minReturn从oneInchData解析
            oneInchData
        );
        
        return amountOut;
    }

    /**
     * @dev Token -> Token swap
     */
    function _swapTokenForToken(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmount,
        bytes calldata oneInchData
    ) internal returns (uint256) {
        IERC20(tokenIn).forceApprove(address(oneInchRouter), tokenAmount);
        
        uint256 amountOut = oneInchRouter.swap(
            tokenIn,
            tokenOut,
            tokenAmount,
            0, // minReturn从oneInchData解析
            oneInchData
        );
        
        return amountOut;
    }



    // 接收ETH
    receive() external payable {}
}