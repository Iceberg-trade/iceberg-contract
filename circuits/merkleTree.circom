pragma circom 2.0.0;

include "poseidon.circom";
include "mux1.circom";

// Merkle Tree验证器模板
template MerkleTreeChecker(levels) {
    signal input leaf;                    // 叶子节点
    signal input root;                    // 期望的根节点
    signal input pathElements[levels];    // 路径上的兄弟节点
    signal input pathIndices[levels];     // 路径索引 (0=left, 1=right)

    // 中间信号
    signal pathHashes[levels + 1];
    pathHashes[0] <== leaf;

    // 逐层向上计算hash
    component hashers[levels];
    component mux[levels];

    for (var i = 0; i < levels; i++) {
        // 选择器：根据pathIndices[i]决定左右位置
        mux[i] = Mux1();
        mux[i].c[0] <== pathHashes[i];      // 当前节点作为左子节点
        mux[i].c[1] <== pathElements[i];    // 兄弟节点作为左子节点
        mux[i].s <== pathIndices[i];
        
        // Poseidon哈希计算
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== mux[i].out;
        hashers[i].inputs[1] <== pathHashes[i] + pathElements[i] - mux[i].out; // 另一个输入
        
        pathHashes[i + 1] <== hashers[i].out;
    }

    // 验证计算出的根是否与期望根相同
    root === pathHashes[levels];
}

// 增量式Merkle Tree更新器
template MerkleTreeUpdater(levels) {
    signal input oldRoot;
    signal input newLeaf;
    signal input leafIndex;
    signal input pathElements[levels];
    
    signal output newRoot;
    
    // 计算叶子索引的二进制表示
    component leafIndexBits = Num2Bits(levels);
    leafIndexBits.in <== leafIndex;
    
    // 逐层计算新的hash
    signal pathHashes[levels + 1];
    pathHashes[0] <== newLeaf;
    
    component hashers[levels];
    component mux[levels];
    
    for (var i = 0; i < levels; i++) {
        mux[i] = Mux1();
        mux[i].c[0] <== pathHashes[i];      // 新节点作为左子节点
        mux[i].c[1] <== pathElements[i];    // 兄弟节点作为左子节点  
        mux[i].s <== leafIndexBits.out[i];
        
        hashers[i] = Poseidon(2);
        hashers[i].inputs[0] <== mux[i].out;
        hashers[i].inputs[1] <== pathHashes[i] + pathElements[i] - mux[i].out;
        
        pathHashes[i + 1] <== hashers[i].out;
    }
    
    newRoot <== pathHashes[levels];
}

// 多叶子Merkle Tree验证器
template MerkleTreeMultiChecker(levels, leafCount) {
    signal input leaves[leafCount];
    signal input root;
    signal input pathElements[leafCount][levels];
    signal input pathIndices[leafCount][levels];
    
    // 为每个叶子创建验证器
    component checkers[leafCount];
    
    for (var i = 0; i < leafCount; i++) {
        checkers[i] = MerkleTreeChecker(levels);
        checkers[i].leaf <== leaves[i];
        checkers[i].root <== root;
        
        for (var j = 0; j < levels; j++) {
            checkers[i].pathElements[j] <== pathElements[i][j];
            checkers[i].pathIndices[j] <== pathIndices[i][j];
        }
    }
}

// Poseidon Hash函数包装器（2输入）
template PoseidonHasher() {
    signal input left;
    signal input right;
    signal output hash;
    
    component hasher = Poseidon(2);
    hasher.inputs[0] <== left;
    hasher.inputs[1] <== right;
    hash <== hasher.out;
}

// 空值检查器
template IsZero() {
    signal input in;
    signal output out;
    
    signal inv;
    inv <-- in == 0 ? 0 : 1 / in;
    out <== 1 - in * inv;
    out * in === 0;
}

// 条件选择器
template ConditionalSelect() {
    signal input condition;
    signal input ifTrue;
    signal input ifFalse;
    signal output out;
    
    out <== condition * (ifTrue - ifFalse) + ifFalse;
}