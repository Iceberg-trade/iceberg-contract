pragma circom 2.0.0;

include "circomlib/circuits/poseidon.circom";
include "circomlib/circuits/bitify.circom";

// Multiplexer template - must be defined before use
template MultiMux1(n) {
    assert(n >= 1);
    signal input c[n][2];  // Selection values
    signal input s;        // Selector signal
    signal output out[n];
    
    for (var i = 0; i < n; i++) {
        out[i] <== (c[i][1] - c[i][0]) * s + c[i][0];
    }
}

// Complete version of privacy withdraw circuit  
// Uses Poseidon hash and full Merkle Tree verification
template Withdraw() {
    // Merkle Tree parameters
    var levels = 5; // 5-level Merkle Tree, supports 2^5 = 32 leaf nodes
    
    // Public inputs
    signal input merkleRoot;      // Merkle Tree root hash
    signal input nullifierHash;   // Hash of nullifier, prevents double spending
    signal input recipient;       // Withdrawal address
    
    // Private inputs
    signal input nullifier;       // Random nullifier
    signal input secret;          // Random secret  
    signal input pathElements[levels];  // Merkle proof path elements
    signal input pathIndices[levels];   // Merkle proof path indices
    
    // 1. Calculate commitment = poseidon(nullifier, secret)
    component commitmentHasher = Poseidon(2);
    commitmentHasher.inputs[0] <== nullifier;
    commitmentHasher.inputs[1] <== secret;
    signal commitment;
    commitment <== commitmentHasher.out;
    
    // 2. Verify nullifier hash: nullifierHash = poseidon(nullifier)
    component nullifierHasher = Poseidon(1);
    nullifierHasher.inputs[0] <== nullifier;
    nullifierHash === nullifierHasher.out;
    
    // 3. Merkle Tree inclusion proof
    component merkleProof[levels];
    component mux[levels];
    
    signal left[levels];
    signal right[levels];
    signal pathElement[levels + 1];
    
    // Start verification path from leaf node (commitment)
    pathElement[0] <== commitment;
    
    for (var i = 0; i < levels; i++) {
        pathIndices[i] * (1 - pathIndices[i]) === 0;
        
        // Decide left or right subtree based on pathIndices[i]
        mux[i] = MultiMux1(2);
        mux[i].c[0][0] <== pathElement[i];
        mux[i].c[0][1] <== pathElements[i];
        mux[i].c[1][0] <== pathElements[i];
        mux[i].c[1][1] <== pathElement[i];
        mux[i].s <== pathIndices[i];
        
        left[i] <== mux[i].out[0];
        right[i] <== mux[i].out[1];
        
        // Calculate parent node hash
        merkleProof[i] = Poseidon(2);
        merkleProof[i].inputs[0] <== left[i];
        merkleProof[i].inputs[1] <== right[i];
        
        pathElement[i + 1] <== merkleProof[i].out;
    }
    
    // Verify final root hash
    merkleRoot === pathElement[levels];
    
    // 4. Range checks - ensure all values are within valid range
    component nullifierBits = Num2Bits(254);
    nullifierBits.in <== nullifier;
    
    component secretBits = Num2Bits(254);
    secretBits.in <== secret;
    
    component recipientBits = Num2Bits(160); // Ethereum address is 160 bits
    recipientBits.in <== recipient;
    
    // 5. Ensure nullifier and secret are not zero
    signal nullifierSquared;
    signal secretSquared;
    nullifierSquared <== nullifier * nullifier;
    secretSquared <== secret * secret;
    
    // If nullifier or secret is 0, corresponding square is also 0
    // Prove they are not zero by computing inverse
    signal nullifierInv;
    signal secretInv;
    nullifierInv <-- 1 / nullifier;
    secretInv <-- 1 / secret;
    nullifier * nullifierInv === 1;
    secret * secretInv === 1;
}

component main {public [merkleRoot, nullifierHash, recipient]} = Withdraw();