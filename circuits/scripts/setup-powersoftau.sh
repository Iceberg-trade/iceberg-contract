#!/bin/bash

# 创建新的Powers of Tau ceremony
# Create new Powers of Tau ceremony

set -e

echo "🔧 Creating new Powers of Tau ceremony..."

# 获取脚本所在目录的父目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 创建keys目录
mkdir -p keys/powersoftau

# 1. 开始新的Powers of Tau ceremony (支持最多2^12=4096个约束)
echo "🚀 Step 1: Start Powers of Tau ceremony..."
snarkjs powersoftau new bn128 12 keys/powersoftau/pot12_0000.ptau -v

# 2. 贡献第一轮随机性
echo "🎲 Step 2: First contribution..."
echo "test contribution 1" | snarkjs powersoftau contribute keys/powersoftau/pot12_0000.ptau keys/powersoftau/pot12_0001.ptau --name="First contribution" -v

# 3. 贡献第二轮随机性（可选，为了更好的安全性）
echo "🎲 Step 3: Second contribution..."
echo "test contribution 2" | snarkjs powersoftau contribute keys/powersoftau/pot12_0001.ptau keys/powersoftau/pot12_0002.ptau --name="Second contribution" -v

# 4. 进入Phase 2（为特定电路准备）
echo "🔄 Step 4: Prepare Phase 2..."
snarkjs powersoftau prepare phase2 keys/powersoftau/pot12_0002.ptau keys/powersoftau/pot12_final.ptau -v

# 5. 验证Powers of Tau
echo "✅ Step 5: Verify Powers of Tau..."
snarkjs powersoftau verify keys/powersoftau/pot12_final.ptau

# 6. 清理中间文件
echo "🧹 Step 6: Cleanup intermediate files..."
rm -f keys/powersoftau/pot12_0000.ptau keys/powersoftau/pot12_0001.ptau keys/powersoftau/pot12_0002.ptau

echo "🎉 Powers of Tau ceremony completed successfully!"
echo "📁 Generated file: keys/powersoftau/pot12_final.ptau"