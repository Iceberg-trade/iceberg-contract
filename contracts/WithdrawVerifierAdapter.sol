// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IWithdrawVerifier.sol";

/**
 * @dev Groth16Verifier接口定义
 */
interface IGroth16VerifierSimple {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[3] calldata _pubSignals
    ) external view returns (bool);
}

interface IGroth16VerifierBasic {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[2] calldata _pubSignals
    ) external view returns (bool);
}

/**
 * @title WithdrawVerifierAdapter
 * @dev 适配器合约，将Groth16Verifier适配到原有的IWithdrawVerifier接口
 */
contract WithdrawVerifierAdapter is IWithdrawVerifier {
    
    IGroth16VerifierSimple public immutable simpleVerifier;
    IGroth16VerifierBasic public immutable basicVerifier;
    
    enum VerifierType { Simple, Basic }
    VerifierType public immutable verifierType;
    
    /**
     * @dev 构造函数
     * @param _verifier 验证器地址
     * @param _isSimple true表示Simple验证器，false表示Basic验证器
     */
    constructor(address _verifier, bool _isSimple) {
        verifierType = _isSimple ? VerifierType.Simple : VerifierType.Basic;
        simpleVerifier = _isSimple ? IGroth16VerifierSimple(_verifier) : IGroth16VerifierSimple(address(0));
        basicVerifier = _isSimple ? IGroth16VerifierBasic(address(0)) : IGroth16VerifierBasic(_verifier);
    }
    
    /**
     * @dev 验证withdrawal的ZK证明
     * @param proof ZK证明数组 [8]uint256 -> 转换为Groth16格式
     * @param publicInputs 公开输入: [merkleRoot, nullifierHash, recipient]
     * @return 验证是否通过
     */
    function verifyProof(
        uint256[8] calldata proof,
        uint256[] calldata publicInputs
    ) external view override returns (bool) {
        
        // 将proof[8]转换为Groth16格式
        uint[2] memory _pA = [proof[0], proof[1]];
        uint[2][2] memory _pB = [[proof[2], proof[3]], [proof[4], proof[5]]];
        uint[2] memory _pC = [proof[6], proof[7]];
        
        if (verifierType == VerifierType.Simple) {
            // Simple电路有2个公开信号: [nullifierHash, recipient]
            require(publicInputs.length >= 3, "Invalid public inputs for simple circuit");
            uint[3] memory _pubSignals = [
                publicInputs[1], // nullifierHash
                publicInputs[2], // recipient
                1 // isValid output (always 1)
            ];
            return simpleVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
            
        } else {
            // Basic电路有2个公开信号: [nullifierHash, recipient]
            require(publicInputs.length >= 3, "Invalid public inputs for basic circuit");
            uint[2] memory _pubSignals = [
                publicInputs[1], // nullifierHash
                publicInputs[2]  // recipient
            ];
            return basicVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        }
    }
}