# XXH3 Benchmark with 4% MULHU Ratio - With Profiling Infrastructure
# Real workload with high iteration counts
# Based on /home/ruijieg/cva6/verif/tests/custom/xxhash_benchmark/xxh3_4percent.S
# Modified to use simplified profiling from mulhu_sweep_profile

.section .text.init
.globl _start
.option norvc

# Configuration for 4% MULHU ratio - HIGH ITERATION COUNTS
#define NUM_ITER_BENCH1 10000
#define NUM_ITER_BENCH2 100000
#define NUM_ITER_BENCH3 10000
#define NUM_ITER_BENCH4 333000

# xxHash3 constants
#define PRIME_MX1_LO 0x9E3779F9
#define PRIME_MX1_HI 0x16566791

# CSR addresses
#define CSR_MCYCLE 0xB00
#define CSR_MINSTRET 0xB02

_start:
    # Initialize stack pointer
    li      sp, 0x84000000

    # Initialize profiling data to zero
    la      s0, profiling_data
    sd      zero, 0(s0)
    sd      zero, 8(s0)
    sd      zero, 16(s0)
    sd      zero, 24(s0)

    # Get program start time
    csrr    s2, CSR_MCYCLE
    csrr    s3, CSR_MINSTRET

    # Run benchmark kernel
    call    benchmark_kernel

    # Get program end time
    csrr    s4, CSR_MCYCLE
    csrr    s5, CSR_MINSTRET

    # Calculate and store total program cycles
    la      s0, profiling_data
    sub     a0, s4, s2       # Total program cycles
    sd      a0, 16(s0)       # Store total_program_cycles

    # Calculate avg: total_cycles / call_count
    ld      a1, 8(s0)        # Load total_cycles
    ld      a2, 0(s0)        # Load call_count
    beqz    a2, skip_avg     # Avoid divide by zero
    div     a3, a1, a2       # avg = total / count
    sd      a3, 24(s0)       # Store avg_cycles_per_call
skip_avg:

    # Exit
    la      s0, tohost
    li      s1, 1
    sd      s1, 0(s0)
done:
    j       done

.section .text
benchmark_kernel:
    addi    sp, sp, -112
    sd      ra, 104(sp)
    sd      s0, 96(sp)
    sd      s1, 88(sp)
    sd      s2, 80(sp)
    sd      s3, 72(sp)
    sd      s4, 64(sp)
    sd      s5, 56(sp)
    sd      s6, 48(sp)
    sd      s7, 40(sp)
    sd      s8, 32(sp)
    sd      s9, 24(sp)
    sd      s10, 16(sp)
    sd      s11, 8(sp)

    # Initialize accumulators for results
    li      s6, 0         # Result accumulator
    li      s7, 0         # Another result accumulator

    # Benchmark 1: mul128_fold64 (10000 iter = 10000 MULHU, 10000 MUL)
    li      s8, 0x123456789ABCDEF0
    li      s9, 0xFEDCBA9876543210
    li      s5, NUM_ITER_BENCH1
bench1_loop:
    mul     a0, s8, s9
    mulhu   a1, s8, s9
    xor     a0, a0, a1
    xor     s7, s7, a0
    add     s8, s8, s5
    sub     s9, s9, s5
    addi    s5, s5, -1
    bnez    s5, bench1_loop

    # Benchmark 2: XXH3 16-byte (100000 iter = 100000 MULHU, 200000 MUL)
    li      s5, NUM_ITER_BENCH2
bench2_loop:
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5
    call    xxh3_16bytes
    xor     s7, s7, a0
    addi    s5, s5, -1
    bnez    s5, bench2_loop

    # Benchmark 3: XXH3 64-byte (10000 iter = 40000 MULHU, 60000 MUL)
    li      s5, NUM_ITER_BENCH3
bench3_loop:
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5
    call    xxh3_64bytes
    xor     s7, s7, a0
    addi    s5, s5, -1
    bnez    s5, bench3_loop

    # Benchmark 4: Avalanche-style mixing (333000 iter, 0 MULHU, 3330000 MUL)
    li      s7, 0x123456789ABCDEF0
    li      t1, PRIME_MX1_LO
    li      t2, PRIME_MX1_HI
    slli    t2, t2, 32
    or      t1, t1, t2
    li      s5, NUM_ITER_BENCH4
