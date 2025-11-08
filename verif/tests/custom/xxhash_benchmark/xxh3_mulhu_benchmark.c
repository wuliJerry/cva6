/*
 * xxh3_mulhu_benchmark.c
 *
 * Benchmark focused on XXH3 functions that generate MULHU instructions
 * Key functions: XXH_mult64to128() and XXH3_mul128_fold64()
 *
 * These use __uint128_t which compiles to MUL+MULHU on RISC-V64
 */

#include <stdint.h>
#include <stddef.h>

// Type definitions matching xxHash
typedef uint64_t xxh_u64;
typedef uint8_t xxh_u8;

// XXH128 hash result type
typedef struct {
    xxh_u64 low64;
    xxh_u64 high64;
} XXH128_hash_t;

// xxHash3 prime constants
#define PRIME_MX1   0x165667919E3779F9ULL
#define PRIME_MX2   0x9FB21C651E98DF25ULL

// ========================================================================
// Core MULHU-generating functions from xxHash
// ========================================================================

/**
 * XXH_mult64to128: Multiply two 64-bit integers to get 128-bit result
 *
 * On RISC-V this compiles to:
 *   MUL   rd, rs1, rs2    // Low 64 bits
 *   MULHU rd, rs1, rs2    // High 64 bits
 *
 * This is the KEY function that generates MULHU instructions!
 */
static XXH128_hash_t XXH_mult64to128(xxh_u64 lhs, xxh_u64 rhs)
{
    __uint128_t const product = (__uint128_t)lhs * (__uint128_t)rhs;
    XXH128_hash_t r128;
    r128.low64  = (xxh_u64)(product);
    r128.high64 = (xxh_u64)(product >> 64);
    return r128;
}

/**
 * XXH3_mul128_fold64: Multiply and fold (XOR high and low parts)
 *
 * This is used extensively in XXH3 for mixing data
 * Also generates MUL+MULHU pair
 */
static xxh_u64 XXH3_mul128_fold64(xxh_u64 lhs, xxh_u64 rhs)
{
    XXH128_hash_t product = XXH_mult64to128(lhs, rhs);
    return product.low64 ^ product.high64;
}

// ========================================================================
// Helper functions
// ========================================================================

static inline xxh_u64 XXH_readLE64(const void* ptr)
{
    const xxh_u8* p = (const xxh_u8*)ptr;
    return ((xxh_u64)p[0])       | ((xxh_u64)p[1] << 8)  |
           ((xxh_u64)p[2] << 16) | ((xxh_u64)p[3] << 24) |
           ((xxh_u64)p[4] << 32) | ((xxh_u64)p[5] << 40) |
           ((xxh_u64)p[6] << 48) | ((xxh_u64)p[7] << 56);
}

static inline xxh_u64 XXH_rotl64(xxh_u64 x, int r)
{
    return (x << r) | (x >> (64 - r));
}

static inline xxh_u64 XXH_swap64(xxh_u64 x)
{
#if defined(__GNUC__)
    return __builtin_bswap64(x);
#else
    return ((x << 56) & 0xff00000000000000ULL) |
           ((x << 40) & 0x00ff000000000000ULL) |
           ((x << 24) & 0x0000ff0000000000ULL) |
           ((x <<  8) & 0x000000ff00000000ULL) |
           ((x >>  8) & 0x00000000ff000000ULL) |
           ((x >> 24) & 0x0000000000ff0000ULL) |
           ((x >> 40) & 0x000000000000ff00ULL) |
           ((x >> 56) & 0x00000000000000ffULL);
#endif
}

static inline xxh_u64 XXH_xorshift64(xxh_u64 v64, int shift)
{
    return v64 ^ (v64 >> shift);
}

/**
 * XXH3_avalanche: Fast avalanche mixing
 * Also contains a multiply, but doesn't need MULHU
 */
static xxh_u64 XXH3_avalanche(xxh_u64 h64)
{
    h64 = XXH_xorshift64(h64, 37);
    h64 *= PRIME_MX1;
    h64 = XXH_xorshift64(h64, 32);
    return h64;
}

// ========================================================================
// XXH3 algorithm implementation - focuses on MULHU-heavy paths
// ========================================================================

/**
 * XXH3_len_9to16_64b: Hash 9-16 bytes
 *
 * This is the ACTUAL xxHash3 algorithm for small inputs
 * It uses XXH3_mul128_fold64 which generates MULHU!
 *
 * Algorithm:
 * 1. Load first and last 8 bytes
 * 2. XOR with secret and seed
 * 3. Multiply using mul128_fold64 (← GENERATES MULHU)
 * 4. Combine with length and swap
 * 5. Avalanche mixing
 */
static xxh_u64 XXH3_len_9to16_64b(const xxh_u8* input, size_t len,
                                   const xxh_u8* secret, xxh_u64 seed)
{
    xxh_u64 const bitflip1 = (XXH_readLE64(secret+24) ^ XXH_readLE64(secret+32)) + seed;
    xxh_u64 const bitflip2 = (XXH_readLE64(secret+40) ^ XXH_readLE64(secret+48)) - seed;
    xxh_u64 const input_lo = XXH_readLE64(input)           ^ bitflip1;
    xxh_u64 const input_hi = XXH_readLE64(input + len - 8) ^ bitflip2;

    // This line uses mul128_fold64 which generates MULHU!
    xxh_u64 const acc = len
                      + XXH_swap64(input_lo) + input_hi
                      + XXH3_mul128_fold64(input_lo, input_hi);

    return XXH3_avalanche(acc);
}

