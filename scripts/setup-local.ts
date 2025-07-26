import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";
const { poseidon1, poseidon2 } = require("poseidon-lite");

/**
 * 本地开发环境设置脚本
 * 用于在本地测试网络上创建测试数据和场景
 */
async function main() {
  console.log("🏗️ 设置本地开发环境...");

  const [deployer, operator, user1, user2, user3] = await ethers.getSigners();

  // 获取最新部署的合约地址
  const poolAddress = "0x59b670e9fA9D0A427751Af201D676719a970857b"; // AnonymousSwapPool地址
  console.log("📍 使用AnonymousSwapPool地址:", poolAddress);
  
  const pool = await ethers.getContractAt("AnonymousSwapPool", poolAddress);

  console.log("📝 使用的账户:");
  console.log("  Deployer:", deployer.address);
  console.log("  Operator:", operator.address);
  console.log("  User1:", user1.address);
  console.log("  User2:", user2.address);
  console.log("  User3:", user3.address);

  // 1. 创建测试commitment
  console.log("\n🔐 生成测试commitment...");
  
  const testCommitments = [
    {
      nullifier: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nullifier_1")),
      secret: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secret_1")),
      user: user1
    },
    {
      nullifier: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nullifier_2")),
      secret: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secret_2")),
      user: user2
    },
    {
      nullifier: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nullifier_3")),
      secret: ethers.utils.keccak256(ethers.utils.toUtf8Bytes("secret_3")),
      user: user3
    }
  ];

  // 计算commitments使用Poseidon哈希
  const commitments = testCommitments.map(item => {
    // commitment = poseidon2(nullifier, secret)
    const commitment = poseidon2([
      ethers.BigNumber.from(item.nullifier).toString(),
      ethers.BigNumber.from(item.secret).toString()
    ]);
    return "0x" + ethers.BigNumber.from(commitment.toString()).toHexString().slice(2).padStart(64, '0');
  });

  console.log("  生成的commitments:", commitments.length);
  console.log("  示例commitment:", commitments[0]);
  console.log("  使用Poseidon哈希: commitment = poseidon2(nullifier, secret)");

  // 2. 执行存款操作
  console.log("\n💰 执行测试存款...");
  const fixedAmount = ethers.utils.parseEther("1");

  for (let i = 0; i < commitments.length; i++) {
    const commitment = commitments[i];
    const user = testCommitments[i].user;
    
    console.log(`  用户${i + 1}存款...`);
    const tx = await pool.connect(user).deposit(commitment, 1, { value: fixedAmount });
    await tx.wait();
    console.log(`  ✅ 存款成功, TxHash: ${tx.hash}`);
  }

  // 3. 检查merkle tree状态
  console.log("\n🌲 检查Merkle Tree状态...");
  const merkleRoot = await pool.getMerkleRoot();
  const commitmentCount = await pool.currentCommitmentIndex();
  
  console.log("  当前Merkle Root:", merkleRoot);
  console.log("  Commitment数量:", commitmentCount.toString());

  // 4. 模拟swap执行
  console.log("\n🔄 模拟Swap执行...");
  
  // 计算nullifierHashes使用Poseidon哈希
  const nullifierHashes = testCommitments.map(item => {
    // nullifierHash = poseidon1(nullifier)
    const nullifierHash = poseidon1([ethers.BigNumber.from(item.nullifier).toString()]);
    return "0x" + ethers.BigNumber.from(nullifierHash.toString()).toHexString().slice(2).padStart(64, '0');
  });

  console.log("  生成的nullifierHashes:", nullifierHashes.length);
  console.log("  示例nullifierHash:", nullifierHashes[0]);
  console.log("  使用Poseidon哈希: nullifierHash = poseidon1(nullifier)");

  for (let i = 0; i < nullifierHashes.length; i++) {
    const nullifierHash = nullifierHashes[i];
    const swapOutput = ethers.utils.parseEther((0.95 + i * 0.01).toString()); // 模拟不同的swap输出
    
    console.log(`  执行Swap ${i + 1}...`);
    const tx = await pool.connect(deployer).recordSwapResult(nullifierHash, swapOutput); // 使用deployer作为operator
    await tx.wait();
    console.log(`  ✅ Swap记录成功, 输出: ${ethers.utils.formatEther(swapOutput)} ETH`);
  }

  // 5. 生成测试数据文件
  console.log("\n📄 生成测试数据文件...");
  
  const testData = {
    contracts: {
      pool: poolAddress
    },
    accounts: {
      deployer: deployer.address,
      operator: operator.address,
      users: [user1.address, user2.address, user3.address]
    },
    testCommitments: testCommitments.map((item, index) => ({
      index,
      nullifier: item.nullifier,
      secret: item.secret,
      commitment: commitments[index],
      nullifierHash: nullifierHashes[index],
      userAddress: item.user.address
    })),
    merkleTree: {
      root: merkleRoot,
      leafCount: commitmentCount.toNumber()
    },
    swapConfigs: [
      {
        id: 1,
        tokenIn: ethers.constants.AddressZero,
        fixedAmount: fixedAmount.toString(),
        description: "ETH -> Token"
      }
    ]
  };

  console.log("✅ 测试数据已生成");

  // 6. 展示可用的测试场景
  console.log("\n🎮 可用的测试场景:");
  console.log("=" .repeat(50));
  console.log("1. 用户存款 - 已完成");
  console.log("2. Operator执行swap - 已完成");
  console.log("3. 用户提取（需要ZK证明）- 待实现");
  console.log("4. 添加新的swap配置 - 可测试");
  console.log("5. 紧急提取功能 - 可测试");

  console.log("\n💡 下一步测试建议:");
  console.log("- 使用不同地址测试withdraw功能");
  console.log("- 测试无效证明的拒绝");
  console.log("- 测试重复使用nullifier的防护");
  console.log("- 测试权限控制功能");

  return testData;
}

main()
  .then(() => {
    console.log("✅ 本地环境设置完成");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 设置失败:", error);
    process.exit(1);
  });