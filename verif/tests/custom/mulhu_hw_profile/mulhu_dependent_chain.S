# Hardware MULHU Dependent Chain Profiling
# Measures latency by creating dependent MULHU operations
# This reveals true instruction latency (critical path delay)

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 1000         // Number of chains to execute
#define CHAIN_LENGTH 10             // MULHUs per chain

_start:
    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Initial operand 1
    li      x6, 0x0FEDCBA987654321    # Initial operand 2
    li      x7, 0                     # Accumulator
    li      x20, NUM_ITERATIONS       # Outer loop counter

    # Initialize profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_chain_count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start cycle count
    csrr    x29, 0xB02                # minstret - start instruction count

test_loop:
    # Vary initial values each iteration
    addi    x5, x5, 17
    xori    x6, x6, 0xA5

    # Profile a chain of DEPENDENT MULHUs
    csrr    x24, 0xB00                # Entry mcycle

    # Chain of 10 dependent MULHU operations
    # Each MULHU depends on the result of the previous one
    mulhu   x13, x5, x6               # MULHU 1: result → x13
    mulhu   x14, x13, x6              # MULHU 2: depends on x13
    mulhu   x15, x14, x6              # MULHU 3: depends on x14
    mulhu   x16, x15, x6              # MULHU 4: depends on x15
    mulhu   x17, x16, x6              # MULHU 5: depends on x16
    mulhu   x18, x17, x6              # MULHU 6: depends on x17
    mulhu   x19, x18, x6              # MULHU 7: depends on x18
    mulhu   x10, x19, x6              # MULHU 8: depends on x19
    mulhu   x11, x10, x6              # MULHU 9: depends on x10
    mulhu   x12, x11, x6              # MULHU 10: depends on x11

    csrr    x25, 0xB00                # Exit mcycle

    # Calculate delta and accumulate
    sub     x25, x25, x24             # Delta cycles for chain
    add     x22, x22, x25             # Accumulate total cycles
    addi    x23, x23, 1               # Increment chain count
    add     x7, x7, x12               # Accumulate final result

    # Continue loop
    addi    x20, x20, -1
    bnez    x20, test_loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end cycle count
    csrr    x31, 0xB02                # minstret - end instruction count

    # Store profiling results in memory
    la      x8, profiling_data
    sd      x23, 0(x8)                # Store chain_count
    sd      x22, 8(x8)                # Store total_cycles
    sub     x9, x30, x28              # Total program cycles
    sd      x9, 16(x8)                # Store total_program_cycles

    # Calculate average cycles per CHAIN (10 MULHUs)
    div     x26, x22, x23
    sd      x26, 24(x8)               # Store avg_cycles_per_chain

    # Calculate average cycles per SINGLE MULHU
    # avg_per_mulhu = avg_per_chain / CHAIN_LENGTH
    li      x27, CHAIN_LENGTH
    div     x26, x26, x27
    sd      x26, 32(x8)               # Store avg_cycles_per_mulhu

    # Calculate percentage
    li      x27, 100
    mul     x27, x22, x27
    div     x27, x27, x9
    sd      x27, 40(x8)               # Store percentage_of_total

    # Write result to tohost
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # chain_count
    .dword 0    # total_cycles
    .dword 0    # total_program_cycles
    .dword 0    # avg_cycles_per_chain (10 MULHUs)
    .dword 0    # avg_cycles_per_mulhu (single MULHU latency)
    .dword 0    # percentage_of_total

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0