bench4_loop:
    # 10x MUL operations (avalanche-style mixing)
    mul     s7, s7, t1
    srli    a0, s7, 32
    xor     s7, s7, a0
    mul     s7, s7, t1
    srli    a0, s7, 29
    xor     s7, s7, a0
    mul     s7, s7, t1
    srli    a0, s7, 37
    xor     s7, s7, a0
    mul     s7, s7, t1
    srli    a0, s7, 32
    xor     s7, s7, a0
    mul     s7, s7, t1
    srli    a0, s7, 29
    xor     s7, s7, a0
    mul     s7, s7, t1
    mul     s7, s7, t1
    mul     s7, s7, t1
    mul     s7, s7, t1
    mul     s7, s7, t1
    addi    s5, s5, -1
    bnez    s5, bench4_loop

    # Store result checksum (for verification)
    la      s0, profiling_data
    # call_count is stored at profiling_data+0 (set to 0 for now, can be incremented if needed)
    # total_cycles is stored at profiling_data+8 (set to 0 for now)
    # We'll just store the result checksum as a placeholder
    # In reality, this benchmark doesn't use the same profiling as MULHU_SOFT

    # Restore and return
    ld      ra, 104(sp)
    ld      s0, 96(sp)
    ld      s1, 88(sp)
    ld      s2, 80(sp)
    ld      s3, 72(sp)
    ld      s4, 64(sp)
    ld      s5, 56(sp)
    ld      s6, 48(sp)
    ld      s7, 40(sp)
    ld      s8, 32(sp)
    ld      s9, 24(sp)
    ld      s10, 16(sp)
    ld      s11, 8(sp)
    addi    sp, sp, 112
    ret

# xxh3_16bytes function
xxh3_16bytes:
    addi    sp, sp, -48
    sd      ra, 0(sp)
    sd      s0, 8(sp)
    sd      s1, 16(sp)
    sd      s2, 24(sp)
    sd      s3, 32(sp)
    sd      s4, 40(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    ld      t0, 24(s1)
    ld      t1, 32(s1)
    xor     t0, t0, t1
    add     t0, t0, s2
    ld      t2, 40(s1)
    ld      t3, 48(s1)
    xor     t2, t2, t3
    sub     t2, t2, s2
    ld      s3, 0(s0)
    ld      s4, 8(s0)
    xor     s3, s3, t0
    xor     s4, s4, t2
    mul     t0, s3, s4
    mulhu   t1, s3, s4
    xor     t0, t0, t1
    li      a0, 16
    add     a0, a0, s3
    add     a0, a0, s4
    add     a0, a0, t0
    srli    t0, a0, 37
    xor     a0, a0, t0
    li      t1, PRIME_MX1_LO
    li      t2, PRIME_MX1_HI
    slli    t2, t2, 32
    or      t1, t1, t2
    mul     a0, a0, t1
    srli    t0, a0, 32
    xor     a0, a0, t0
    ld      ra, 0(sp)
    ld      s0, 8(sp)
    ld      s1, 16(sp)
    ld      s2, 24(sp)
    ld      s3, 32(sp)
    ld      s4, 40(sp)
    addi    sp, sp, 48
    ret

# xxh3_64bytes function
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
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    li      s3, PRIME_MX1_LO
    li      t0, PRIME_MX1_HI
    slli    t0, t0, 32
    or      s3, s3, t0
    li      t0, 64
    mul     s3, s3, t0
    ld      s4, 0(s0)
    ld      s5, 8(s0)
    ld      t0, 0(s1)
    ld      t1, 8(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5
    xor     t2, t2, t3
    add     s3, s3, t2
    ld      s4, 16(s0)
    ld      s5, 24(s0)
    ld      t0, 16(s1)
    ld      t1, 24(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5
    xor     t2, t2, t3
    add     s3, s3, t2
    ld      s4, 32(s0)
    ld      s5, 40(s0)
    ld      t0, 32(s1)
    ld      t1, 40(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5
    xor     t2, t2, t3
    add     s3, s3, t2
    ld      s4, 48(s0)
    ld      s5, 56(s0)
    ld      t0, 48(s1)
    ld      t1, 56(s1)
    add     t0, t0, s2
    xor     s4, s4, t0
    sub     t1, t1, s2
    xor     s5, s5, t1
    mul     t2, s4, s5
    mulhu   t3, s4, s5
    xor     t2, t2, t3
    add     s3, s3, t2
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

.section .data
.align 3

# Profiling data structure - compatible with profiler
profiling_data:
    .dword 0              # call_count (not used in this benchmark, always 0)
    .dword 0              # total_cycles (not used in this benchmark, always 0)
    .dword 0              # total_program_cycles (filled by _start)
    .dword 0              # avg_cycles_per_call (not meaningful here)

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

.align 12
test_buffer:
    .space 256

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0