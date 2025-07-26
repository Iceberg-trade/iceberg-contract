// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title IWithdrawVerifier
 * @dev ZK证明验证器接口
 */
interface IWithdrawVerifier {
    /**
     * @dev 验证withdrawal的ZK证明
     * @param proof ZK证明数组
     * @param publicInputs 公开输入: [merkleRoot, nullifierHash, recipient]
     * @return 验证是否通过
     */
    function verifyProof(
        uint256[8] calldata proof,
        uint256[] calldata publicInputs
    ) external view returns (bool);
}