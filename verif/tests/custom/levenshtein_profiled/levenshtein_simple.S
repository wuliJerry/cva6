# Simple MULHU Benchmark - 1% MULHU ratio
# Mimics computational workload without complex algorithm
# Based on working mulhu_sweep.S structure

.section .text.init
.globl _start
.option norvc

# Configuration: 1% MULHU means 1 MULHU per 100 MULs
#define MUL_PER_MULHU 100
#define OUTER_LOOPS 200000            // Total: 200K MULHU, ~20M MUL, ~100M instructions

_start:
    // Initialize test data
    // Use a0-a7, s0-s11 to avoid conflict with MULHU expander (which uses t0-t6)
    li      a0, 0x123456789ABCDEF0   // Operand 1
    li      a1, 0x0FEDCBA987654321   // Operand 2
    li      a2, 0                    // Accumulator
    li      a3, OUTER_LOOPS          // Outer loop counter
    li      s4, MUL_PER_MULHU - 1    // Inner loop constant (99 MULs)

    // Initialize profiling counters
    li      s5, 0                    // s5 = mulhu_total_cycles
    li      s6, 0                    // s6 = mulhu_call_count

    // Capture start performance counters
    csrr    s2, 0xB00                // s2 = mcycle_start
    csrr    s3, 0xB02                // s3 = minstret_start

outer_loop:
    // Inner loop: perform (MUL_PER_MULHU - 1) = 99 MUL operations
    mv      a4, s4                   // a4 = inner loop counter (99)

inner_loop:
    // Perform MUL operation
    mul     a5, a0, a1               // a5 = result
    add     a2, a2, a5               // Accumulate

    // Vary operands for realistic computation pattern
    addi    a0, a0, 17               // Change operand slightly
    xori    a1, a1, 0x5A             // XOR pattern

    // Inner loop control
    addi    a4, a4, -1
    bnez    a4, inner_loop

    // After 99 MULs, perform 1 profiled MULHU (this is the 1%)
    csrr    a4, 0xB00                // Entry mcycle
    mulhu   a6, a0, a1               // MULHU operation (measured)
    csrr    a5, 0xB00                // Exit mcycle
    sub     a5, a5, a4               // Delta cycles
    add     s5, s5, a5               // Accumulate mulhu_total_cycles
    addi    s6, s6, 1                // Increment mulhu_call_count
    add     a2, a2, a6               // Accumulate result

    // Restore entropy
    addi    a0, a0, 23
    xori    a1, a1, 0xA5

    // Outer loop control
    addi    a3, a3, -1
    bnez    a3, outer_loop

    // Capture end performance counters
    csrr    a7, 0xB00                // mcycle_end
    csrr    t1, 0xB02                // minstret_end

    // Store profiling results in memory
    la      a2, profiling_data
    sd      s6, 0(a2)                // call_count
    sd      s5, 8(a2)                // total_cycles
    sub     a3, a7, s2               // total_program_cycles
    sd      a3, 16(a2)               // total_program_cycles

    // Calculate average cycles per MULHU call
    div     a4, s5, s6
    sd      a4, 24(a2)               // avg_cycles_per_call

    // Don't write to offset 0x20 (percentage) - profiler calculates it automatically

    // Signal completion
    la      a2, tohost
    li      a3, 1
    sd      a3, 0(a2)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # +0x00: call_count
    .dword 0    # +0x08: total_cycles
    .dword 0    # +0x10: total_program_cycles
    .dword 0    # +0x18: avg_cycles_per_call

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0
