# 📄 合约目录状态报告

## ✅ 当前合约文件

### 🔧 核心业务合约
- **AnonymousSwapPool.sol** - 匿名交换池主合约
- **SwapOperator.sol** - 交换操作合约  
- **MerkleTree.sol** - Merkle树实现

### 🔐 ZK验证相关合约
- **WithdrawSimpleVerifier.sol** ✨ - 简化电路的Groth16验证器
- **WithdrawBasicFixedVerifier.sol** ✨ - 基础电路的Groth16验证器
- **ZKProofIntegration.sol** ✨ - ZK证明集成合约（推荐使用）

### 🔌 接口和适配器
- **IWithdrawVerifier.sol** - 旧版验证器接口
- **IGroth16Verifier.sol** ✨ - 新版Groth16验证器接口
- **WithdrawVerifierAdapter.sol** ✨ - 适配器合约（兼容旧接口）

## 🎯 推荐使用方案

### 方案1: 使用新的ZKProofIntegration合约 (推荐)
```solidity
// 部署验证器
address simpleVerifier = deploy WithdrawSimpleVerifier();
address basicVerifier = deploy WithdrawBasicFixedVerifier();

// 部署集成合约
ZKProofIntegration zkProof = new ZKProofIntegration(simpleVerifier, basicVerifier);

// 验证证明
zkProof.verifySimpleWithdraw(pA, pB, pC, [nullifierHash, recipient]);
zkProof.verifyBasicWithdraw(pA, pB, pC, []); // 没有公开信号
```

### 方案2: 使用适配器兼容现有系统
```solidity
// 为Simple电路创建适配器
WithdrawVerifierAdapter simpleAdapter = new WithdrawVerifierAdapter(simpleVerifier, true);

// 为Basic电路创建适配器  
WithdrawVerifierAdapter basicAdapter = new WithdrawVerifierAdapter(basicVerifier, false);

// 在AnonymousSwapPool中使用
AnonymousSwapPool pool = new AnonymousSwapPool(simpleAdapter, operator);
```

## 📊 验证器特性对比

| 验证器 | 公开信号数量 | 约束数量 | 用途 |
|--------|-------------|---------|------|
| WithdrawSimpleVerifier | 3 (`[nullifierHash, recipient, isValid]`) | 5 | 简化测试 |
| WithdrawBasicFixedVerifier | 0 (全私有) | 8 | 更强隐私 |

## 🔄 电路到验证器映射

### Simple电路 (`withdraw_simple.circom`)
- **公开输入**: `nullifierHash`, `recipient`
- **公开输出**: `isValid` 
- **验证器**: `WithdrawSimpleVerifier.sol`
- **调用格式**: `verifyProof(pA, pB, pC, [nullifierHash, recipient, 1])`

### BasicFixed电路 (`withdraw_basic_fixed.circom`)
- **公开输入**: 无 (全部私有)
- **公开输出**: 无
- **验证器**: `WithdrawBasicFixedVerifier.sol`
- **调用格式**: `verifyProof(pA, pB, pC, [])`

## 🧹 清理的文件

### ❌ 已删除的过时文件
- `WithdrawBasicVerifier.sol` - 旧版basic电路验证器
- `WithdrawVerifier.sol` - 旧版模拟验证器

## 🚀 下一步建议

1. **测试集成**: 使用`ZKProofIntegration.sol`进行端到端测试
2. **性能对比**: 测试Simple vs BasicFixed电路的性能差异
3. **部署策略**: 根据需求选择使用方案1或方案2
4. **文档更新**: 更新项目文档以反映新的合约结构

---

✨ **合约目录现在干净整洁，包含了完整的ZK证明验证系统！**