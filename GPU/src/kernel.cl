// SHA1 GPU Implementation for DUCO Mining
// Optimized for OpenCL 1.2+ (Adreno 660, NVIDIA, AMD, Intel)
// No typedefs - uchar/uint are built-in in OpenCL

// SHA1 工具函数
uint rotr(uint x, uint n) {
    return (x >> n) | (x << (32 - n));
}

uint rotl(uint x, uint n) {
    return (x << n) | (x >> (32 - n));
}

// SHA1 压缩函数核心
void sha1_compress(uint* state, uchar* block) {
    uint w[80];
    for (int i = 0; i < 16; ++i) {
        w[i] = (block[i*4] << 24) | (block[i*4+1] << 16) | (block[i*4+2] << 8) | block[i*4+3];
    }
    for (int i = 16; i < 80; ++i) {
        w[i] = rotl(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
    }

    uint a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];

    for (int i = 0; i < 80; ++i) {
        uint f, k;
        // 保存原始 b,c,d 用于 f 函数计算
        uint orig_b = b, orig_c = c, orig_d = d;

        if (i < 20) {
            f = (orig_b & orig_c) | ((~orig_b) & orig_d);
            k = 0x5A827999;
        } else if (i < 40) {
            f = orig_b ^ orig_c ^ orig_d;
            k = 0x6ED9EBA1;
        } else if (i < 60) {
            f = (orig_b & orig_c) | (orig_b & orig_d) | (orig_c & orig_d);
            k = 0x8F1BBCDC;
        } else {
            f = orig_b ^ orig_c ^ orig_d;
            k = 0xCA62C1D6;
        }

        uint temp = (rotl(a, 5) + f + e + k + w[i]);
        e = d;
        d = c;
        c = rotl(b, 30);  // 标准 SHA1 要求
        b = a;
        a = temp;
    }

    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
}

// 将整数转为字符串
int int_to_str(uchar* out, uint n) {
    if (n == 0) {
        out[0] = '0';
        return 1;
    }
    int len = 0;
    uchar tmp[16];
    while (n > 0) {
        tmp[len++] = '0' + (n % 10);
        n /= 10;
    }
    for (int i = 0; i < len; ++i) {
        out[i] = tmp[len - 1 - i];
    }
    return len;
}

// 主挖矿 kernel
__kernel void duco_brute(
    __global uchar* base_data,
    uint base_len,
    __global uchar* expected_hash,
    ulong start_nonce,    // 原来的 diff → start_nonce
    ulong batch_size,     // 原来的 job_mul → batch_size
    __global uint* result
) {
    ulong tid = start_nonce + get_global_id(0);
    if (get_global_id(0) >= batch_size || *result != 0) return;
    // 构造输入: base_data + nonce_str
    uchar input[128];
    for (int i = 0; i < base_len; ++i) {
        input[i] = base_data[i];
    }

    // 转 nonce 为字符串
    uchar nonce_str[16];
    int str_len = int_to_str(nonce_str, (uint)tid);

    for (int i = 0; i < str_len; ++i) {
        input[base_len + i] = nonce_str[i];
    }

    int total_len = base_len + str_len;

    // 填充
    uchar block[64];
    uint state[5] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0};

    // 清空 block
    for (int i = 0; i < 64; ++i) block[i] = 0;

    // 处理输入
    for (int i = 0; i < total_len; ++i) {
        block[i % 64] = input[i];
        if (i % 64 == 63) {
            sha1_compress(state, block);
            for (int j = 0; j < 64; ++j) block[j] = 0;
        }
    }

    // 添加 0x80
    block[total_len % 64] = 0x80;

    // 处理填充
    if (total_len % 64 >= 56) {
        for (int i = (total_len % 64) + 1; i < 64; ++i) block[i] = 0;
        sha1_compress(state, block);
        for (int i = 0; i < 64; ++i) block[i] = 0;
    } else {
        for (int i = (total_len % 64) + 1; i < 56; ++i) block[i] = 0;
    }

    // 添加长度
    ulong bit_len = (ulong)total_len * 8;
    block[56] = (bit_len >> 56) & 0xFF;
    block[57] = (bit_len >> 48) & 0xFF;
    block[58] = (bit_len >> 40) & 0xFF;
    block[59] = (bit_len >> 32) & 0xFF;
    block[60] = (bit_len >> 24) & 0xFF;
    block[61] = (bit_len >> 16) & 0xFF;
    block[62] = (bit_len >> 8) & 0xFF;
    block[63] = bit_len & 0xFF;

    sha1_compress(state, block);

    // 输出哈希
    uchar hash[20];
    for (int i = 0; i < 5; ++i) {
        hash[i*4]   = (state[i] >> 24) & 0xFF;
        hash[i*4+1] = (state[i] >> 16) & 0xFF;
        hash[i*4+2] = (state[i] >> 8) & 0xFF;
        hash[i*4+3] = state[i] & 0xFF;
    }

    // 比较哈希
    int match = 1;
    for (int i = 0; i < 20; ++i) {
        if (hash[i] != expected_hash[i]) {
            match = 0;
            break;
        }
    }

    if (match) {
        // 使用原子操作记录第一个找到的 nonce
        atomic_cmpxchg((__global volatile uint*)result, 0, (uint)tid);
    }
}
