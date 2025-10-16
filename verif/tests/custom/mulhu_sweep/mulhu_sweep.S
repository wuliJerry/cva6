// Copyright 2025 RISC-V Performance Analysis
// SPDX-License-Identifier: Apache-2.0
//
// Synthetic Benchmark: MULHU Frequency Sweep
//
// Description:
//   Tight loop performing MUL instructions with periodic MULHU operations
//   to measure performance impact of MULHU instruction frequency
//
// Configuration:
//   MULHU_INTERVAL: Number of MUL operations between each MULHU
//   Total iterations designed to keep total instruction count ~constant
//
// For N=10000: ~0.01% MULHU frequency (1 MULHU per 10000 MUL)

#include "encoding.h"

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter: 1 MULHU every N MULs (default)
#endif

// Keep total multiply operations (MUL + MULHU) constant across all configurations
// Total target = 1,000,000 multiply operations
// Each outer iteration does: MULHU_INTERVAL MULs + 1 MULHU
#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

    .section .text.init
    .globl _start
    .type _start, @function

_start:
    // Initialize registers with non-zero test values
    li      x5, 0x123456789ABCDEF0    // Test operand 1
    li      x6, 0x0FEDCBA987654321    // Test operand 2
    li      x7, 0                     // Accumulator for results (prevent optimization)
    li      x10, OUTER_LOOPS          // x10 = outer loop counter
    li      x20, MULHU_INTERVAL - 1   // x20 = inner loop constant (s4 register)

    // Read initial mcycle
    csrr    x28, mcycle               // x28 = start cycle count
    csrr    x29, minstret             // x29 = start instruction count

outer_loop:
    // Inner loop: perform (MULHU_INTERVAL - 1) MUL operations
    // This keeps total MUL+MULHU count at exactly 1 million
    mv      x11, x20                  // Reload inner loop counter (1 instruction always!)

inner_loop:
    // Perform MUL operations
    // Use results to prevent compiler optimization
    mul     x12, x5, x6               // Regular multiply
    add     x7, x7, x12               // Accumulate result

    // Rotate operands to vary the multiplication pattern
    addi    x5, x5, 17                // Change operand slightly
    xori    x6, x6, 0x5A              // XOR pattern to vary bits

    // Decrement inner loop counter and continue
    addi    x11, x11, -1
    bnez    x11, inner_loop

    // After MULHU_INTERVAL MULs, perform one MULHU
    mulhu   x13, x5, x6               // High multiply unsigned
    add     x7, x7, x13               // Accumulate result

    // Restore some entropy to operands
    addi    x5, x5, 23
    xori    x6, x6, 0xA5              // XOR pattern (12-bit immediate)

    // Decrement outer loop counter and continue
    addi    x10, x10, -1
    bnez    x10, outer_loop

    // Read final mcycle
    csrr    x30, mcycle               // x30 = end cycle count
    csrr    x31, minstret             // x31 = end instruction count

    // Calculate deltas
    sub     x28, x30, x28             // x28 = total cycles
    sub     x29, x31, x29             // x29 = total instructions

    // Store results to prevent optimization
    // Use x7 (accumulator) to ensure calculations aren't optimized away
    la      x14, result_accumulator
    sd      x7, 0(x14)
    sd      x28, 8(x14)               // Store cycle count
    sd      x29, 16(x14)              // Store instruction count

    // Write to tohost to signal completion
    li      x15, 1
    la      x14, tohost
    sd      x15, 0(x14)

    // Infinite loop (should not reach here)
done:
    j       done

    .section .tohost
    .align 6
    .globl tohost
tohost:
    .dword 0
    .globl fromhost
fromhost:
    .dword 0

    .section .data
    .align 3
result_accumulator:
    .dword 0                          // Result accumulator
    .dword 0                          // Cycle count
    .dword 0                          // Instruction count

    .section .rodata
benchmark_info:
    .string "MULHU Sweep Benchmark: N=10000 (0.01% MULHU)\n"