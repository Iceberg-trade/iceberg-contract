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
mkdir -p keys/powersoftau keys/withdraw_simple keys/withdraw_basic_fixed
mkdir -p build/withdraw_simple build/withdraw_basic_fixed
mkdir -p proofs/examples proofs/witnesses

echo "📦 Step 1: Powers of Tau ceremony..."

# 使用我们生成的Powers of Tau文件
if [ ! -f "keys/powersoftau/pot12_final.ptau" ]; then
    echo "❌ Powers of Tau not found. Please run ./scripts/setup-powersoftau.sh first"
    exit 1
fi

echo "✅ Using our generated Powers of Tau: keys/powersoftau/pot12_final.ptau"

echo "🔧 Step 2: Generating proving keys for circuits..."

# 为withdraw_simple电路生成密钥
if [ -f "build/withdraw_simple/withdraw_simple.r1cs" ]; then
    echo "🔑 Processing withdraw_simple circuit..."
    
    # 生成zkey文件
    snarkjs groth16 setup build/withdraw_simple/withdraw_simple.r1cs keys/powersoftau/pot12_final.ptau keys/withdraw_simple/withdraw_simple_0000.zkey
    
    # 贡献随机性（生产环境需要多方参与）
    echo "test random entropy" | snarkjs zkey contribute keys/withdraw_simple/withdraw_simple_0000.zkey keys/withdraw_simple/withdraw_simple_0001.zkey --name="First contribution"
    
    # 导出验证密钥
    snarkjs zkey export verificationkey keys/withdraw_simple/withdraw_simple_0001.zkey keys/withdraw_simple/withdraw_simple_verification_key.json
    
    # 生成Solidity验证合约
    snarkjs zkey export solidityverifier keys/withdraw_simple/withdraw_simple_0001.zkey ../contracts/WithdrawSimpleVerifier.sol
    
    echo "✅ withdraw_simple keys generated"
fi

# 为withdraw_basic_fixed电路生成密钥
if [ -f "build/withdraw_basic_fixed/withdraw_basic_fixed.r1cs" ]; then
    echo "🔑 Processing withdraw_basic_fixed circuit..."
    
    # 生成zkey文件
    snarkjs groth16 setup build/withdraw_basic_fixed/withdraw_basic_fixed.r1cs keys/powersoftau/pot12_final.ptau keys/withdraw_basic_fixed/withdraw_basic_fixed_0000.zkey
    
    # 贡献随机性
    echo "test random entropy basic fixed" | snarkjs zkey contribute keys/withdraw_basic_fixed/withdraw_basic_fixed_0000.zkey keys/withdraw_basic_fixed/withdraw_basic_fixed_0001.zkey --name="First contribution"
    
    # 导出验证密钥
    snarkjs zkey export verificationkey keys/withdraw_basic_fixed/withdraw_basic_fixed_0001.zkey keys/withdraw_basic_fixed/withdraw_basic_fixed_verification_key.json
    
    # 生成Solidity验证合约
    snarkjs zkey export solidityverifier keys/withdraw_basic_fixed/withdraw_basic_fixed_0001.zkey ../contracts/WithdrawBasicFixedVerifier.sol
    
    echo "✅ withdraw_basic_fixed keys generated"
fi

echo "🎯 Step 3: Testing proof generation..."

# 测试simple电路的完整证明流程
if [ -f "keys/withdraw_simple/withdraw_simple_0001.zkey" ] && [ -f "proofs/inputs/input_simple_correct.json" ]; then
    echo "🧪 Testing withdraw_simple proof generation..."
    
    # 生成见证
    snarkjs wtns calculate build/withdraw_simple/withdraw_simple_js/withdraw_simple.wasm proofs/inputs/input_simple_correct.json proofs/witnesses/witness_simple_test.wtns
    
    # 生成证明
    snarkjs groth16 prove keys/withdraw_simple/withdraw_simple_0001.zkey proofs/witnesses/witness_simple_test.wtns proofs/examples/proof_simple.json proofs/examples/public_simple.json
    
    # 验证证明
    snarkjs groth16 verify keys/withdraw_simple/withdraw_simple_verification_key.json proofs/examples/public_simple.json proofs/examples/proof_simple.json
    
    echo "✅ withdraw_simple proof verification successful!"
fi

# 测试basic_fixed电路的完整证明流程
if [ -f "keys/withdraw_basic_fixed/withdraw_basic_fixed_0001.zkey" ] && [ -f "proofs/inputs/input_poseidon_correct.json" ]; then
    echo "🧪 Testing withdraw_basic_fixed proof generation..."
    
    # 生成见证
    snarkjs wtns calculate build/withdraw_basic_fixed/withdraw_basic_fixed_js/withdraw_basic_fixed.wasm proofs/inputs/input_poseidon_correct.json proofs/witnesses/witness_basic_fixed_test.wtns
    
    # 如果见证生成成功，继续生成证明
    if [ -f "proofs/witnesses/witness_basic_fixed_test.wtns" ]; then
        snarkjs groth16 prove keys/withdraw_basic_fixed/withdraw_basic_fixed_0001.zkey proofs/witnesses/witness_basic_fixed_test.wtns proofs/examples/proof_basic_fixed.json proofs/examples/public_basic_fixed.json
        snarkjs groth16 verify keys/withdraw_basic_fixed/withdraw_basic_fixed_verification_key.json proofs/examples/public_basic_fixed.json proofs/examples/proof_basic_fixed.json
        echo "✅ withdraw_basic_fixed proof verification successful!"
    else
        echo "⚠️  withdraw_basic_fixed witness generation failed"
    fi
fi

echo ""
echo "🎉 ZK proof system setup complete!"
echo ""
echo "📂 Generated files:"
echo "  📁 keys/ - Contains zkey files and verification keys"
echo "  📁 contracts/ - Contains Solidity verifier contracts"
echo "  📁 proofs/examples/ - Example proofs"
echo "  📁 proofs/witnesses/ - Generated witnesses"
echo ""
echo "🔧 Next steps:"
echo "  1. Update smart contracts to use generated verifiers"
echo "  2. Integrate proof generation into your application"
echo "  3. Test end-to-end functionality"
echo ""