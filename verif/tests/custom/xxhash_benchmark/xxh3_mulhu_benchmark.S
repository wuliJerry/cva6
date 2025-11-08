# xxH3 MULHU Benchmark for CVA6
# Focuses on XXH3_mul128_fold64 operation which generates MUL+MULHU instruction pairs
#
# This benchmark measures:
# 1. Raw mul128_fold64 operation (1 MULHU per call)
# 2. XXH3 16-byte hashing (uses mul128_fold64)
# 3. XXH3 64-byte hashing (uses 4x mul128_fold64)
#
# Similar structure to mulhu_hw_profile benchmarks

.section .text.init
.globl _start
.option norvc

# Configuration
#define NUM_ITERATIONS 1000

# CSR addresses
#define CSR_MCYCLE 0xB00
#define CSR_MINSTRET 0xB02

# xxHash3 constants
# PRIME_MX1 = 0x165667919E3779F9
#define PRIME_MX1_LO 0x9E3779F9
#define PRIME_MX1_HI 0x16566791

_start:
    # Initialize stack pointer
    li      sp, 0x84000000

    # Initialize test data buffer
    la      a0, test_buffer
    li      a1, 256
    li      a2, 0xA5
    call    fill_buffer

    # Get program start time
    csrr    s10, CSR_MCYCLE         # s10 = program start cycles

    # ========================================================================
    # Benchmark 1: Raw XXH3_mul128_fold64 (1 MULHU per iteration)
    # ========================================================================
    la      s11, profiling_mul128   # s11 = result pointer

    # Initialize accumulators
    li      s6, 0                   # s6 = total_cycles
    li      s7, 0                   # s7 = result checksum

    # Initialize operands (will vary each iteration)
    li      s8, 0x123456789ABCDEF0  # s8 = operand a
    li      s9, 0xFEDCBA9876543210  # s9 = operand b

    # Iteration loop
    li      s5, NUM_ITERATIONS

bench1_loop:
    # Profile single mul128_fold64 call
    csrr    s2, CSR_MCYCLE          # Entry mcycle

    # Inline XXH3_mul128_fold64(s8, s9)
    mul     a0, s8, s9              # a0 = low 64 bits
    mulhu   a1, s8, s9              # a1 = high 64 bits (← MULHU!)
    xor     a0, a0, a1              # a0 = fold (low ^ high)

    csrr    s3, CSR_MCYCLE          # Exit mcycle

    # Accumulate results
    sub     s4, s3, s2              # Delta cycles
    add     s6, s6, s4              # Total cycles
    xor     s7, s7, a0              # XOR result

    # Vary operands
    add     s8, s8, s5              # a += iteration
    sub     s9, s9, s5              # b -= iteration

    # Loop control
    addi    s5, s5, -1
    bnez    s5, bench1_loop

    # Store results for benchmark 1
    li      t0, NUM_ITERATIONS
    sd      t0, 0(s11)              # Store call_count
    sd      s6, 8(s11)              # Store total_cycles
    sd      s7, 16(s11)             # Store result_checksum
    div     t1, s6, t0
    sd      t1, 24(s11)             # Store avg_cycles_per_call

    # ========================================================================
    # Benchmark 2: XXH3 16-byte hash (1 MULHU per iteration)
    # ========================================================================
    la      s11, profiling_16byte   # s11 = result pointer

    # Initialize accumulators
    li      s6, 0                   # s6 = total_cycles
    li      s7, 0                   # s7 = result checksum

    # Iteration loop
    li      s5, NUM_ITERATIONS

bench2_loop:
    # Profile XXH3_16bytes call
    csrr    s2, CSR_MCYCLE          # Entry mcycle

    # Call XXH3_16bytes(test_buffer, kSecret, iteration_seed)
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5                  # seed = iteration number
    call    xxh3_16bytes

    csrr    s3, CSR_MCYCLE          # Exit mcycle

    # Accumulate results
    sub     s4, s3, s2              # Delta cycles
    add     s6, s6, s4              # Total cycles
    xor     s7, s7, a0              # XOR result

    # Loop control
    addi    s5, s5, -1
    bnez    s5, bench2_loop

    # Store results for benchmark 2
    li      t0, NUM_ITERATIONS
    sd      t0, 0(s11)              # Store call_count
    sd      s6, 8(s11)              # Store total_cycles
    sd      s7, 16(s11)             # Store result_checksum
    div     t1, s6, t0
    sd      t1, 24(s11)             # Store avg_cycles_per_call

    # ========================================================================
    # Benchmark 3: XXH3 64-byte hash (4 MULHU per iteration)
    # ========================================================================
    la      s11, profiling_64byte   # s11 = result pointer

    # Initialize accumulators
    li      s6, 0                   # s6 = total_cycles
    li      s7, 0                   # s7 = result checksum

    # Iteration loop
    li      s5, NUM_ITERATIONS

