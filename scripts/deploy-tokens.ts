/**
 * Copyright (c) 2025 Iceberg.trade. All rights reserved.
 * 
 * This software is proprietary and confidential. Unauthorized copying,
 * distribution, or use is strictly prohibited.
 */

import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

async function main() {
  console.log("🪙 开始部署测试代币...");

  // 获取部署者账户
  const [deployer] = await ethers.getSigners();
  console.log("📝 部署账户:", deployer.address);
  console.log("💰 账户余额:", ethers.utils.formatEther(await deployer.getBalance()), "ETH");

  console.log("\n📄 部署测试代币...");

  // 获取TestToken合约工厂
  const TestTokenFactory = await ethers.getContractFactory("TestToken");
  
  // 部署MockUSDC (6位小数)
  const mockUSDC = await TestTokenFactory.deploy(
    "Mock USDC", 
    "USDC", 
    6, 
    ethers.utils.parseUnits("1000000", 6)
  );
  await mockUSDC.deployed();
  console.log("✅ MockUSDC部署成功:", mockUSDC.address);

  // 部署MockUSDT (6位小数)
  const mockUSDT = await TestTokenFactory.deploy(
    "Mock USDT", 
    "USDT", 
    6, 
    ethers.utils.parseUnits("1000000", 6)
  );
  await mockUSDT.deployed();
  console.log("✅ MockUSDT部署成功:", mockUSDT.address);

  // 部署MockDAI (18位小数)
  const mockDAI = await TestTokenFactory.deploy(
    "Mock DAI", 
    "DAI", 
    18, 
    ethers.utils.parseEther("1000000")
  );
  await mockDAI.deployed();
  console.log("✅ MockDAI部署成功:", mockDAI.address);

  // 4. 创建配置文件
  const tokenConfig = {
    network: "localhost",
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    tokens: {
      USDC: {
        address: mockUSDC.address,
        symbol: "USDC",
        decimals: 6,
        name: "Mock USDC"
      },
      USDT: {
        address: mockUSDT.address,
        symbol: "USDT",
        decimals: 6,
        name: "Mock USDT"
      },
      DAI: {
        address: mockDAI.address,
        symbol: "DAI",
        decimals: 18,
        name: "Mock DAI"
      }
    }
  };

  // 5. 保存配置到文件
  const configPath = path.join(__dirname, "../deployment-tokens.json");
  fs.writeFileSync(configPath, JSON.stringify(tokenConfig, null, 2));
  console.log("\n📄 代币配置已保存到:", configPath);
  
  // 6. 输出地址供复制使用
  console.log("\n📋 代币地址 (复制到其他脚本使用):");
  console.log(`USDC: "${mockUSDC.address}"`);
  console.log(`USDT: "${mockUSDT.address}"`);
  console.log(`DAI: "${mockDAI.address}"`);
  console.log("\n💡 现在可以将这些地址复制到 deploy.ts 和 setup-local.ts 中");

  // 6. 给一些测试账户mint代币用于测试
  console.log("\n🪙 为测试账户分发代币...");
  const signers = await ethers.getSigners();
  const testAccounts = signers.slice(1, 5); // 取前4个测试账户

  for (let i = 0; i < testAccounts.length; i++) {
    const account = testAccounts[i];
    console.log(`  给账户 ${account.address} 分发代币...`);
    
    // 给每个账户分发10000个代币
    await mockUSDC.mint(account.address, ethers.utils.parseUnits("10000", 6));
    await mockUSDT.mint(account.address, ethers.utils.parseUnits("10000", 6));
    await mockDAI.mint(account.address, ethers.utils.parseEther("10000"));
    
    console.log(`  ✅ 账户 ${i + 1} 获得 10,000 USDC/USDT/DAI`);
  }

  // 7. 输出摘要
  console.log("\n🎉 代币部署完成！地址总结:");
  console.log("=" .repeat(50));
  console.log("MockUSDC:", mockUSDC.address);
  console.log("MockUSDT:", mockUSDT.address);
  console.log("MockDAI:", mockDAI.address);
  console.log("=" .repeat(50));

  console.log("\n💡 下一步:");
  console.log("1. 运行 npm run deploy:local 部署主合约");
  console.log("2. USDC地址已自动配置到部署脚本中");
  console.log("3. 测试账户已获得代币，可以直接开始测试");

  return tokenConfig;
}

// 错误处理
main()
  .then((config) => {
    console.log("✅ 代币部署脚本执行成功");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 代币部署失败:", error);
    process.exit(1);
  });