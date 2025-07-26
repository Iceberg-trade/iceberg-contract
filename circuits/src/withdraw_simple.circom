pragma circom 2.0.0;

template Withdraw() {
    signal input nullifierHash;
    signal input recipient;
    signal input nullifier;
    signal input secret;

    signal commitmentSquared;
    signal nullifierSquared;

    commitmentSquared <== nullifier * secret;
    nullifierSquared <== nullifier * nullifier;
    nullifierHash === nullifierSquared;

    signal secretInv;
    secretInv <-- 1 / secret;
    secret * secretInv === 1;

    signal recipientInv;
    recipientInv <-- 1 / recipient;
    recipient * recipientInv === 1;

    signal output isValid;
    isValid <== 1;
}

component main {public [nullifierHash, recipient]} = Withdraw();