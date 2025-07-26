#!/bin/bash

# 完整的ZK证明系统设置脚本 - 适配新目录结构
# Complete ZK proof system setup script - adapted for new directory structure

set -e

# 获取脚本所在目录的父目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🚀 Setting up complete ZK proof system..."
echo "📁 Project root: $PROJECT_ROOT"

# 检查依赖
if ! command -v circom &> /dev/null; then
    echo "❌ Circom not found. Please install it first."
    exit 1
fi

if ! command -v snarkjs &> /dev/null; then
    echo "❌ snarkjs not found. Please install it first."
    exit 1
fi

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 确保目录结构存在
mkdir -p keys/powersoftau keys/withdraw
mkdir -p build/withdraw
mkdir -p proofs/examples proofs/witnesses

echo "📦 Step 1: Powers of Tau ceremony..."

# 检查电路复杂度，选择合适的Powers of Tau文件
CIRCUIT_SIZE=4207  # withdraw circuit has 4207 constraints
POT_FILE="pot13_final.ptau"  # pot13 supports 2^13 = 8192 constraints

if [ ! -f "keys/powersoftau/$POT_FILE" ]; then
    echo "❌ Powers of Tau ($POT_FILE) not found. Circuit needs 2^13 or higher."
    echo "   Available files:"
    ls -la keys/powersoftau/
    echo "   Please ensure pot13_final.ptau exists for circuit with $CIRCUIT_SIZE constraints"
    exit 1
fi

echo "✅ Using Powers of Tau: keys/powersoftau/$POT_FILE (for circuit with $CIRCUIT_SIZE constraints)"

echo "🔧 Step 2: Generating proving keys for circuits..."

# 为withdraw电路生成密钥
if [ -f "build/withdraw/withdraw.r1cs" ]; then
    echo "🔑 Processing withdraw circuit..."
    
    # 生成zkey文件
    snarkjs groth16 setup build/withdraw/withdraw.r1cs keys/powersoftau/$POT_FILE keys/withdraw/withdraw_0000.zkey
    
    # 贡献随机性（生产环境需要多方参与）
    echo "test random entropy for withdraw circuit" | snarkjs zkey contribute keys/withdraw/withdraw_0000.zkey keys/withdraw/withdraw_0001.zkey --name="First contribution"
    
    # 导出验证密钥
    snarkjs zkey export verificationkey keys/withdraw/withdraw_0001.zkey keys/withdraw/withdraw_verification_key.json
    
    # 生成Solidity验证合约
    snarkjs zkey export solidityverifier keys/withdraw/withdraw_0001.zkey ../contracts/WithdrawVerifier.sol
    
    echo "✅ withdraw circuit keys generated"
else
    echo "❌ withdraw.r1cs not found. Please compile circuit first."
    exit 1
fi

echo "🎯 Step 3: Testing proof generation..."

# 测试withdraw电路的完整证明流程
if [ -f "keys/withdraw/withdraw_0001.zkey" ] && [ -f "proofs/inputs/input_basic_fixed_complete.json" ]; then
    echo "🧪 Testing withdraw circuit proof generation..."
    
    # 生成见证
    snarkjs wtns calculate build/withdraw/withdraw_js/withdraw.wasm proofs/inputs/input_basic_fixed_complete.json proofs/witnesses/witness_withdraw_final.wtns
    
    # 生成证明
    snarkjs groth16 prove keys/withdraw/withdraw_0001.zkey proofs/witnesses/witness_withdraw_final.wtns proofs/proof_withdraw_final.json proofs/public_withdraw_final.json
    
    # 验证证明
    snarkjs groth16 verify keys/withdraw/withdraw_verification_key.json proofs/public_withdraw_final.json proofs/proof_withdraw_final.json
    
    echo "✅ withdraw circuit proof verification successful!"
else
    echo "⚠️  Missing files for withdraw circuit testing:"
    echo "     - Proving key: keys/withdraw/withdraw_0001.zkey"
    echo "     - Input file: proofs/inputs/input_basic_fixed_complete.json"
fi

echo ""
echo "🎉 ZK proof system setup complete!"
echo ""
echo "📂 Generated files:"
echo "  📁 keys/withdraw/ - Contains withdraw circuit zkey files and verification keys"
echo "  📁 ../contracts/WithdrawVerifier.sol - Solidity verifier contract"
echo "  📁 proofs/ - Contains example proofs and witnesses"
echo ""
echo "🔧 Next steps:"
echo "  1. Test circuit functionality: Run 'npx hardhat test test/ZKProof.test.js'"
echo "  2. Test contract integration: Run 'npx hardhat test'"
echo "  3. Deploy contracts for production use"
echo ""