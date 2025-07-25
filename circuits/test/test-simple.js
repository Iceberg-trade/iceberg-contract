const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");

async function testSimpleCircuit() {
    console.log("🧪 Testing simple withdraw circuit...");

    try {
        // 1. 编译电路
        console.log("📝 Compiling circuit...");
        const { exec } = require("child_process");
        
        await new Promise((resolve, reject) => {
            exec("circom withdraw_simple.circom --r1cs --wasm --sym", 
                { cwd: path.join(__dirname, "..") }, 
                (error, stdout, stderr) => {
                    if (error) {
                        console.error("Compilation error:", error);
                        reject(error);
                    } else {
                        console.log("✅ Circuit compiled successfully");
                        resolve();
                    }
                }
            );
        });

        // 2. 准备测试输入
        const nullifier = 123;
        const secret = 456;
        const nullifierHash = nullifier * nullifier; // 简化的hash
        const recipient = 789;

        const input = {
            nullifier: nullifier,
            secret: secret,
            nullifierHash: nullifierHash,
            recipient: recipient
        };

        console.log("📊 Test input:", input);

        // 3. 生成witness
        console.log("🔄 Generating witness...");
        const { witness } = await snarkjs.wtns.calculate(
            input, 
            path.join(__dirname, "..", "withdraw_simple.wasm")
        );

        console.log("✅ Witness generated successfully!");
        console.log("📏 Witness length:", witness.length);

        // 4. 验证witness的输出
        const output = witness[1]; // 第一个输出信号
        console.log("📤 Circuit output (isValid):", output.toString());

        if (output.toString() === "1") {
            console.log("🎉 Circuit test PASSED!");
            return true;
        } else {
            console.log("❌ Circuit test FAILED!");
            return false;
        }

    } catch (error) {
        console.error("💥 Test failed with error:", error);
        return false;
    }
}

// 运行测试
if (require.main === module) {
    testSimpleCircuit().then(success => {
        process.exit(success ? 0 : 1);
    });
}

module.exports = { testSimpleCircuit };