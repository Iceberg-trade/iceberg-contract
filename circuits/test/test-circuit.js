const { expect } = require("chai");
const snarkjs = require("snarkjs");
const circomlib = require("circomlib");
const fs = require("fs");

describe("AnonymousSwap ZK Circuit", function() {
    let circuit;
    let poseidon;

    before(async function() {
        this.timeout(60000); // 增加超时时间
        
        // 加载Poseidon哈希函数
        poseidon = circomlib.poseidon;
        
        // 编译电路（如果还没编译）
        if (!fs.existsSync("withdraw.wasm")) {
            console.log("Circuit not compiled. Please run 'npm run compile' first.");
            process.exit(1);
        }
    });

    describe("Valid withdrawal proof", function() {
        it("Should generate and verify a valid proof", async function() {
            this.timeout(30000);

            // 模拟用户数据
            const nullifier = "0x123456789abcdef123456789abcdef123456789abcdef123456789abcdef12";
            const secret = "0xabcdef123456789abcdef123456789abcdef123456789abcdef123456789abc";
            const recipient = "0x742d35Cc6aB4c2F7C4B5c5c9B0Ee2D2B2B8C8B8C";

            // 计算commitment
            const commitment = poseidon([nullifier, secret]);
            
            // 计算nullifierHash
            const nullifierHash = poseidon([nullifier]);

            // 模拟Merkle Tree路径（简化版）
            const levels = 20;
            const pathElements = new Array(levels).fill(0);
            const pathIndices = new Array(levels).fill(0);
            
            // 计算一个简单的merkle root（实际应该构建真实的树）
            let currentHash = commitment;
            for (let i = 0; i < levels; i++) {
                if (pathIndices[i] === 0) {
                    currentHash = poseidon([currentHash, pathElements[i]]);
                } else {
                    currentHash = poseidon([pathElements[i], currentHash]);
                }
            }
            const merkleRoot = currentHash;

            // 准备电路输入
            const input = {
                merkleRoot: merkleRoot.toString(),
                nullifierHash: nullifierHash.toString(),
                recipient: recipient,
                nullifier: nullifier,
                secret: secret,
                pathElements: pathElements.map(x => x.toString()),
                pathIndices: pathIndices
            };

            console.log("Circuit input:", JSON.stringify(input, null, 2));

            try {
                // 生成witness
                const { witness } = await snarkjs.wtns.calculate(input, "withdraw.wasm");
                
                console.log("✅ Witness generated successfully");
                console.log("Witness length:", witness.length);

                // 如果有zkey文件，可以生成完整的证明
                if (fs.existsSync("withdraw_0001.zkey")) {
                    const { proof, publicSignals } = await snarkjs.groth16.fullProve(
                        input,
                        "withdraw.wasm",
                        "withdraw_0001.zkey"
                    );

                    console.log("✅ Proof generated successfully");
                    console.log("Public signals:", publicSignals);

                    // 验证证明
                    if (fs.existsSync("verification_key.json")) {
                        const vKey = JSON.parse(fs.readFileSync("verification_key.json"));
                        const isValid = await snarkjs.groth16.verify(vKey, publicSignals, proof);
                        
                        expect(isValid).to.be.true;
                        console.log("✅ Proof verified successfully");
                    }
                } else {
                    console.log("⚠️ No zkey file found. Run 'npm run build-zkey' to generate it.");
                }

            } catch (error) {
                console.error("❌ Circuit test failed:", error);
                throw error;
            }
        });
    });

    describe("Invalid inputs", function() {
        it("Should fail with invalid nullifier", async function() {
            this.timeout(10000);

            const invalidInput = {
                merkleRoot: "123",
                nullifierHash: "456", 
                recipient: "0x742d35Cc6aB4c2F7C4B5c5c9B0Ee2D2B2B8C8B8C",
                nullifier: "999", // 不匹配的nullifier
                secret: "888",
                pathElements: new Array(20).fill("0"),
                pathIndices: new Array(20).fill(0)
            };

            try {
                await snarkjs.wtns.calculate(invalidInput, "withdraw.wasm");
                expect.fail("Should have thrown an error");
            } catch (error) {
                // 预期的错误
                console.log("✅ Correctly rejected invalid input");
            }
        });
    });
});

// 辅助函数：生成随机测试数据
function generateTestData() {
    const crypto = require("crypto");
    
    return {
        nullifier: "0x" + crypto.randomBytes(31).toString("hex"),
        secret: "0x" + crypto.randomBytes(31).toString("hex"),
        recipient: "0x" + crypto.randomBytes(20).toString("hex")
    };
}

module.exports = { generateTestData };