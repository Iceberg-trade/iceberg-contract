pragma circom 2.0.0;

// 1位多路选择器
template Mux1() {
    signal input c[2];  // 两个输入选项
    signal input s;     // 选择信号 (0 或 1)
    signal output out;  // 输出
    
    // 约束选择信号只能是0或1
    s * (s - 1) === 0;
    
    // 多路选择逻辑: out = s * c[1] + (1 - s) * c[0]
    out <== s * (c[1] - c[0]) + c[0];
}

// 2位多路选择器
template Mux2() {
    signal input c[4];   // 四个输入选项
    signal input s[2];   // 2位选择信号
    signal output out;
    
    // 约束每个选择信号只能是0或1
    s[0] * (s[0] - 1) === 0;
    s[1] * (s[1] - 1) === 1;
    
    // 第一级选择
    component mux1[2];
    mux1[0] = Mux1();
    mux1[0].c[0] <== c[0];
    mux1[0].c[1] <== c[1];
    mux1[0].s <== s[0];
    
    mux1[1] = Mux1();
    mux1[1].c[0] <== c[2];
    mux1[1].c[1] <== c[3];
    mux1[1].s <== s[0];
    
    // 第二级选择
    component mux2 = Mux1();
    mux2.c[0] <== mux1[0].out;
    mux2.c[1] <== mux1[1].out;
    mux2.s <== s[1];
    
    out <== mux2.out;
}

// 3位多路选择器
template Mux3() {
    signal input c[8];   // 八个输入选项
    signal input s[3];   // 3位选择信号
    signal output out;
    
    // 约束选择信号
    for (var i = 0; i < 3; i++) {
        s[i] * (s[i] - 1) === 0;
    }
    
    // 使用两个Mux2构建Mux3
    component mux2[2];
    mux2[0] = Mux2();
    mux2[1] = Mux2();
    
    for (var i = 0; i < 4; i++) {
        mux2[0].c[i] <== c[i];
        mux2[1].c[i] <== c[i + 4];
    }
    
    mux2[0].s[0] <== s[0];
    mux2[0].s[1] <== s[1];
    mux2[1].s[0] <== s[0];
    mux2[1].s[1] <== s[1];
    
    // 最终选择
    component finalMux = Mux1();
    finalMux.c[0] <== mux2[0].out;
    finalMux.c[1] <== mux2[1].out;
    finalMux.s <== s[2];
    
    out <== finalMux.out;
}

// 通用多路选择器（基于位向量）
template MultiMux(n) {
    var nChoices = 2**n;
    signal input c[nChoices];  // 2^n个输入选项
    signal input s[n];         // n位选择信号
    signal output out;
    
    // 约束所有选择信号为0或1
    for (var i = 0; i < n; i++) {
        s[i] * (s[i] - 1) === 0;
    }
    
    // 递归构建多路选择器
    if (n == 1) {
        component mux = Mux1();
        mux.c[0] <== c[0];
        mux.c[1] <== c[1];
        mux.s <== s[0];
        out <== mux.out;
    } else {
        var halfChoices = nChoices / 2;
        
        component subMux[2];
        subMux[0] = MultiMux(n - 1);
        subMux[1] = MultiMux(n - 1);
        
        // 分配输入到子选择器
        for (var i = 0; i < halfChoices; i++) {
            subMux[0].c[i] <== c[i];
            subMux[1].c[i] <== c[i + halfChoices];
        }
        
        // 分配选择信号
        for (var i = 0; i < n - 1; i++) {
            subMux[0].s[i] <== s[i];
            subMux[1].s[i] <== s[i];  
        }
        
        // 最高位控制最终选择
        component finalMux = Mux1();
        finalMux.c[0] <== subMux[0].out;
        finalMux.c[1] <== subMux[1].out;
        finalMux.s <== s[n - 1];
        
        out <== finalMux.out;
    }
}

// 条件选择器（简化版Mux1）
template CondSelect() {
    signal input condition;  // 条件信号
    signal input ifTrue;     // 条件为真时的值
    signal input ifFalse;    // 条件为假时的值
    signal output out;
    
    // 约束条件只能是0或1
    condition * (condition - 1) === 0;
    
    // 条件选择
    out <== condition * (ifTrue - ifFalse) + ifFalse;
}

// 数组选择器（根据索引选择数组元素）
template ArraySelect(arraySize) {
    signal input array[arraySize];
    signal input index;
    signal output out;
    
    // 将索引转换为二进制
    var indexBits = 0;
    var temp = arraySize - 1;
    while (temp > 0) {
        indexBits++;
        temp = temp >> 1;
    }
    
    component indexToBits = Num2Bits(indexBits);
    indexToBits.in <== index;
    
    // 使用多路选择器
    component mux = MultiMux(indexBits);
    for (var i = 0; i < arraySize; i++) {
        mux.c[i] <== array[i];
    }
    for (var i = 0; i < indexBits; i++) {
        mux.s[i] <== indexToBits.out[i];
    }
    
    out <== mux.out;
}