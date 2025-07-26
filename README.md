# 🧊 Iceberg Contract - Anonymous Swap Protocol

一个基于零知识证明的隐私swap协议，允许用户使用不同地址进行deposit和withdraw，实现真正的匿名交易。

## 🚀 功能特性

- **隐私保护**: 基于Tornado Cash的Merkle Tree + ZK证明设计
- **地址分离**: 用户使用address1存入tokenA，使用address2提取tokenB
- **批量处理**: 后台服务批量执行swap，降低gas成本和提高隐私
- **固定面额**: 支持多个固定面额池子，提高匿名集大小
- **1inch集成**: 使用1inch协议获得最优swap价格

## 📋 系统架构

```
用户(address1) → Pool合约 → MerkleTree → ZK电路验证 → 后台服务 → 1inch → 用户(address2)
```

### 核心组件

1. **AnonymousSwapPool.sol**: 主要资金池合约
2. **MerkleTree.sol**: Merkle树实现，记录所有commitments
3. **WithdrawVerifier.sol**: ZK证明验证器
4. **SwapOperator.sol**: 后台服务合约，负责执行1inch swap

## 🛠️ 安装和部署

### 环境要求

- Node.js >= 16
- npm >= 8
- Hardhat

### 安装依赖

```bash
npm install
```

### 编译合约

```bash
npm run build
```

### 运行测试

```bash
npm run test
```

### 本地部署

```bash
# 启动本地节点
npm run node

# 在另一个终端部署合约
npm run deploy:local

# 设置测试环境
npm run setup:local
```

## 🔄 用户流程

### 1. Deposit阶段

用户在address1执行存款：

```javascript
const nullifier = randomBytes(31);
const secret = randomBytes(31); 
const commitment = poseidon([nullifier, secret]);

await pool.deposit(commitment, swapConfigId, {value: ethers.parseEther("1")});
```

### 2. 提交Swap意图

用户向后台服务提交swap请求：

```javascript
const nullifierHash = poseidon([nullifier]);
const signature = await signer.signMessage(nullifierHash);

await fetch('/api/v1/swap/intent', {
  method: 'POST',
  body: JSON.stringify({
    nullifierHash: nullifierHash.toString(),
    signature,
    swapConfigId: 1,
    expectedMinOutput: "950000000000000000"
  })
});
```

### 3. Withdraw阶段

用户切换到address2执行提取：

```javascript
const proof = await generateProof({
  merkleRoot,
  nullifier, 
  secret,
  pathElements,
  pathIndices,
  recipient: address2
});

await pool.withdraw(nullifierHash, address2, proof);
```

## 🔐 安全特性

- **重放攻击防护**: nullifierHash只能使用一次
- **时序分析防护**: 强制延迟+批量处理打乱时序关联  
- **金额分析防护**: 固定面额池子，避免金额特征关联
- **地址关联防护**: 强制使用不同地址deposit/withdraw
- **MEV防护**: 后台服务统一调用，避免抢跑

## 📁 项目结构

```
├── contracts/              # Solidity合约
│   ├── AnonymousSwapPool.sol
│   ├── MerkleTree.sol
│   ├── WithdrawVerifier.sol
│   └── SwapOperator.sol
├── circuits/               # ZK电路文件
│   ├── withdraw.circom
│   ├── merkleTree.circom
│   └── poseidon.circom
├── test/                   # 测试文件
├── scripts/                # 部署脚本
└── typechain/             # 类型定义(自动生成)
```

## 🧪 测试

运行完整测试套件：

```bash
npm run test
```

运行测试覆盖率：

```bash
npm run test:coverage
```

## 📚 API文档

### 合约接口

#### AnonymousSwapPool

- `deposit(bytes32 commitment, uint256 swapConfigId)`: 用户存款
- `executeSwap(bytes32 nullifierHash, uint256 amountOut)`: 执行swap（仅operator）
- `withdraw(bytes32 nullifierHash, address recipient, uint256[8] proof)`: 用户提取

#### SwapOperator

- `executeSingleSwap(bytes32 nullifierHash, uint256 swapConfigId, bytes oneInchData)`: 执行单个swap
- `executeBatchSwap(...)`: 批量执行swap

### 后台服务API

- `POST /api/v1/swap/intent`: 提交swap意图
- `GET /api/v1/swap/status/{nullifierHash}`: 查询swap状态
- `GET /api/v1/merkle/proof/{commitment}`: 获取merkle proof

## 🔐 ZK电路

项目使用**Circom**来实现零知识证明电路：

### 快速测试ZK电路

```bash
cd circuits
npm install
node test/test-simple.js
```

### 完整电路编译

```bash
cd circuits

# 编译电路
npm run compile

# 生成证明密钥（需要几分钟）
npm run build-zkey

# 生成Solidity验证器
npm run generate-verifier
```

详细说明请查看 [circuits/README.md](circuits/README.md)

## 🚧 开发状态

- ✅ 核心合约实现
- ✅ 基础测试覆盖  
- ✅ 本地部署脚本
- ✅ Circom ZK电路框架
- 🚧 完整ZK电路集成
- 🚧 后台服务实现
- 🚧 前端钱包集成
- ⏳ 1inch真实集成
- ⏳ 主网部署

## 📄 许可证

专有软件许可证 - 版权所有 © 2025 Iceberg.trade

本软件受专有许可证保护。未经Iceberg.trade明确书面许可，禁止复制、修改、分发或以任何形式使用本软件。详细条款请参阅LICENSE文件。

## 🤝 贡献

欢迎提交Issue和Pull Request！