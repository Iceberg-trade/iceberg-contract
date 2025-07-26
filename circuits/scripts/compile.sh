#!/bin/bash

# 电路编译脚本
# Circuit compilation script

set -e

# 获取脚本所在目录的父目录作为项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔧 Compiling ZK circuits..."
echo "📁 Project root: $PROJECT_ROOT"

# 切换到项目根目录
cd "$PROJECT_ROOT"

# 检查依赖
if ! command -v circom &> /dev/null; then
    echo "❌ Circom not found. Please install it first."
    exit 1
fi

# 确保目录结构存在
mkdir -p build/withdraw_simple build/withdraw

echo "🔄 Step 1: Compiling withdraw_simple circuit..."

if [ -f "src/withdraw_simple.circom" ]; then
    circom src/withdraw_simple.circom --r1cs --wasm --sym -o build/withdraw_simple/
    echo "✅ withdraw_simple compiled successfully"
    echo "   📄 R1CS: build/withdraw_simple/withdraw_simple.r1cs"
    echo "   📄 WASM: build/withdraw_simple/withdraw_simple_js/"
    echo "   📄 SYM:  build/withdraw_simple/withdraw_simple.sym"
else
    echo "❌ src/withdraw_simple.circom not found"
    exit 1
fi

echo ""
echo "🔄 Step 2: Compiling withdraw circuit..."

if [ -f "src/withdraw.circom" ]; then
    circom src/withdraw.circom --r1cs --wasm --sym -o build/withdraw/ -l node_modules
    echo "✅ withdraw compiled successfully"
    echo "   📄 R1CS: build/withdraw/withdraw.r1cs"
    echo "   📄 WASM: build/withdraw/withdraw_js/"
    echo "   📄 SYM:  build/withdraw/withdraw.sym"
else
    echo "❌ src/withdraw.circom not found"
    exit 1
fi

echo ""
echo "📊 Circuit Information:"

echo "📋 withdraw_simple circuit:"
if command -v snarkjs &> /dev/null; then
    snarkjs info -r build/withdraw_simple/withdraw_simple.r1cs
else
    echo "⚠️  snarkjs not available for circuit info"
fi

echo ""
echo "📋 withdraw circuit:"
if command -v snarkjs &> /dev/null; then
    snarkjs info -r build/withdraw/withdraw.r1cs
else
    echo "⚠️  snarkjs not available for circuit info"
fi

echo ""
echo "🎉 All circuits compiled successfully!"
echo ""
echo "📂 Build outputs:"
echo "  📁 build/withdraw_simple/ - Simple withdraw circuit (for testing)"
echo "  📁 build/withdraw/ - Complete withdraw circuit (for production)"
echo ""
echo "🔧 Next step: Run './scripts/setup.sh' to generate proving keys"
echo ""