bench3_loop:
    # Profile XXH3_64bytes call
    csrr    s2, CSR_MCYCLE          # Entry mcycle

    # Call XXH3_64bytes(test_buffer, kSecret, iteration_seed)
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5                  # seed = iteration number
    call    xxh3_64bytes

    csrr    s3, CSR_MCYCLE          # Exit mcycle

    # Accumulate results
    sub     s4, s3, s2              # Delta cycles
    add     s6, s6, s4              # Total cycles
    xor     s7, s7, a0              # XOR result

    # Loop control
    addi    s5, s5, -1
    bnez    s5, bench3_loop

    # Store results for benchmark 3
    li      t0, NUM_ITERATIONS
    sd      t0, 0(s11)              # Store call_count
    sd      s6, 8(s11)              # Store total_cycles
    sd      s7, 16(s11)             # Store result_checksum
    div     t1, s6, t0
    sd      t1, 24(s11)             # Store avg_cycles_per_call

    # Get program end time
    csrr    s3, CSR_MCYCLE          # End cycle count
    sub     s4, s3, s10             # Total program cycles
    la      t0, profiling_mul128
    sd      s4, 32(t0)              # Store in first result structure

    # Signal completion
    la      t0, tohost
    li      t1, 1
    sd      t1, 0(t0)

done:
    j       done

# ========================================================================
# xxh3_16bytes: Hash 16 bytes using XXH3 algorithm
# Input: a0 = input buffer, a1 = secret, a2 = seed
# Output: a0 = hash value
# Uses 1 MULHU instruction via mul128_fold64
# ========================================================================
xxh3_16bytes:
    addi    sp, sp, -48
    sd      ra, 0(sp)
    sd      s0, 8(sp)
    sd      s1, 16(sp)
    sd      s2, 24(sp)
    sd      s3, 32(sp)
    sd      s4, 40(sp)

    mv      s0, a0                  # s0 = input
    mv      s1, a1                  # s1 = secret
    mv      s2, a2                  # s2 = seed

    # Load bitflips from secret
    ld      t0, 24(s1)              # secret[24]
    ld      t1, 32(s1)              # secret[32]
    xor     t0, t0, t1
    add     t0, t0, s2              # bitflip1 = (secret[24] ^ secret[32]) + seed

    ld      t2, 40(s1)              # secret[40]
    ld      t3, 48(s1)              # secret[48]
    xor     t2, t2, t3
    sub     t2, t2, s2              # bitflip2 = (secret[40] ^ secret[48]) - seed

    # Load input
    ld      s3, 0(s0)               # input[0]
    ld      s4, 8(s0)               # input[8]
    xor     s3, s3, t0              # input_lo = input[0] ^ bitflip1
    xor     s4, s4, t2              # input_hi = input[8] ^ bitflip2

    # acc = 16 + swap64(input_lo) + input_hi + mul128_fold64(input_lo, input_hi)
    # First: mul128_fold64(input_lo, input_hi)
    mul     t0, s3, s4              # Low 64 bits
    mulhu   t1, s3, s4              # High 64 bits (← MULHU!)
    xor     t0, t0, t1              # Fold

    # swap64(input_lo) - using compiler builtin pattern
    # For simplicity, just add without swap (still valid benchmark)
    li      a0, 16
    add     a0, a0, s3              # + input_lo
    add     a0, a0, s4              # + input_hi
    add     a0, a0, t0              # + mul128_fold64 result

    # Avalanche: h ^= h >> 37; h *= PRIME_MX1; h ^= h >> 32
    srli    t0, a0, 37
    xor     a0, a0, t0

    # PRIME_MX1 = 0x165667919E3779F9
    li      t1, PRIME_MX1_LO
    li      t2, PRIME_MX1_HI
    slli    t2, t2, 32
    or      t1, t1, t2
    mul     a0, a0, t1

    srli    t0, a0, 32
    xor     a0, a0, t0

    # Return
    ld      ra, 0(sp)
    ld      s0, 8(sp)
    ld      s1, 16(sp)
    ld      s2, 24(sp)
    ld      s3, 32(sp)
    ld      s4, 40(sp)
    addi    sp, sp, 48
    ret

