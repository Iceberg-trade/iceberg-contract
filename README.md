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
├── contracts/                    # Solidity合约
│   ├── AnonymousSwapPool.sol    # 主资金池合约
│   ├── MerkleTree.sol           # Merkle树实现
│   ├── WithdrawVerifier.sol     # ZK证明验证器(自动生成)
│   ├── WithdrawVerifierAdapter.sol  # 接口适配器
│   ├── ZKProofIntegration.sol   # ZK证明集成测试
│   ├── IWithdrawVerifier.sol    # 验证器接口
│   └── SwapOperator.sol         # Swap执行器
├── circuits/                    # ZK电路系统
│   ├── src/
│   │   └── withdraw.circom      # 生产级withdraw电路
│   ├── scripts/
│   │   ├── compile.sh           # 电路编译脚本
│   │   ├── setup.sh             # 密钥生成脚本
│   │   └── generate-withdraw-data.js  # 测试数据生成
│   ├── build/                   # 编译产物(gitignore)
│   ├── keys/                    # 证明密钥(gitignore)
│   └── proofs/                  # 测试证明数据
├── test/                        # 测试文件
│   ├── ZKProof.test.js         # ZK证明集成测试
│   ├── AnonymousSwapPool.test.ts # 匿名交换池测试
│   └── MerkleTree.test.ts      # Merkle树测试
├── scripts/                     # 部署和设置脚本
│   ├── deploy.ts
│   └── setup-local.ts
└── docs/                        # 文档
```

## 🧪 测试

### 完整测试流程

项目包含27个测试用例，涵盖ZK电路、合约功能和系统集成：

```bash
# 清理所有中间产物 (推荐每次测试前执行)
rm -rf artifacts/ cache/ typechain-types/
cd circuits && rm -rf build/ keys/withdraw/ proofs/proof_*.json proofs/public_*.json proofs/witnesses/
cd ..

# 安装依赖
npm install

# 编译合约
npx hardhat compile

# 运行完整测试套件 (27个测试)
npx hardhat test

# 单独测试ZK证明功能 (4个测试)
npx hardhat test test/ZKProof.test.js

# 单独测试匿名交换池 (12个测试)
npx hardhat test test/AnonymousSwapPool.test.ts

# 单独测试Merkle树 (11个测试)
npx hardhat test test/MerkleTree.test.ts
```

### ZK电路测试

首次运行需要编译电路和生成证明密钥：

```bash
cd circuits

# 1. 编译withdraw电路
./scripts/compile.sh

# 2. 生成Proving Keys (需要几分钟)
./scripts/setup.sh

# 3. 生成测试数据
node scripts/generate-withdraw-data.js

# 返回项目根目录测试
cd ..
npx hardhat test test/ZKProof.test.js
```

### 测试覆盖的功能

**ZKProof.test.js (4个测试)**
- ✅ ZK证明验证
- ✅ 双花防护 (nullifier防重放)  
- ✅ Nullifier使用状态跟踪
- ✅ 事件发送验证

**AnonymousSwapPool.test.ts (12个测试)**
- ✅ 合约部署和初始化
- ✅ Swap配置管理
- ✅ 存款功能和Merkle树更新
- ✅ Swap执行和权限控制
- ✅ 使用真实ZK验证器 (提取功能在ZKProof.test.js中测试)

**MerkleTree.test.ts (11个测试)**
- ✅ Merkle树初始化
- ✅ Poseidon哈希计算
- ✅ Merkle证明生成和验证
- ✅ 树操作和常量验证

### 测试输出示例

```
  ZK Proof Integration
    ✔ Should verify withdraw proof
    ✔ Should prevent double spending
    ✔ Should check nullifier usage status
    ✔ Should emit withdrawal authorized event

  AnonymousSwapPool
    ✔ Should set the correct verifier
    ✔ Should accept valid ETH deposit
    ✔ Should not allow duplicate swap recording
    ... (9 more tests)

  MerkleTree
    ✔ Should initialize with correct parameters
    ✔ Should compute hash correctly
    ✔ Should verify merkle proofs correctly
    ... (8 more tests)

  27 passing (886ms)
