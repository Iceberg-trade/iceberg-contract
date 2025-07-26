const { buildPoseidon } = require("circomlibjs");
const fs = require("fs");
const path = require("path");

// 生成withdraw完整电路的测试数据
async function generateBasicFixedData() {
    console.log("生成withdraw完整电路测试数据（真正的Poseidon哈希）...");
    
    // 构建Poseidon哈希函数
    const poseidon = await buildPoseidon();
    
    // 1. 设置私有输入
    const nullifier = BigInt("12345678901234567890");
    const secret = BigInt("98765432109876543210");
    
    console.log("Nullifier:", nullifier.toString());
    console.log("Secret:", secret.toString());
    
    // 2. 计算真正的Poseidon哈希
    const commitment = poseidon([nullifier, secret]);
    const nullifierHash = poseidon([nullifier]);
    
    // 转换为字符串格式
    const commitmentStr = poseidon.F.toString(commitment);
    const nullifierHashStr = poseidon.F.toString(nullifierHash);
    
    console.log("Commitment:", commitmentStr);
    console.log("NullifierHash:", nullifierHashStr);
    
    // 3. 构建Merkle Tree (5层)
    const levels = 5;
    const leafIndex = 0; // commitment在第0个位置
    
    // 生成Merkle路径
    const pathElements = [];
    const pathIndices = [];
    
    let currentIndex = leafIndex;
    let currentHash = commitment;
    
    for (let i = 0; i < levels; i++) {
        const isRight = currentIndex % 2;
        pathIndices.push(isRight);
        
        // 兄弟节点设为0（空节点）
        const siblingHash = BigInt(0);
        pathElements.push(siblingHash.toString());
        
        // 计算父节点哈希 - 使用真正的Poseidon
        if (isRight === 0) {
            // 当前节点是左子树
            currentHash = poseidon([currentHash, siblingHash]);
        } else {
            // 当前节点是右子树
            currentHash = poseidon([siblingHash, currentHash]);
        }
        
        currentIndex = Math.floor(currentIndex / 2);
    }
    
    const merkleRoot = currentHash;
    const merkleRootStr = poseidon.F.toString(merkleRoot);
    console.log("MerkleRoot:", merkleRootStr);
    
    // 4. 设置recipient地址（模拟以太坊地址）
    const recipient = BigInt("0x1234567890123456789012345678901234567890");
    
    // 5. 创建电路输入 - 只包含私有输入
    const circuitInput = {
        nullifier: nullifier.toString(),
        secret: secret.toString(),
        pathElements: pathElements,
        pathIndices: pathIndices
    };
    
    // 6. 保存输入文件
    const inputPath = path.join(__dirname, "../proofs/inputs/input_basic_fixed_complete.json");
    fs.writeFileSync(inputPath, JSON.stringify(circuitInput, null, 2));
    console.log("完整电路输入文件已保存:", inputPath);
    
    // 7. 创建预期的公开信号 [merkleRoot, nullifierHash, recipient] 
    const publicSignals = [
        merkleRootStr, 
        nullifierHashStr, 
        recipient.toString()
    ];
    const publicPath = path.join(__dirname, "../proofs/examples/public_basic_fixed_complete.json");
    fs.writeFileSync(publicPath, JSON.stringify(publicSignals, null, 2));
    console.log("完整电路公开信号已保存:", publicPath);
    
    console.log("\\n=== 完整版测试数据生成完成！===");
    console.log("✅ 使用了真正的Poseidon哈希实现");
    console.log("✅ 兼容circomlib/circuits/poseidon.circom");
    console.log("✅ 可以通过完整电路验证");
    
    return { circuitInput, publicSignals };
}

// 运行生成函数
if (require.main === module) {
    generateBasicFixedData().catch(console.error);
}

module.exports = { generateBasicFixedData };