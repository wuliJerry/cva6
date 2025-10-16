# Hardware MULHU Parallel Independent Operations Profiling
# Measures throughput by executing independent MULHU operations
# This reveals if multiple MULHUs can execute in parallel (ILP)

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 1000         // Number of parallel groups to execute
#define PARALLEL_OPS 10             // Independent MULHUs per group

_start:
    # Initialize test data (10 independent pairs of operands)
    li      x5, 0x123456789ABCDEF0    # Operand pair 1a
    li      x6, 0x0FEDCBA987654321    # Operand pair 1b
    li      x10, 0x1111111111111111   # Operand pair 2a
    li      x11, 0x2222222222222222   # Operand pair 2b
    li      x12, 0x3333333333333333   # Operand pair 3a
    li      x13, 0x4444444444444444   # Operand pair 3b
    li      x14, 0x5555555555555555   # Operand pair 4a
    li      x15, 0x6666666666666666   # Operand pair 4b
    li      x16, 0x7777777777777777   # Operand pair 5a
    li      x17, 0x8888888888888888   # Operand pair 5b

    li      x7, 0                     # Accumulator
    li      x20, NUM_ITERATIONS       # Loop counter

    # Initialize profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_group_count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start cycle count
    csrr    x29, 0xB02                # minstret - start instruction count

test_loop:
    # Vary operands each iteration
    addi    x5, x5, 1
    addi    x10, x10, 2
    addi    x12, x12, 3
    addi    x14, x14, 5
    addi    x16, x16, 7

    # Profile group of INDEPENDENT MULHUs
    csrr    x24, 0xB00                # Entry mcycle

    # Group of 10 INDEPENDENT MULHU operations
    # No data dependencies - can execute in parallel if hardware supports it
    mulhu   x18, x5, x6               # Independent MULHU 1
    mulhu   x19, x10, x11             # Independent MULHU 2
    mulhu   x21, x12, x13             # Independent MULHU 3
    mulhu   x25, x14, x15             # Independent MULHU 4
    mulhu   x26, x16, x17             # Independent MULHU 5
    mulhu   x27, x6, x5               # Independent MULHU 6 (reversed operands)
    mulhu   x30, x11, x10             # Independent MULHU 7 (reversed)
    mulhu   x31, x13, x12             # Independent MULHU 8 (reversed)
    mulhu   x8, x15, x14              # Independent MULHU 9 (reversed)
    mulhu   x9, x17, x16              # Independent MULHU 10 (reversed)

    csrr    x25, 0xB00                # Exit mcycle (reuse x25, x18/x19 already used)

    # Calculate delta and accumulate
    sub     x4, x25, x24              # Delta cycles for group (use x4 as temp)
    add     x22, x22, x4              # Accumulate total cycles
    addi    x23, x23, 1               # Increment group count

    # Accumulate results (sum all outputs to keep compiler from optimizing out)
    add     x7, x7, x18
    add     x7, x7, x19
    add     x7, x7, x21
    add     x7, x7, x26
    add     x7, x7, x27
    add     x7, x7, x30
    add     x7, x7, x31
    add     x7, x7, x8
    add     x7, x7, x9

    # Continue loop
    addi    x20, x20, -1
    bnez    x20, test_loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end cycle count
    csrr    x31, 0xB02                # minstret - end instruction count

    # Store profiling results in memory
    la      x8, profiling_data
    sd      x23, 0(x8)                # Store group_count
    sd      x22, 8(x8)                # Store total_cycles
    sub     x9, x30, x28              # Total program cycles
    sd      x9, 16(x8)                # Store total_program_cycles

    # Calculate average cycles per GROUP (10 MULHUs)
    div     x26, x22, x23
    sd      x26, 24(x8)               # Store avg_cycles_per_group

    # Calculate average cycles per SINGLE MULHU (throughput)
    # avg_per_mulhu = avg_per_group / PARALLEL_OPS
    li      x27, PARALLEL_OPS
    div     x26, x26, x27
    sd      x26, 32(x8)               # Store avg_cycles_per_mulhu (throughput)

    # Calculate IPC-equivalent (MULHUs per cycle)
    # If avg_cycles_per_mulhu < 1, multiple MULHUs can execute per cycle
    # mulhu_per_cycle = PARALLEL_OPS / avg_per_group
    div     x4, x23, x22              # Approximate inverse (integer division)
    sd      x4, 40(x8)                # Store approximate throughput

    # Calculate percentage
    li      x27, 100
    mul     x27, x22, x27
    div     x27, x27, x9
    sd      x27, 48(x8)               # Store percentage_of_total

    # Write result to tohost
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # group_count
    .dword 0    # total_cycles
    .dword 0    # total_program_cycles
    .dword 0    # avg_cycles_per_group (10 MULHUs)
    .dword 0    # avg_cycles_per_mulhu (throughput if parallel)
    .dword 0    # mulhu_per_cycle (throughput metric)
    .dword 0    # percentage_of_total

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0