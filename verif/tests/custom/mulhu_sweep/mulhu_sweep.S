# Hardware MULHU Frequency Sweep Benchmark
# Measures performance impact of MULHU instruction frequency
# Performs N MUL operations between each MULHU to vary MULHU frequency

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter: 1 MULHU every N MULs (default)
#endif

// Keep total multiply operations (MUL + MULHU) constant across all configurations
// Total target = 1,000,000 multiply operations
// Each outer iteration does: MULHU_INTERVAL MULs + 1 MULHU
#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

_start:
    // Initialize test data
    // Note: Use a0-a7 (x10-x17) and s-registers to avoid conflict with MULHU expander
    // MULHU expander clobbers t0-t6 (x5-x7, x28-x31)
    li      x10, 0x123456789ABCDEF0   // a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   // a1 = Test operand 2
    li      x12, 0                    // a2 = Accumulator for results
    li      x13, OUTER_LOOPS          // a3 = outer loop counter
    li      x20, MULHU_INTERVAL - 1   // s4 = inner loop constant

    // Initialize profiling counters
    li      x21, 0                    // s5 (x21) = mulhu_total_cycles
    li      x22, 0                    // s6 (x22) = mulhu_call_count

    // Capture start performance counters
    csrr    x18, 0xB00                // s2 (x18) = mcycle - start cycle count
    csrr    x19, 0xB02                // s3 (x19) = minstret - start instruction count

outer_loop:
    // Inner loop: perform (MULHU_INTERVAL - 1) MUL operations
    mv      x14, x20                  // a4 = inner loop counter

inner_loop:
    // Perform MUL operations
    mul     x15, x10, x11             // a5 = result
    add     x12, x12, x15             // Accumulate result

    // Rotate operands to vary the multiplication pattern
    addi    x10, x10, 17              // Change operand slightly
    xori    x11, x11, 0x5A            // XOR pattern to vary bits

    // Decrement inner loop counter and continue
    addi    x14, x14, -1
    bnez    x14, inner_loop

    // After MULHU_INTERVAL MULs, perform one profiled MULHU
    csrr    x14, 0xB00                // a4 = Entry mcycle
    mulhu   x16, x10, x11             // a6 = MULHU result (measured instruction)
    csrr    x15, 0xB00                // a5 = Exit mcycle
    sub     x15, x15, x14             // Delta cycles
    add     x21, x21, x15             // Accumulate mulhu_total_cycles
    addi    x22, x22, 1               // Increment mulhu_call_count
    add     x12, x12, x16             // Accumulate result

    // Restore some entropy to operands
    addi    x10, x10, 23
    xori    x11, x11, 0xA5

    // Decrement outer loop counter and continue
    addi    x13, x13, -1
    bnez    x13, outer_loop

    // Capture end performance counters
    csrr    x9, 0xB00                 // mcycle - end cycle count
    csrr    x10, 0xB02                // minstret - end instruction count

    // Store profiling results in memory for extraction
    la      x8, profiling_data
    sd      x22, 0(x8)                // Store call_count (MULHU calls)
    sd      x21, 8(x8)                // Store total_cycles (MULHU cycles only)
    sub     x11, x9, x18              // Total program cycles (end - start)
    sd      x11, 16(x8)               // Store total_program_cycles

    // Calculate average cycles per call: mulhu_total_cycles / mulhu_call_count
    div     x12, x21, x22
    sd      x12, 24(x8)               // Store avg_cycles_per_call

    // Calculate percentage: (mulhu_cycles * 100) / total_program_cycles
    li      x13, 100
    mul     x13, x21, x13
    div     x13, x13, x11
    sd      x13, 32(x8)               // Store percentage_of_total

    // Write result to tohost to signal completion
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # call_count
    .dword 0    # total_cycles
    .dword 0    # total_program_cycles
    .dword 0    # avg_cycles_per_call
    .dword 0    # percentage_of_total

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0