/**
 * XXH3_len_17to128_64b: Hash 17-128 bytes
 *
 * This processes multiple 16-byte chunks, each using mul128_fold64
 * Generates MANY MULHU instructions!
 */
static xxh_u64 XXH3_len_17to128_64b(const xxh_u8* input, size_t len,
                                     const xxh_u8* secret, xxh_u64 seed)
{
    xxh_u64 acc = len * PRIME_MX1;

    // Process at least 2 chunks
    if (len > 32) {
        if (len > 64) {
            if (len > 96) {
                // 4 chunks (96-128 bytes)
                xxh_u64 input_1 = XXH_readLE64(input);
                xxh_u64 input_2 = XXH_readLE64(input + 8);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret),
                                          input_2 ^ XXH_readLE64(secret + 8));

                input_1 = XXH_readLE64(input + 32);
                input_2 = XXH_readLE64(input + 40);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 16),
                                          input_2 ^ XXH_readLE64(secret + 24));

                input_1 = XXH_readLE64(input + 64);
                input_2 = XXH_readLE64(input + 72);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 32),
                                          input_2 ^ XXH_readLE64(secret + 40));

                input_1 = XXH_readLE64(input + len - 16);
                input_2 = XXH_readLE64(input + len - 8);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 48),
                                          input_2 ^ XXH_readLE64(secret + 56));
            } else {
                // 3 chunks (64-96 bytes)
                xxh_u64 input_1 = XXH_readLE64(input);
                xxh_u64 input_2 = XXH_readLE64(input + 8);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret),
                                          input_2 ^ XXH_readLE64(secret + 8));

                input_1 = XXH_readLE64(input + 32);
                input_2 = XXH_readLE64(input + 40);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 16),
                                          input_2 ^ XXH_readLE64(secret + 24));

                input_1 = XXH_readLE64(input + len - 16);
                input_2 = XXH_readLE64(input + len - 8);
                acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 32),
                                          input_2 ^ XXH_readLE64(secret + 40));
            }
        } else {
            // 2 chunks (32-64 bytes)
            xxh_u64 input_1 = XXH_readLE64(input);
            xxh_u64 input_2 = XXH_readLE64(input + 8);
            acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret),
                                      input_2 ^ XXH_readLE64(secret + 8));

            input_1 = XXH_readLE64(input + len - 16);
            input_2 = XXH_readLE64(input + len - 8);
            acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 16),
                                      input_2 ^ XXH_readLE64(secret + 24));
        }
    } else {
        // 1-2 chunks (17-32 bytes)
        xxh_u64 input_1 = XXH_readLE64(input);
        xxh_u64 input_2 = XXH_readLE64(input + 8);
        acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret),
                                  input_2 ^ XXH_readLE64(secret + 8));

        input_1 = XXH_readLE64(input + len - 16);
        input_2 = XXH_readLE64(input + len - 8);
        acc += XXH3_mul128_fold64(input_1 ^ XXH_readLE64(secret + 16),
                                  input_2 ^ XXH_readLE64(secret + 24));
    }

    return XXH3_avalanche(acc);
}

// ========================================================================
// Benchmark driver (no dependencies, no printf)
// ========================================================================

// Default xxHash3 secret (first 128 bytes)
static const xxh_u8 kSecret[128] = {
    0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c,
    0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f,
    0x72, 0x28, 0x2e, 0xa3, 0x8c, 0x32, 0xa6, 0x54, 0xb5, 0x4d, 0x40, 0x5f, 0x37, 0x05, 0x89, 0xe6,
    0x97, 0x82, 0x93, 0x62, 0xc1, 0x49, 0x51, 0x52, 0xa0, 0xc9, 0xa7, 0x5f, 0xe3, 0x60, 0xf0, 0x23,
    0xa0, 0xa5, 0x7e, 0xcd, 0xab, 0x58, 0x37, 0x8e, 0xdd, 0xd1, 0x7a, 0x6a, 0x41, 0xb2, 0x87, 0xdc,
    0x0d, 0xf6, 0x34, 0x8c, 0x2a, 0xcc, 0x75, 0xb0, 0x13, 0x99, 0x44, 0x4e, 0x84, 0xb5, 0x3b, 0xd1,
    0x28, 0x56, 0x49, 0x69, 0xa5, 0xd4, 0x4f, 0x94, 0xc9, 0xcd, 0xdb, 0xf9, 0x2f, 0x07, 0x43, 0x12,
    0xb7, 0x14, 0xe5, 0x08, 0xbd, 0xd1, 0x1a, 0x8f, 0x88, 0x26, 0x3f, 0x9e, 0x54, 0xb6, 0x4c, 0x4f
};

// Test data buffer
static xxh_u8 test_data[256];

// Result sink (volatile to prevent optimization)
volatile xxh_u64 result_sink = 0;

/**
 * demo_xxh3_9to16: Demonstrates XXH3 9-16 byte hashing
 * This generates MULHU instructions from mul128_fold64
 */
void demo_xxh3_9to16(void) {
    result_sink = XXH3_len_9to16_64b(test_data, 16, kSecret, 0);
}

/**
 * demo_xxh3_17to128: Demonstrates XXH3 17-128 byte hashing
 * This generates MANY MULHU instructions
 */
void demo_xxh3_17to128(void) {
    result_sink = XXH3_len_17to128_64b(test_data, 64, kSecret, 0);
}

/**
 * demo_mul128_fold64: Direct test of mul128_fold64
 * Pure MULHU generation
 */
void demo_mul128_fold64(void) {
    xxh_u64 a = 0x123456789ABCDEF0ULL;
    xxh_u64 b = 0xFEDCBA9876543210ULL;
    result_sink = XXH3_mul128_fold64(a, b);
}