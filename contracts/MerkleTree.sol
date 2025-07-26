// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract MerkleTree {
    uint256 public constant TREE_HEIGHT = 20;
    uint256 public constant MAX_LEAVES = 2**TREE_HEIGHT;

    // Merkle tree 存储
    bytes32[TREE_HEIGHT] public filledSubtrees;
    bytes32 public merkleRoot;
    uint256 public currentCommitmentIndex;

    // Poseidon hash function approximation (实际应使用专门的Poseidon库)
    function poseidonHash(bytes32 left, bytes32 right) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

    constructor() {
        // 初始化空的subtree hashes
        bytes32 currentZero = bytes32(0);
        filledSubtrees[0] = currentZero;
        
        for (uint256 i = 1; i < TREE_HEIGHT; i++) {
            currentZero = poseidonHash(currentZero, currentZero);
            filledSubtrees[i] = currentZero;
        }
        
        merkleRoot = currentZero;
    }

    /**
     * @dev 插入新的commitment到merkle tree
     * @param commitment 要插入的commitment
     * @return leafIndex 插入的叶子节点索引
     */
    function _insert(bytes32 commitment) internal returns (uint256) {
        require(currentCommitmentIndex < MAX_LEAVES, "Merkle tree is full");
        
        uint256 leafIndex = currentCommitmentIndex;
        bytes32 currentHash = commitment;
        uint256 currentIndex = currentCommitmentIndex;

        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            if (currentIndex % 2 == 0) {
                // 左节点 - 存储并等待右兄弟
                filledSubtrees[i] = currentHash;
                break;
            } else {
                // 右节点 - 与左兄弟合并向上传播
                currentHash = poseidonHash(filledSubtrees[i], currentHash);
            }
            currentIndex /= 2;
        }

        // 如果到达了树顶，更新根
        if (currentIndex % 2 == 1) {
            merkleRoot = currentHash;
        }
        
        currentCommitmentIndex++;
        return leafIndex;
    }

    /**
     * @dev 验证merkle proof
     * @param leaf 叶子节点
     * @param proof merkle proof路径
     * @param pathIndices 路径索引 (0=left, 1=right)
     * @return 是否验证通过
     */
    function verifyMerkleProof(
        bytes32 leaf,
        bytes32[TREE_HEIGHT] memory proof,
        bool[TREE_HEIGHT] memory pathIndices
    ) public view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            bytes32 proofElement = proof[i];
            if (pathIndices[i]) {
                // 当前节点是右子节点
                computedHash = poseidonHash(proofElement, computedHash);
            } else {
                // 当前节点是左子节点
                computedHash = poseidonHash(computedHash, proofElement);
            }
        }

        return computedHash == merkleRoot;
    }

    /**
     * @dev 获取指定索引的merkle proof
     * @param leafIndex 叶子节点索引
     * @return proof merkle proof
     * @return pathIndices 路径索引
     */
    function getMerkleProof(uint256 leafIndex) 
        external 
        view 
        returns (
            bytes32[TREE_HEIGHT] memory proof,
            bool[TREE_HEIGHT] memory pathIndices
        ) 
    {
        require(leafIndex < currentCommitmentIndex, "Invalid leaf index");

        uint256 currentIndex = leafIndex;
        
        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            if (currentIndex % 2 == 0) {
                // 左节点，需要右兄弟节点
                proof[i] = filledSubtrees[i];
                pathIndices[i] = false;
            } else {
                // 右节点，需要左兄弟节点  
                proof[i] = filledSubtrees[i];
                pathIndices[i] = true;
            }
            currentIndex /= 2;
        }
    }

    /**
     * @dev 获取当前树的信息
     */
    function getTreeInfo() external view returns (
        bytes32 root,
        uint256 leafCount
    ) {
        return (merkleRoot, currentCommitmentIndex);
    }
}