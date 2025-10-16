# Hardware MULHU Single-Instruction Profiling
# Measures the latency of a single MULHU instruction
# This is the most direct comparison to software MULHU implementation

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 10000        // Number of MULHU operations to profile

_start:
    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x20, NUM_ITERATIONS       # Loop counter

    # Initialize profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_call_count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start cycle count
    csrr    x29, 0xB02                # minstret - start instruction count

test_loop:
    # Update operands to vary data patterns
    addi    x5, x5, 17                # Vary operand 1
    xori    x6, x6, 0x5A              # Vary operand 2

    # Profile single MULHU instruction
    csrr    x24, 0xB00                # Entry mcycle
    mulhu   x13, x5, x6               # ← HARDWARE MULHU (what we measure)
    csrr    x25, 0xB00                # Exit mcycle
    sub     x25, x25, x24             # Delta cycles
    add     x22, x22, x25             # Accumulate total cycles
    addi    x23, x23, 1               # Increment call count
    add     x7, x7, x13               # Accumulate result

    # Continue loop
    addi    x20, x20, -1
    bnez    x20, test_loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end cycle count
    csrr    x31, 0xB02                # minstret - end instruction count

    # Store profiling results in memory for extraction
    la      x8, profiling_data
    sd      x23, 0(x8)                # Store call_count
    sd      x22, 8(x8)                # Store total_cycles
    sub     x9, x30, x28              # Total program cycles
    sd      x9, 16(x8)                # Store total_program_cycles

    # Calculate average cycles per call: total_cycles / call_count
    div     x26, x22, x23
    sd      x26, 24(x8)               # Store avg_cycles_per_call

    # Calculate percentage: (mulhu_cycles * 100) / total_cycles
    li      x27, 100
    mul     x27, x22, x27
    div     x27, x27, x9
    sd      x27, 32(x8)               # Store percentage_of_total

    # Write result to tohost to signal completion
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