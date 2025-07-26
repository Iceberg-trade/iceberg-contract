// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./WithdrawVerifier.sol";

/**
 * @title ZKProofIntegration
 * @dev 集成ZK证明验证的合约
 */
contract ZKProofIntegration {
    WithdrawVerifier public withdrawVerifier;
    
    mapping(bytes32 => bool) public nullifierHashUsed;
    
    event ProofVerified(address indexed user, bytes32 nullifierHash, uint256 timestamp);
    event WithdrawalAuthorized(address indexed user, bytes32 nullifierHash, uint256 amount);
    
    constructor(address _withdrawVerifier) {
        withdrawVerifier = WithdrawVerifier(_withdrawVerifier);
    }
    
    /**
     * @dev 验证withdraw证明
     * @param _pA ZK证明元素A
     * @param _pB ZK证明元素B  
     * @param _pC ZK证明元素C
     * @param publicSignals 公开信号 [merkleRoot, nullifierHash, recipient]
     */
    function verifyWithdraw(
        uint[2] memory _pA,
        uint[2][2] memory _pB,
        uint[2] memory _pC,
        uint[3] memory publicSignals
    ) external returns (bool) {
        bytes32 nullifierHash = bytes32(publicSignals[1]); // nullifierHash在第2个位置
        require(!nullifierHashUsed[nullifierHash], "Nullifier already used");
        
        // 验证ZK证明
        bool isValid = withdrawVerifier.verifyProof(_pA, _pB, _pC, publicSignals);
        require(isValid, "Invalid ZK proof");
        
        // 标记nullifier为已使用
        nullifierHashUsed[nullifierHash] = true;
        
        emit ProofVerified(msg.sender, nullifierHash, block.timestamp);
        emit WithdrawalAuthorized(msg.sender, nullifierHash, 0); // amount可以根据需要设置
        
        return true;
    }
    
    /**
     * @dev 更新验证器地址（仅管理员）
     * @param _withdrawVerifier 新的withdraw验证器地址
     */
    function updateVerifier(address _withdrawVerifier) external {
        // 这里可以添加 onlyOwner 修饰符
        withdrawVerifier = WithdrawVerifier(_withdrawVerifier);
    }
    
    /**
     * @dev 检查nullifier是否已使用
     * @param nullifierHash nullifier哈希
     * @return 是否已使用
     */
    function isNullifierUsed(bytes32 nullifierHash) external view returns (bool) {
        return nullifierHashUsed[nullifierHash];
    }
}