const fs = require('fs');
const path = require('path');

// 更新智能合约以使用真实的ZK证明
function updateContracts() {
    console.log('🔄 Updating smart contracts to use ZK proof verifiers...');
    
    // 获取项目根目录
    const projectRoot = path.dirname(__dirname);
    
    // 1. 验证合约已经直接生成到主合约目录
    const contractsPath = path.join(projectRoot, '..', 'contracts');
    
    // 验证合约已经直接生成到主合约目录
    try {
        if (!fs.existsSync(contractsPath)) {
            console.log(`❌ Main contracts directory not found: ${contractsPath}`);
            return;
        }
        
        // 检查验证合约是否存在
        const simpleVerifier = path.join(contractsPath, 'WithdrawSimpleVerifier.sol');
        const basicVerifier = path.join(contractsPath, 'WithdrawBasicFixedVerifier.sol');
        
        if (fs.existsSync(simpleVerifier)) {
            console.log(`✅ Found WithdrawSimpleVerifier.sol in main contracts directory`);
        }
        if (fs.existsSync(basicVerifier)) {
            console.log(`✅ Found WithdrawBasicFixedVerifier.sol in main contracts directory`);
        }
        
        // 2. 创建一个ZK证明集成合约
        const zkIntegrationContract = `// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./WithdrawSimpleVerifier.sol";
import "./WithdrawBasicFixedVerifier.sol";

/**
 * @title ZKProofIntegration
 * @dev 集成ZK证明验证的合约
 */
contract ZKProofIntegration {
    Groth16Verifier public simpleVerifier;
    Groth16Verifier public basicVerifier;
    
    mapping(bytes32 => bool) public nullifierHashUsed;
    
    event ProofVerified(address indexed user, bytes32 nullifierHash, uint256 timestamp);
    event WithdrawalAuthorized(address indexed user, bytes32 nullifierHash, uint256 amount);
    
    constructor(address _simpleVerifier, address _basicVerifier) {
        simpleVerifier = Groth16Verifier(_simpleVerifier);
        basicVerifier = Groth16Verifier(_basicVerifier);
    }
    
    /**
     * @dev 验证简单withdraw证明
     * @param proof ZK证明数据
     * @param publicSignals 公开信号 [nullifierHash, recipient]
     */
    function verifySimpleWithdraw(
        uint[2] memory _pA,
        uint[2][2] memory _pB,
        uint[2] memory _pC,
        uint[2] memory publicSignals
    ) external returns (bool) {
        bytes32 nullifierHash = bytes32(publicSignals[0]);
        require(!nullifierHashUsed[nullifierHash], "Nullifier already used");
        
        // 验证ZK证明
        bool isValid = simpleVerifier.verifyProof(_pA, _pB, _pC, publicSignals);
        require(isValid, "Invalid ZK proof");
        
        // 标记nullifier已使用
        nullifierHashUsed[nullifierHash] = true;
        
        emit ProofVerified(msg.sender, nullifierHash, block.timestamp);
        return true;
    }
    
    /**
     * @dev 验证基础withdraw证明
     * @param proof ZK证明数据
     * @param publicSignals 公开信号 [nullifierHash, recipient]
     */
    function verifyBasicWithdraw(
        uint[2] memory _pA,
        uint[2][2] memory _pB,
        uint[2] memory _pC,
        uint[2] memory publicSignals
    ) external returns (bool) {
        bytes32 nullifierHash = bytes32(publicSignals[0]);
        require(!nullifierHashUsed[nullifierHash], "Nullifier already used");
        
        // 验证ZK证明
        bool isValid = basicVerifier.verifyProof(_pA, _pB, _pC, publicSignals);
        require(isValid, "Invalid ZK proof");
        
        // 标记nullifier已使用
        nullifierHashUsed[nullifierHash] = true;
        
        emit ProofVerified(msg.sender, nullifierHash, block.timestamp);
        return true;
    }
    
    /**
     * @dev 更新验证器地址（仅用于测试）
     */
    function updateVerifiers(address _simpleVerifier, address _basicVerifier) external {
        simpleVerifier = Groth16Verifier(_simpleVerifier);
        basicVerifier = Groth16Verifier(_basicVerifier);
    }
}
`;
        
        const integrationPath = path.join(contractsPath, 'ZKProofIntegration.sol');
        fs.writeFileSync(integrationPath, zkIntegrationContract);
        console.log('✅ Created ZKProofIntegration.sol');
        
        // 3. 创建测试脚本
        const testScript = `const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

describe("ZK Proof Integration", function () {
    let simpleVerifier, basicVerifier, zkIntegration;
    let owner, user1, user2;
    
    // 加载测试证明数据
    const proofSimple = JSON.parse(fs.readFileSync(path.join(__dirname, '../circuits/proofs/examples/proof_simple.json')));
    const publicSimple = JSON.parse(fs.readFileSync(path.join(__dirname, '../circuits/proofs/examples/public_simple.json')));
    
    const proofBasicFixed = JSON.parse(fs.readFileSync(path.join(__dirname, '../circuits/proofs/examples/proof_basic_fixed.json')));
    const publicBasicFixed = JSON.parse(fs.readFileSync(path.join(__dirname, '../circuits/proofs/examples/public_basic_fixed.json')));
    
    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();
        
        // 部署验证合约
        const SimpleVerifier = await ethers.getContractFactory("Groth16Verifier", {
            bytecode: (await artifacts.readArtifact("contracts/WithdrawSimpleVerifier.sol:Groth16Verifier")).bytecode
        });
        simpleVerifier = await SimpleVerifier.deploy();
        
        const BasicVerifier = await ethers.getContractFactory("Groth16Verifier", {
            bytecode: (await artifacts.readArtifact("contracts/WithdrawBasicFixedVerifier.sol:Groth16Verifier")).bytecode
        });
        basicVerifier = await BasicVerifier.deploy();
        
        // 部署集成合约
        const ZKIntegration = await ethers.getContractFactory("ZKProofIntegration");
        zkIntegration = await ZKIntegration.deploy(
            await simpleVerifier.getAddress(),
            await basicVerifier.getAddress()
        );
    });
    
    it("Should verify simple withdraw proof", async function () {
        const tx = await zkIntegration.verifySimpleWithdraw(
            [proofSimple.pi_a[0], proofSimple.pi_a[1]],
            [[proofSimple.pi_b[0][1], proofSimple.pi_b[0][0]], 
             [proofSimple.pi_b[1][1], proofSimple.pi_b[1][0]]],
            [proofSimple.pi_c[0], proofSimple.pi_c[1]],
            publicSimple
        );
        
        await expect(tx).to.emit(zkIntegration, "ProofVerified");
    });
    
    it("Should verify basic withdraw proof", async function () {
        const tx = await zkIntegration.verifyBasicWithdraw(
            [proofBasicFixed.pi_a[0], proofBasicFixed.pi_a[1]],
            [[proofBasicFixed.pi_b[0][1], proofBasicFixed.pi_b[0][0]], 
             [proofBasicFixed.pi_b[1][1], proofBasicFixed.pi_b[1][0]]],
            [proofBasicFixed.pi_c[0], proofBasicFixed.pi_c[1]],
            publicBasicFixed
        );
        
        await expect(tx).to.emit(zkIntegration, "ProofVerified");
    });
    
    it("Should prevent double spending", async function () {
        // 第一次使用证明
        await zkIntegration.verifySimpleWithdraw(
            [proofSimple.pi_a[0], proofSimple.pi_a[1]],
            [[proofSimple.pi_b[0][1], proofSimple.pi_b[0][0]], 
             [proofSimple.pi_b[1][1], proofSimple.pi_b[1][0]]],
            [proofSimple.pi_c[0], proofSimple.pi_c[1]],
            publicSimple
        );
        
        // 第二次使用相同证明应该失败
        await expect(
            zkIntegration.verifySimpleWithdraw(
                [proofSimple.pi_a[0], proofSimple.pi_a[1]],
                [[proofSimple.pi_b[0][1], proofSimple.pi_b[0][0]], 
                 [proofSimple.pi_b[1][1], proofSimple.pi_b[1][0]]],
                [proofSimple.pi_c[0], proofSimple.pi_c[1]],
                publicSimple
            )
        ).to.be.revertedWith("Nullifier already used");
    });
});
`;
        
        const testPath = path.join(__dirname, '..', 'test', 'ZKProof.test.js');
        const testDir = path.dirname(testPath);
        if (!fs.existsSync(testDir)) {
            fs.mkdirSync(testDir, { recursive: true });
        }
        fs.writeFileSync(testPath, testScript);
        console.log('✅ Created ZKProof.test.js');
        
        console.log('\\n🎉 Smart contract integration complete!');
        console.log('\\n📂 Generated files:');
        console.log('  📁 contracts/ - Verifier contracts and ZK integration');
        console.log('  📁 test/ - ZK proof test suite');
        console.log('\\n🔧 Next steps:');
        console.log('  1. Run: npm test test/ZKProof.test.js');
        console.log('  2. Deploy contracts to your preferred network');
        console.log('  3. Integrate proof generation into your frontend');
        
    } catch (error) {
        console.error('❌ Error updating contracts:', error);
    }
}

// 运行更新
if (require.main === module) {
    updateContracts();
}

module.exports = { updateContracts };