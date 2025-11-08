# Minimal XXH3 Test - Quick verification with 10 iterations
# Tests basic functionality without long runtime

.section .text.init
.globl _start
.option norvc

#define NUM_ITER 10

_start:
    # Initialize stack pointer
    li      sp, 0x84000000

    # Test 1: Raw mul128_fold64 (10 iterations)
    li      s8, 0x123456789ABCDEF0
    li      s9, 0xFEDCBA9876543210
    li      s5, NUM_ITER
    li      s7, 0
test1_loop:
    mul     a0, s8, s9
    mulhu   a1, s8, s9
    xor     a0, a0, a1
    xor     s7, s7, a0
    addi    s8, s8, 1
    addi    s9, s9, -1
    addi    s5, s5, -1
    bnez    s5, test1_loop

    # Store result
    la      t0, result1
    sd      s7, 0(t0)

    # Test 2: Simple avalanche (10 iterations, MUL-only)
    li      s7, 0x123456789ABCDEF0
    li      t1, 0x9E3779F9
    li      s5, NUM_ITER
test2_loop:
    mul     s7, s7, t1
    srli    a0, s7, 32
    xor     s7, s7, a0
    addi    s5, s5, -1
    bnez    s5, test2_loop

    # Store result
    la      t0, result2
    sd      s7, 0(t0)

    # Exit successfully
    la      t0, tohost
    li      t1, 1
    sd      t1, 0(t0)

done:
    j       done

.section .data
.align 3
result1:    .dword 0
result2:    .dword 0

.align 6
tohost:     .dword 0
fromhost:   .dword 0
