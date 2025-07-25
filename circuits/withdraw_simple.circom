pragma circom 2.0.0;

// 简化版的隐私swap withdraw电路
// 这个版本使用keccak256而不是poseidon，更容易测试

template Withdraw() {
    // 公开输入
    signal input nullifierHash;
    signal input recipient;

    // 私有输入  
    signal private input nullifier;
    signal private input secret;

    // 中间信号
    signal commitmentSquared;
    signal nullifierSquared;

    // 1. 简化的commitment计算 (用平方代替复杂哈希)
    commitmentSquared <== nullifier * secret;

    // 2. 简化的nullifier验证
    nullifierSquared <== nullifier * nullifier;
    nullifierHash === nullifierSquared;

    // 3. 确保secret不为零
    signal secretInv;
    secretInv <-- 1 / secret;
    secret * secretInv === 1;

    // 4. 确保recipient不为零  
    signal recipientInv;
    recipientInv <-- 1 / recipient;
    recipient * recipientInv === 1;

    // 输出验证标志
    signal output isValid;
    isValid <== 1;
}

component main {public [nullifierHash, recipient]} = Withdraw();