# ========================================================================
# xxh3_64bytes: Hash 64 bytes using XXH3 algorithm
# Input: a0 = input buffer, a1 = secret, a2 = seed
# Output: a0 = hash value
# Uses 4 MULHU instructions via mul128_fold64
# ========================================================================
xxh3_64bytes:
    addi    sp, sp, -64
    sd      ra, 0(sp)
    sd      s0, 8(sp)
    sd      s1, 16(sp)
    sd      s2, 24(sp)
    sd      s3, 32(sp)
    sd      s4, 40(sp)
    sd      s5, 48(sp)
    sd      s6, 56(sp)

    mv      s0, a0                  # s0 = input
    mv      s1, a1                  # s1 = secret
    mv      s2, a2                  # s2 = seed

    # acc = 64 * PRIME_MX1
    li      s3, PRIME_MX1_LO
    li      t0, PRIME_MX1_HI
    slli    t0, t0, 32
    or      s3, s3, t0
    li      t0, 64
    mul     s3, s3, t0              # s3 = acc

    # Chunk 1 (bytes 0-15) - MULHU #1
    ld      s4, 0(s0)               # input[0]
    ld      s5, 8(s0)               # input[8]
    ld      t0, 0(s1)               # secret[0]
    ld      t1, 8(s1)               # secret[8]
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5              # Low
    mulhu   t3, s4, s5              # High (← MULHU #1)
    xor     t2, t2, t3              # Fold
    add     s3, s3, t2              # acc += result

    # Chunk 2 (bytes 16-31) - MULHU #2
    ld      s4, 16(s0)
    ld      s5, 24(s0)
    ld      t0, 16(s1)
    ld      t1, 24(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5              # ← MULHU #2
    xor     t2, t2, t3
    add     s3, s3, t2

    # Chunk 3 (bytes 32-47) - MULHU #3
    ld      s4, 32(s0)
    ld      s5, 40(s0)
    ld      t0, 32(s1)
    ld      t1, 40(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5              # ← MULHU #3
    xor     t2, t2, t3
    add     s3, s3, t2

    # Chunk 4 (bytes 48-63) - MULHU #4
    ld      s4, 48(s0)
    ld      s5, 56(s0)
    ld      t0, 48(s1)
    ld      t1, 56(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5              # ← MULHU #4
    xor     t2, t2, t3
    add     s3, s3, t2

    # Avalanche
    mv      a0, s3
    srli    t0, a0, 37
    xor     a0, a0, t0
    li      t1, PRIME_MX1_LO
    li      t2, PRIME_MX1_HI
    slli    t2, t2, 32
    or      t1, t1, t2
    mul     a0, a0, t1
    srli    t0, a0, 32
    xor     a0, a0, t0

    # Return
    ld      ra, 0(sp)
    ld      s0, 8(sp)
    ld      s1, 16(sp)
    ld      s2, 24(sp)
    ld      s3, 32(sp)
    ld      s4, 40(sp)
    ld      s5, 48(sp)
    ld      s6, 56(sp)
    addi    sp, sp, 64
    ret

# ========================================================================
# fill_buffer: Fill buffer with test pattern
# Input: a0 = buffer, a1 = length, a2 = pattern
# ========================================================================
fill_buffer:
    beqz    a1, fill_done
    mv      t0, a0
fill_loop:
    sb      a2, 0(t0)
    addi    t0, t0, 1
    addi    a1, a1, -1
    bnez    a1, fill_loop
fill_done:
    ret

# ========================================================================
# Data Section
# ========================================================================
.section .data
.align 3

# xxHash3 default secret (128 bytes)
kSecret:
    .byte 0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe
    .byte 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c
    .byte 0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb
    .byte 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f
    .byte 0x72, 0x28, 0x2e, 0xa3, 0x8c, 0x32, 0xa6, 0x54
    .byte 0xb5, 0x4d, 0x40, 0x5f, 0x37, 0x05, 0x89, 0xe6
    .byte 0x97, 0x82, 0x93, 0x62, 0xc1, 0x49, 0x51, 0x52
    .byte 0xa0, 0xc9, 0xa7, 0x5f, 0xe3, 0x60, 0xf0, 0x23
    .byte 0xa0, 0xa5, 0x7e, 0xcd, 0xab, 0x58, 0x37, 0x8e
    .byte 0xdd, 0xd1, 0x7a, 0x6a, 0x41, 0xb2, 0x87, 0xdc
    .byte 0x0d, 0xf6, 0x34, 0x8c, 0x2a, 0xcc, 0x75, 0xb0
    .byte 0x13, 0x99, 0x44, 0x4e, 0x84, 0xb5, 0x3b, 0xd1
    .byte 0x28, 0x56, 0x49, 0x69, 0xa5, 0xd4, 0x4f, 0x94
    .byte 0xc9, 0xcd, 0xdb, 0xf9, 0x2f, 0x07, 0x43, 0x12
    .byte 0xb7, 0x14, 0xe5, 0x08, 0xbd, 0xd1, 0x1a, 0x8f
    .byte 0x88, 0x26, 0x3f, 0x9e, 0x54, 0xb6, 0x4c, 0x4f

# Profiling data structures
profiling_mul128:
    .dword 0    # 0x00: call_count
    .dword 0    # 0x08: total_cycles
    .dword 0    # 0x10: result_checksum
    .dword 0    # 0x18: avg_cycles_per_call
    .dword 0    # 0x20: total_program_cycles

profiling_16byte:
    .dword 0    # 0x00: call_count
    .dword 0    # 0x08: total_cycles
    .dword 0    # 0x10: result_checksum
    .dword 0    # 0x18: avg_cycles_per_call

profiling_64byte:
    .dword 0    # 0x00: call_count
    .dword 0    # 0x08: total_cycles
    .dword 0    # 0x10: result_checksum
    .dword 0    # 0x18: avg_cycles_per_call

# Test buffer
.align 12
test_buffer:
    .space 256

.align 6
tohost:     .dword 0
fromhost:   .dword 0