# MULHU Software Implementation Sweep Benchmark
# Tests performance impact of software MULHU vs hardware multiply
# Sweeps N ∈ {10000, 1000, 100, 10} for MULHU frequency

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter - number of MULs per MULHU (default)
#endif

// Keep total multiply operations (MUL + MULHU) constant across all configurations
// Total target = 1,000,000 multiply operations
#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

_start:
    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x10, OUTER_LOOPS          # Outer loop counter

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start cycle count
    csrr    x29, 0xB02                # minstret - start instruction count

outer_loop:
    li      x11, MULHU_INTERVAL - 1   # Inner loop counter (N-1 MULs + 1 MULHU = N total)

inner_loop:
    # Regular multiply operations
    mul     x12, x5, x6               # Regular multiply
    add     x7, x7, x12               # Accumulate result
    addi    x5, x5, 17                # Vary operand 1 (prime increment)
    xori    x6, x6, 0x5A              # Vary operand 2 (XOR pattern)

    addi    x11, x11, -1              # Decrement inner counter
    bnez    x11, inner_loop           # Continue inner loop

    # Call software MULHU implementation after N multiplies
    mv      a0, x5                    # First argument
    mv      a1, x6                    # Second argument
    call    __mulhu64_soft            # Call software MULHU
    add     x7, x7, a0                # Accumulate MULHU result

    # Update operands for next iteration
    addi    x5, x5, 23                # Vary operand 1 (different prime)
    xori    x6, x6, 0xA5              # Vary operand 2 (different XOR)

    addi    x10, x10, -1              # Decrement outer counter
    bnez    x10, outer_loop           # Continue outer loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end cycle count
    csrr    x31, 0xB02                # minstret - end instruction count

    # Write result to tohost to signal completion
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

# Software implementation of MULHU (64-bit unsigned high multiply)
# Input: a0 = multiplicand, a1 = multiplier
# Output: a0 = upper 64 bits of (a0 * a1)
# Clobbers: t0, t1, t2, t3, t4, t5, t6
__mulhu64_soft:
    srli    t1, a0, 32                # t1 = high(a0)
    li      t4, -1                    # t4 = 0xFFFFFFFFFFFFFFFF
    srli    t4, t4, 32                # t4 = 0x00000000FFFFFFFF (mask)
    and     t0, a0, t4                # t0 = low(a0)

    srli    t3, a1, 32                # t3 = high(a1)
    and     t2, a1, t4                # t2 = low(a1)

    mul     t4, t0, t2                # t4 = low(a0) * low(a1)
    mul     t5, t0, t3                # t5 = low(a0) * high(a1)
    mul     t6, t1, t2                # t6 = high(a0) * low(a1)
    mul     a0, t1, t3                # a0 = high(a0) * high(a1)

    srli    t0, t4, 32                # t0 = high half of (low*low)
    add     t5, t5, t0                # t5 += high(low*low)
    sltu    t0, t5, t0                # t0 = carry from addition

    add     t1, t5, t6                # t1 = t5 + t6
    sltu    t2, t1, t6                # t2 = carry from addition
    add     t0, t0, t2                # t0 += carry

    slli    t0, t0, 32                # t0 = carry << 32
    srli    t1, t1, 32                # t1 = high 32 bits of middle sum
    or      t0, t0, t1                # t0 = combined middle result
    add     a0, a0, t0                # a0 += middle contribution

    ret

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0