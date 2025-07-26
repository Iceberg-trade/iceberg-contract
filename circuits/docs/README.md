# 🔐 AnonymousSwap ZK Circuits

零知识证明电路，用于实现隐私swap协议的匿名withdraw功能。

## 📋 文件说明

### 电路文件
- `withdraw.circom` - 完整的隐私withdraw电路（使用Poseidon哈希）
- `withdraw_simple.circom` - 简化版电路（用于快速测试）
- `merkleTree.circom` - Merkle树验证组件  
- `poseidon.circom` - Poseidon哈希函数实现

### 测试文件
- `test/test-circuit.js` - 完整电路测试
- `test/test-simple.js` - 简化电路测试

## 🚀 快速开始

### 1. 安装依赖

```bash
cd circuits
npm install
```

### 2. 安装Circom (如果还没安装)

```bash
# 安装Rust
curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh
source ~/.cargo/env

# 安装Circom
git clone https://github.com/iden3/circom.git
cd circom
cargo build --release
cargo install --path circom
```

### 3. 测试简化电路

```bash
# 测试简化版电路（推荐先试这个）
node test/test-simple.js
```

### 4. 编译完整电路

```bash
# 编译主电路
npm run compile

# 如果遇到circomlib导入问题，手动安装：
npm install circomlib@2.0.5
```

## 🔧 电路开发流程

### 完整工作流程

```bash
# 1. 编译电路
npm run compile

# 2. 生成Powers of Tau (一次性设置)
npm run setup

# 3. 生成零知识证明密钥
npm run build-zkey

# 4. 生成Solidity验证器
npm run generate-verifier

# 5. 运行测试
npm run test-circuit
```

### 快速测试工作流程

```bash
# 只编译和测试简化电路
circom withdraw_simple.circom --r1cs --wasm
node test/test-simple.js
```

## 📊 电路详细说明

### withdraw.circom - 主要电路

**公开输入**：
- `merkleRoot` - 当前Merkle树根
- `nullifierHash` - 防重放的nullifier hash  
- `recipient` - 接收地址

**私有输入**：
- `nullifier` - 用户的唯一标识符
- `secret` - 用户的随机秘密
- `pathElements[20]` - Merkle proof路径
- `pathIndices[20]` - Merkle proof索引

**验证逻辑**：
1. ✅ `commitment = Poseidon(nullifier, secret)`
2. ✅ `nullifierHash = Poseidon(nullifier)`  
3. ✅ `commitment` 确实在 Merkle树中
4. ✅ `recipient` 不为零

### withdraw_simple.circom - 简化电路

简化版本，用于：
- 🧪 快速测试和调试
- 📚 学习电路开发基础
- 🔧 验证基本逻辑

## 🎯 集成到智能合约

### 1. 生成Solidity验证器

```bash
npm run generate-verifier
```

这会生成 `../contracts/Verifier.sol`

### 2. 在合约中使用

```solidity
import "./Verifier.sol";

contract AnonymousSwapPool {
    Verifier public immutable verifier;
    
    function withdraw(
        bytes32 nullifierHash,
        address recipient, 
        uint256[8] calldata proof
    ) external {
        uint256[] memory publicInputs = new uint256[](3);
        publicInputs[0] = uint256(merkleRoot);
        publicInputs[1] = uint256(nullifierHash);
        publicInputs[2] = uint256(uint160(recipient));
        
        require(verifier.verifyProof(proof, publicInputs), "Invalid proof");
        // ... 转账逻辑
    }
}
```

## 🌐 前端集成

### JavaScript示例

```javascript
import { groth16 } from "snarkjs";

async function generateWithdrawProof(userInputs) {
    const { proof, publicSignals } = await groth16.fullProve(
        {
            nullifier: userInputs.nullifier,
            secret: userInputs.secret,
            merkleRoot: userInputs.merkleRoot,
            pathElements: userInputs.pathElements,
            pathIndices: userInputs.pathIndices,
            recipient: userInputs.recipient
        },
        "/withdraw.wasm",
        "/withdraw_final.zkey"
    );

    return {
        proof: formatProofForSolidity(proof),
        publicSignals
    };
}
```

## 🐛 故障排除

### 常见问题

1. **circomlib导入错误**
   ```bash
   npm install circomlib@2.0.5
   ```

2. **编译超时**
   ```bash
   # 使用简化电路测试
   node test/test-simple.js
   ```

3. **内存不足**
   ```bash
   # 减少约束数量或使用更强的机器
   # 考虑使用云服务器编译
   ```

### 调试技巧

```bash
# 查看电路信息
snarkjs info -r withdraw.r1cs

# 打印约束数量
snarkjs printconstraints withdraw.r1cs withdraw.sym

# 检查witness
snarkjs wtns check withdraw.r1cs witness.wtns
```

## 📈 性能优化

### 约束数量优化
- ✅ 使用高效的哈希函数（Poseidon vs Keccak）
- ✅ 优化Merkle树深度（20层 vs 更少）
- ✅ 避免不必要的约束

### 证明生成时间
- ⚡ 典型时间：2-10秒（取决于电路复杂度）
- 🔧 优化：使用WebWorker在前端异步生成

## 🎓 进阶开发

### 添加新功能

1. **支持多种token**
   ```circom
   signal input tokenType;
   // 添加token验证逻辑
   ```

2. **金额验证**
   ```circom
   signal input amount;
   signal input minAmount;
   component amountCheck = GreaterEqualThan(64);
   ```

3. **时间锁**
   ```circom
   signal input timestamp;
   signal input minTimestamp;
   // 添加时间验证
   ```

## 📚 学习资源

- [Circom文档](https://docs.circom.io/)
- [ZK学习指南](https://github.com/matter-labs/awesome-zero-knowledge-proofs)
- [Tornado Cash电路分析](https://github.com/tornadocash/tornado-core)

## 🤝 贡献指南

1. Fork项目
2. 创建功能分支
3. 测试电路
4. 提交PR

---

🔐 **安全提醒**：这些电路仍在开发中，请勿在生产环境中使用未经充分审计的代码。