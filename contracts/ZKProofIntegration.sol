// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./WithdrawSimpleVerifier.sol";
import "./WithdrawVerifier.sol";

/**
 * @title ZKProofIntegration
 * @dev 集成ZK证明验证的合约
 */
contract ZKProofIntegration {
    WithdrawSimpleVerifier public simpleVerifier;
    WithdrawVerifier public withdrawVerifier;
    
    mapping(bytes32 => bool) public nullifierHashUsed;
    
    event ProofVerified(address indexed user, bytes32 nullifierHash, uint256 timestamp);
    event WithdrawalAuthorized(address indexed user, bytes32 nullifierHash, uint256 amount);
    
    constructor(address _simpleVerifier, address _withdrawVerifier) {
        simpleVerifier = WithdrawSimpleVerifier(_simpleVerifier);
        withdrawVerifier = WithdrawVerifier(_withdrawVerifier);
    }
    
    /**
     * @dev 验证简单withdraw证明
     * @param _pA ZK证明元素A
     * @param _pB ZK证明元素B
     * @param _pC ZK证明元素C
     * @param publicSignals 公开信号 [nullifierHash, recipient]
     */
    function verifySimpleWithdraw(
        uint[2] memory _pA,
        uint[2][2] memory _pB,
        uint[2] memory _pC,
        uint[2] memory publicSignals
    ) external returns (bool) {
        bytes32 nullifierHash = bytes32(publicSignals[0]);
        require(!nullifierHashUsed[nullifierHash], "Nullifier already used");
        
        // Simple验证器需要3个信号：[nullifierHash, recipient, isValid]
        uint[3] memory _pubSignals = [
            publicSignals[0], // nullifierHash
            publicSignals[1], // recipient
            1                 // isValid (always 1)
        ];
        
        // 验证ZK证明
        bool isValid = simpleVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        require(isValid, "Invalid ZK proof");
        
        // 标记nullifier已使用
        nullifierHashUsed[nullifierHash] = true;
        
        emit ProofVerified(msg.sender, nullifierHash, block.timestamp);
        return true;
    }
    
    /**
     * @dev 验证基础withdraw证明
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
        
        // 标记nullifier已使用
        nullifierHashUsed[nullifierHash] = true;
        
        emit ProofVerified(msg.sender, nullifierHash, block.timestamp);
        return true;
    }
    
    /**
     * @dev 更新验证器地址（仅用于测试）
     */
    function updateVerifiers(address _simpleVerifier, address _withdrawVerifier) external {
        simpleVerifier = WithdrawSimpleVerifier(_simpleVerifier);
        withdrawVerifier = WithdrawVerifier(_withdrawVerifier);
    }
}
