# CSR Overhead Calibration Benchmark
# Measures the overhead of CSR read operations and instrumentation
# This allows us to subtract the measurement overhead from MULHU measurements

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 10000        // Number of calibration measurements

_start:
    li      x20, NUM_ITERATIONS       # Loop counter

    # Initialize profiling counters
    li      x22, 0                    # Total cycles measured
    li      x23, 0                    # Measurement count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start
    csrr    x29, 0xB02                # minstret - start

calibration_loop:
    # Measure the overhead of: csrr + nop + csrr + sub + add + addi
    # This is exactly what we do around MULHU, but with NOP instead
    csrr    x24, 0xB00                # Entry mcycle
    nop                                # ← Placeholder (no real work)
    csrr    x25, 0xB00                # Exit mcycle
    sub     x25, x25, x24             # Delta cycles
    add     x22, x22, x25             # Accumulate
    addi    x23, x23, 1               # Count

    addi    x20, x20, -1
    bnez    x20, calibration_loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end
    csrr    x31, 0xB02                # minstret - end

    # Store results
    la      x8, profiling_data
    sd      x23, 0(x8)                # measurement_count
    sd      x22, 8(x8)                # total_overhead_cycles
    sub     x9, x30, x28              # Total program cycles
    sd      x9, 16(x8)                # total_program_cycles

    # Calculate average overhead per measurement
    div     x26, x22, x23
    sd      x26, 24(x8)               # avg_overhead_per_measurement

    # Store total instructions
    sub     x27, x31, x29
    sd      x27, 32(x8)               # total_instructions

    # Calculate overhead percentage
    li      x4, 100
    mul     x4, x22, x4
    div     x4, x4, x9
    sd      x4, 40(x8)                # percentage_of_total

    # Write result to tohost
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # measurement_count
    .dword 0    # total_overhead_cycles
    .dword 0    # total_program_cycles
    .dword 0    # avg_overhead_per_measurement
    .dword 0    # total_instructions
    .dword 0    # percentage_of_total

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0