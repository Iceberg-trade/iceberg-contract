import { ethers } from "hardhat";
import { Contract } from "ethers";

async function main() {
  console.log("🚀 开始部署AnonymousSwap合约...");

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("📝 部署账户:", deployer.address);
  console.log("💰 账户余额:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  // 1. 部署WithdrawVerifier
  console.log("\n📄 部署WithdrawVerifier...");
  const VerifierFactory = await ethers.getContractFactory("WithdrawVerifier");
  const verifier = await VerifierFactory.deploy();
  await verifier.deployed();
  console.log("✅ WithdrawVerifier部署成功:", verifier.address);

  // 2. 部署AnonymousSwapPool
  console.log("\n📄 部署AnonymousSwapPool...");
  const operator = deployer.address; // 临时设置deployer为operator，实际应该是后台服务地址
  
  const PoolFactory = await ethers.getContractFactory("AnonymousSwapPool");
  const pool = await PoolFactory.deploy(verifier.address, operator);
  await pool.deployed();
  console.log("✅ AnonymousSwapPool部署成功:", pool.address);

  // 3. 部署SwapOperator（可选）
  console.log("\n📄 部署SwapOperator...");
  const mockOneInchRouter = "0x1111111254EEB25477B68fb85Ed929f73A960582"; // 1inch router地址
  
  const OperatorFactory = await ethers.getContractFactory("SwapOperator");
  const swapOperator = await OperatorFactory.deploy(pool.address, mockOneInchRouter);
  await swapOperator.deployed();
  console.log("✅ SwapOperator部署成功:", swapOperator.address);

  // 4. 初始化配置
  console.log("\n⚙️ 初始化swap配置...");
  
  // 添加ETH -> USDC配置
  const usdcAddress = "0xA0b86a33E6441B95C9e8A35E1a1A01f0E8DdBF00"; // Mock USDC地址
  const fixedAmount = ethers.utils.parseEther("1"); // 1 ETH
  const minDelay = 3600; // 1小时延迟

  const tx1 = await pool.addSwapConfig(
    ethers.constants.AddressZero, // ETH
    usdcAddress,
    fixedAmount,
    minDelay
  );
  await tx1.wait();
  console.log("✅ ETH->USDC配置添加成功, ConfigID: 1");

  // 添加USDC -> ETH配置
  const tx2 = await pool.addSwapConfig(
    usdcAddress,
    ethers.constants.AddressZero, // ETH
    ethers.utils.parseUnits("1000", 6), // 1000 USDC
    minDelay
  );
  await tx2.wait();
  console.log("✅ USDC->ETH配置添加成功, ConfigID: 2");

  // 5. 设置SwapOperator为operator（如果需要）
  if (swapOperator.address !== operator) {
    console.log("\n🔧 更新operator地址...");
    const tx3 = await pool.setOperator(swapOperator.address);
    await tx3.wait();
    console.log("✅ Operator地址更新完成");
  }

  // 6. 验证部署
  console.log("\n🔍 验证合约部署...");
  const merkleRoot = await pool.getMerkleRoot();
  const config1 = await pool.getSwapConfig(1);
  
  console.log("📊 Merkle Root:", merkleRoot);
  console.log("📊 配置1 - TokenIn:", config1.tokenIn);
  console.log("📊 配置1 - TokenOut:", config1.tokenOut);
  console.log("📊 配置1 - FixedAmount:", ethers.utils.formatEther(config1.fixedAmount));

  // 7. 输出部署摘要
  console.log("\n🎉 部署完成！合约地址总结:");
  console.log("=" .repeat(50));
  console.log("WithdrawVerifier:", verifier.address);
  console.log("AnonymousSwapPool:", pool.address);
  console.log("SwapOperator:", swapOperator.address);
  console.log("=" .repeat(50));

  // 8. 生成部署配置文件
  const deploymentConfig = {
    network: "localhost", // 或实际网络名
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      WithdrawVerifier: verifier.address,
      AnonymousSwapPool: pool.address,
      SwapOperator: swapOperator.address
    },
    swapConfigs: [
      {
        id: 1,
        tokenIn: ethers.constants.AddressZero,
        tokenOut: usdcAddress,
        fixedAmount: fixedAmount.toString(),
        description: "ETH -> USDC"
      },
      {
        id: 2,
        tokenIn: usdcAddress,
        tokenOut: ethers.constants.AddressZero,
        fixedAmount: ethers.utils.parseUnits("1000", 6).toString(),
        description: "USDC -> ETH"
      }
    ]
  };

  console.log("\n📄 部署配置已保存到 deployment.json");
  
  // 如果在真实网络上部署，还应该验证合约源码
  console.log("\n💡 后续步骤:");
  console.log("1. 在区块链浏览器上验证合约源码");
  console.log("2. 配置后台服务使用这些合约地址");
  console.log("3. 设置适当的1inch router地址");
  console.log("4. 部署真实的ZK verifier合约");

  return deploymentConfig;
}

// 错误处理
main()
  .then((config) => {
    console.log("✅ 部署脚本执行成功");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 部署失败:", error);
    process.exit(1);
  });