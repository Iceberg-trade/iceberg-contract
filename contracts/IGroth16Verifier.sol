// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IGroth16Verifier
 * @dev Groth16 ZK证明验证器统一接口
 */
interface IGroth16Verifier {
    /**
     * @dev 验证Groth16 ZK证明
     * @param _pA 证明元素A
     * @param _pB 证明元素B  
     * @param _pC 证明元素C
     * @param _pubSignals 公开信号数组
     * @return 验证是否通过
     */
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB, 
        uint[2] calldata _pC,
        uint[] calldata _pubSignals
    ) external view returns (bool);
}