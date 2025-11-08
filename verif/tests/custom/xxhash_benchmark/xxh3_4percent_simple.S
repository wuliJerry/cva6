# XXH3 Benchmark with 4% MULHU Ratio - Simplified (No HPM)
# Removed all CSR profiling to debug AXI errors

.section .text.init
.globl _start
.option norvc

# Configuration for 4% MULHU ratio
#define NUM_ITER_BENCH1 100
#define NUM_ITER_BENCH2 1000
#define NUM_ITER_BENCH3 100
#define NUM_ITER_BENCH4 3330

# xxHash3 constants
#define PRIME_MX1_LO 0x9E3779F9
#define PRIME_MX1_HI 0x16566791

_start:
    # Benchmark 1: mul128_fold64 (100 iter = 100 MULHU, 100 MUL)
    la      s11, profiling_mul128
    li      s6, 0
    li      s7, 0
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
    li      t0, NUM_ITER_BENCH1
    sd      t0, 0(s11)
    sd      s6, 8(s11)
    sd      s7, 16(s11)

    # Benchmark 2: XXH3 16-byte (1000 iter = 1000 MULHU, 2000 MUL)
    la      s11, profiling_16byte
    li      s6, 0
    li      s7, 0
    li      s5, NUM_ITER_BENCH2
bench2_loop:
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5
    call    xxh3_16bytes
    xor     s7, s7, a0
    addi    s5, s5, -1
    bnez    s5, bench2_loop
    li      t0, NUM_ITER_BENCH2
    sd      t0, 0(s11)
    sd      s6, 8(s11)
    sd      s7, 16(s11)

    # Benchmark 3: XXH3 64-byte (100 iter = 400 MULHU, 600 MUL)
    la      s11, profiling_64byte
    li      s6, 0
    li      s7, 0
    li      s5, NUM_ITER_BENCH3
bench3_loop:
    la      a0, test_buffer
    la      a1, kSecret
    mv      a2, s5
    call    xxh3_64bytes
    xor     s7, s7, a0
    addi    s5, s5, -1
    bnez    s5, bench3_loop
    li      t0, NUM_ITER_BENCH3
    sd      t0, 0(s11)
    sd      s6, 8(s11)
    sd      s7, 16(s11)

    # Benchmark 4: Avalanche-style mixing (3330 iter, 0 MULHU, 33300 MUL)
    la      s11, profiling_avalanche
    li      s6, 0
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
    li      t0, NUM_ITER_BENCH4
    sd      t0, 0(s11)
    sd      s6, 8(s11)
    sd      s7, 16(s11)

    # Exit
    la      t0, tohost
    li      t1, 1
    sd      t1, 0(t0)
done:
    j       done

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

profiling_mul128:
    .dword 0, 0, 0, 0

profiling_16byte:
    .dword 0, 0, 0

profiling_64byte:
    .dword 0, 0, 0

profiling_avalanche:
    .dword 0, 0, 0

.align 12
test_buffer:
    .space 256

.align 6
tohost:     .dword 0
fromhost:   .dword 0