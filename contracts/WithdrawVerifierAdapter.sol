// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./IWithdrawVerifier.sol";

/**
 * @dev WithdrawVerifier接口定义
 */
interface IWithdrawVerifierGroth16 {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[3] calldata _pubSignals
    ) external view returns (bool);
}


/**
 * @title WithdrawVerifierAdapter
 * @dev 适配器合约，将Groth16Verifier适配到原有的IWithdrawVerifier接口
 */
contract WithdrawVerifierAdapter is IWithdrawVerifier {
    
    IWithdrawVerifierGroth16 public immutable withdrawVerifier;
    
    /**
     * @dev 构造函数
     * @param _verifier WithdrawVerifier合约地址
     */
    constructor(address _verifier) {
        withdrawVerifier = IWithdrawVerifierGroth16(_verifier);
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
        
        // Withdraw电路有3个公开信号: [merkleRoot, nullifierHash, recipient]
        require(publicInputs.length >= 3, "Invalid public inputs for withdraw circuit");
        uint[3] memory _pubSignals = [
            publicInputs[0], // merkleRoot
            publicInputs[1], // nullifierHash
            publicInputs[2]  // recipient
        ];
        
        return withdrawVerifier.verifyProof(_pA, _pB, _pC, _pubSignals);
    }
}