// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MerkleTree.sol";
import "./IWithdrawVerifier.sol";

contract AnonymousSwapPool is ReentrancyGuard, Ownable, MerkleTree {
    using SafeERC20 for IERC20;

    enum CommitmentState { None, Deposited, Swapped, Withdrawn }

    struct SwapConfig {
        address tokenIn;      // 输入token地址
        address tokenOut;     // 输出token地址  
        uint256 fixedAmount;  // 固定金额
        uint256 minDelay;     // 最小延迟时间(秒)
        bool active;          // 是否激活
    }

    // 事件定义
    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp, uint256 swapConfigId);
    event SwapResultRecorded(bytes32 indexed nullifierHash, uint256 amountOut, uint256 timestamp);
    event Withdrawal(bytes32 indexed nullifierHash, address recipient, uint256 amount);
    event SwapConfigAdded(uint256 indexed configId, address tokenIn, address tokenOut, uint256 fixedAmount);

    // 状态变量
    mapping(bytes32 => CommitmentState) public commitmentStates;
    mapping(bytes32 => uint256) public swappedAmounts;
    mapping(bytes32 => uint256) public depositTimestamps;
    mapping(bytes32 => bool) public nullifierHashUsed;
    mapping(uint256 => SwapConfig) public swapConfigs;
    
    uint256 public nextSwapConfigId = 1;
    address public operator;  // 后台服务地址
    IWithdrawVerifier public immutable verifier;

    modifier onlyOperator() {
        require(msg.sender == operator, "Only operator can call this function");
        _;
    }

    constructor(
        IWithdrawVerifier _verifier,
        address _operator
    ) Ownable(msg.sender) MerkleTree() {
        verifier = _verifier;
        operator = _operator;
    }

    /**
     * @dev 用户存款并提交commitment
     * @param commitment 用户的commitment = hash(nullifier, secret)
     * @param swapConfigId swap配置ID
     */
    function deposit(bytes32 commitment, uint256 swapConfigId) external payable nonReentrant {
        require(commitment != 0, "Invalid commitment");
        require(swapConfigs[swapConfigId].active, "Swap config not active");
        
        SwapConfig memory config = swapConfigs[swapConfigId];
        
        if (config.tokenIn == address(0)) {
            // ETH deposit
            require(msg.value == config.fixedAmount, "Invalid ETH amount");
        } else {
            // ERC20 deposit
            require(msg.value == 0, "ETH not expected");
            IERC20(config.tokenIn).safeTransferFrom(msg.sender, address(this), config.fixedAmount);
        }

        uint256 leafIndex = _insert(commitment);
        commitmentStates[commitment] = CommitmentState.Deposited;
        depositTimestamps[commitment] = block.timestamp;

        emit Deposit(commitment, leafIndex, block.timestamp, swapConfigId);
    }

    /**
     * @dev 记录swap完成状态
     * @param nullifierHash nullifier的hash值
     * @param amountOut swap得到的输出金额
     */
    function recordSwapResult(
        bytes32 nullifierHash, 
        uint256 amountOut
    ) external onlyOperator nonReentrant {
        require(!nullifierHashUsed[nullifierHash], "Nullifier already used");
        require(amountOut > 0, "Invalid output amount");

        nullifierHashUsed[nullifierHash] = true;
        swappedAmounts[nullifierHash] = amountOut;

        emit SwapResultRecorded(nullifierHash, amountOut, block.timestamp);
    }

    /**
     * @dev 用户使用新地址提取swap后的token
     * @param nullifierHash nullifier的hash值
     * @param recipient 接收地址
     * @param proof ZK证明
     */
    function withdraw(
        bytes32 nullifierHash,
        address recipient,
        uint256[8] calldata proof
    ) external nonReentrant {
        require(recipient != address(0), "Invalid recipient");
        require(swappedAmounts[nullifierHash] > 0, "No swapped amount available");
        require(nullifierHashUsed[nullifierHash], "Swap not executed yet");

        // 验证ZK证明
        uint256[] memory publicInputs = new uint256[](3);
        publicInputs[0] = uint256(merkleRoot);
        publicInputs[1] = uint256(nullifierHash);
        publicInputs[2] = uint256(uint160(recipient));

        require(verifier.verifyProof(proof, publicInputs), "Invalid proof");

        // 删除swap金额，防止重复提取
        uint256 amount = swappedAmounts[nullifierHash];
        delete swappedAmounts[nullifierHash];
        
        // 转账给用户
        // 这里假设输出token是ETH，实际实现中需要根据swap配置确定token类型
        payable(recipient).transfer(amount);

        emit Withdrawal(nullifierHash, recipient, amount);
    }

    /**
     * @dev 添加新的swap配置
     */
    function addSwapConfig(
        address tokenIn,
        address tokenOut,
        uint256 fixedAmount,
        uint256 minDelay
    ) external onlyOwner returns (uint256) {
        require(fixedAmount > 0, "Invalid fixed amount");
        
        uint256 configId = nextSwapConfigId++;
        swapConfigs[configId] = SwapConfig({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fixedAmount: fixedAmount,
            minDelay: minDelay,
            active: true
        });

        emit SwapConfigAdded(configId, tokenIn, tokenOut, fixedAmount);
        return configId;
    }

    /**
     * @dev 设置operator地址
     */
    function setOperator(address _operator) external onlyOwner {
        require(_operator != address(0), "Invalid operator address");
        operator = _operator;
    }


    /**
     * @dev 获取swap配置信息
     */
    function getSwapConfig(uint256 configId) external view returns (SwapConfig memory) {
        return swapConfigs[configId];
    }

    /**
     * @dev 检查commitment是否有效
     */
    function isValidCommitment(bytes32 commitment) external view returns (bool) {
        return commitmentStates[commitment] == CommitmentState.Deposited;
    }

    /**
     * @dev 获取当前merkle root
     */
    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }


    // 接收ETH
    receive() external payable {}
}