```

### 故障排除

**电路编译失败:**
```bash
# 确保安装了正确版本的circom
cargo install --git https://github.com/iden3/circom.git circom
circom --version  # 应该显示 2.2.2 或更高版本
```

**Powers of Tau错误:**
```bash
# 确保pot13_final.ptau存在
ls -la circuits/keys/powersoftau/pot13_final.ptau
# 如果不存在，运行Powers of Tau设置
cd circuits && ./scripts/setup-powersoftau.sh
```

**测试失败:**
```bash
# 清理并重新编译
rm -rf artifacts/ cache/ typechain-types/
cd circuits && rm -rf build/ keys/withdraw/
./scripts/compile.sh && ./scripts/setup.sh
cd .. && npx hardhat test
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

## 🔐 ZK电路系统

项目使用**Circom 2.0**和**snarkjs**实现零知识证明电路。

### 环境要求

- **Circom 2.2.2+**: `cargo install --git https://github.com/iden3/circom.git circom`
- **snarkjs**: `npm install -g snarkjs`  
- **Node.js 16+**

### 电路编译和设置

```bash
cd circuits

# 1. 编译电路 (生成 R1CS, WASM, SYM)
./scripts/compile.sh

# 2. 生成Proving Keys和验证器合约 (需要几分钟)
./scripts/setup.sh

# 3. 生成测试数据和证明
node scripts/generate-withdraw-data.js
```

### 电路信息

- **电路类型**: `withdraw` (生产级完整功能)
- **约束数量**: 4,207 non-linear constraints  
- **Merkle Tree**: 5层 (支持32个叶子节点)
- **哈希函数**: Poseidon (来自circomlib)
- **Powers of Tau**: 需要 `pot13_final.ptau` (支持2^13=8192约束)

### 生成的文件

```
circuits/
├── build/withdraw/          # 编译产物
│   ├── withdraw.r1cs       # 约束系统
│   ├── withdraw.sym        # 符号表
│   └── withdraw_js/        # WASM见证生成器
├── keys/withdraw/           # 证明密钥
│   ├── withdraw_0001.zkey  # 最终proving key
│   └── withdraw_verification_key.json
└── proofs/                  # 测试证明数据
    ├── proof_withdraw_final.json
    └── public_withdraw_final.json
```

### 验证电路功能

完成电路编译和密钥生成后，可以验证电路正常工作：

```bash
# 返回项目根目录
cd ..

# 测试ZK证明集成 (验证电路与合约的集成)
npx hardhat test test/ZKProof.test.js

# 测试完整系统 (包含电路、合约、Merkle树)
npx hardhat test

# 查看生成的证明文件
cat circuits/proofs/proof_withdraw_final.json
cat circuits/proofs/public_withdraw_final.json
```

**电路测试验证内容:**
- ✅ 真实ZK证明的生成和验证
- ✅ Poseidon哈希在电路中的正确性
- ✅ Merkle Tree路径验证
- ✅ Nullifier防重放机制
- ✅ 公开信号的正确传递

## 🚧 开发状态

- ✅ 核心合约实现
- ✅ 完整测试覆盖 (27个测试用例)
- ✅ 本地部署脚本
- ✅ 生产级ZK电路 (withdraw circuit)
- ✅ Groth16证明系统完整集成
- ✅ Poseidon哈希和Merkle Tree验证
- ✅ Nullifier防重放机制
- 🚧 后台服务实现
- 🚧 前端钱包集成
- ⏳ 1inch真实集成
- ⏳ 主网部署

### 电路详细状态
- ✅ withdraw.circom - 生产级完整电路
- ✅ Poseidon哈希集成 (circomlib)
- ✅ 5层Merkle Tree验证
- ✅ Nullifier hash防双花
- ✅ Groth16证明生成和验证
- ✅ Solidity验证器合约生成

## 📄 许可证

专有软件许可证 - 版权所有 © 2025 Iceberg.trade

本软件受专有许可证保护。未经Iceberg.trade明确书面许可，禁止复制、修改、分发或以任何形式使用本软件。详细条款请参阅LICENSE文件。

## 🤝 贡献

欢迎提交Issue和Pull Request！