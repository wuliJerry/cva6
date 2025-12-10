#!/usr/bin/env python3
"""
Generate RISC-V assembly benchmarks with controlled MULHU_SOFT/MUL ratios.
This version replaces hardware MULHU with __mulhu64_soft function calls.

Based on generate_sweep_final.py but with software MULHU implementation.
"""

import sys
sys.path.insert(0, '/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep_profile')
from generate_sweep_final import *

def generate_benchmark_soft(name, mulhu_count, mul_count):
    """Generate benchmark with __mulhu64_soft calls instead of MULHU hardware"""

    # Calculate interval for MULHU insertion
    mulhu_interval = TOTAL_ITERATIONS // mulhu_count if mulhu_count > 0 else float('inf')

    output = []
    output.append(f"# RISC-V Synthetic Benchmark - MULHU_SOFT Sweep")
    output.append(f"# Generated benchmark: {name}")
    output.append(f"# Total instructions: {TOTAL_INSTRUCTIONS:,}")
    output.append(f"# Kernel size: {KERNEL_SIZE}")
    output.append(f"# Loop iterations: {TOTAL_ITERATIONS:,}")
    output.append(f"# MUL instructions: {mul_count:,}")
    output.append(f"# MULHU_SOFT calls: {mulhu_count:,}")
    output.append(f"# Multiplication percentage: 0.5000%")
    output.append(f"# MULHU_SOFT/(MUL+MULHU_SOFT) ratio: {mulhu_count/(mulhu_count+mul_count)*100:.4f}%")
    output.append(f"# MULHU_SOFT interval: every {mulhu_interval} iterations" if mulhu_count > 0 else "# No MULHU_SOFT")
    output.append("")

    # Profiling wrapper
    output.append(".section .text.init")
    output.append(".globl _start")
    output.append("_start:")
    output.append("    li      sp, 0x84000000")
    output.append("    la      s0, profiling_data")
    output.append("    sd      zero, 0(s0)")
    output.append("    sd      zero, 8(s0)")
    output.append("    sd      zero, 16(s0)")
    output.append("    sd      zero, 24(s0)")
    output.append("    csrr    s2, 0xB00")
    output.append("    csrr    s3, 0xB02")
    output.append("    call    benchmark_kernel")
    output.append("    csrr    s4, 0xB00")
    output.append("    csrr    s5, 0xB02")
    output.append("    # Profiling data already populated by benchmark_kernel")
    output.append("    # Just add total_program_cycles and avg_cycles_per_call")
    output.append("    la      s0, profiling_data")
    output.append("    sub     a0, s4, s2       # Total program cycles")
    output.append("    sd      a0, 16(s0)       # Store total_program_cycles")
    output.append("    # Calculate avg: total_cycles / call_count")
    output.append("    ld      a1, 8(s0)        # Load total_cycles")
    output.append("    ld      a2, 0(s0)        # Load call_count")
    output.append("    beqz    a2, skip_avg     # Avoid divide by zero")
    output.append("    div     a3, a1, a2       # avg = total / count")
    output.append("    sd      a3, 24(s0)       # Store avg_cycles_per_call")
    output.append("skip_avg:")
    output.append("    la      s0, tohost")
    output.append("    li      s1, 1")
    output.append("    sd      s1, 0(s0)")
    output.append("done:")
    output.append("    j       done")
    output.append("")

    # Benchmark kernel
    output.append(".section .text")
    output.append("benchmark_kernel:")
    output.append("    addi    sp, sp, -112")
    output.append("    sd      ra, 104(sp)")
    output.append("    sd      s0, 96(sp)")
    output.append("    sd      s1, 88(sp)")
    output.append("    sd      s6, 80(sp)")   # Save s6 for iteration counter
    output.append("    sd      s7, 72(sp)")   # Save s7 for mul interval
    output.append("    sd      s8, 64(sp)")   # Save s8 for mulhu_call_count accumulator
    output.append("    sd      s9, 56(sp)")   # Save s9 for mulhu_total_cycles accumulator
    output.append("    sd      s10, 48(sp)")  # Save s10 for temp profiling
    output.append("    sd      s11, 40(sp)")  # Save s11 for temp profiling
    output.append("")
    output.append("    addi    s0, sp, 1024")
    output.append("    li      t0, 123")
    output.append("    li      t1, 456")
    output.append("    li      t2, 789")
    output.append("    li      t3, 321")
    output.append("    li      t4, 654")
    output.append("    li      t5, 987")
    output.append("    li      t6, 111")
    output.append("")
    output.append(f"    li      s1, {TOTAL_ITERATIONS}")
    if mulhu_count > 0:
        output.append(f"    li      s6, 0         # Iteration counter")
        output.append(f"    li      s7, {mulhu_interval}  # MULHU_SOFT interval")
        output.append(f"    li      s8, 0         # MULHU_SOFT call_count accumulator")
        output.append(f"    li      s9, 0         # MULHU_SOFT total_cycles accumulator")
    output.append("")
    output.append("loop_start:")
    output.append("    beqz    s1, loop_end")
    output.append("")

    # Generate kernel instructions
    # Place the MUL/MULHU_SOFT at a random position in the kernel
    mul_position = random.randint(0, KERNEL_SIZE - 10)  # Leave room for modulo check

    for i in range(KERNEL_SIZE):
        if i == mul_position and mulhu_count > 0:
            # Insert conditional MUL/MULHU_SOFT with individual profiling
            output.append("    # Conditional MUL/MULHU_SOFT with profiling")
            # Use s10/s11 for temporary storage to avoid conflicts
            # s6, s7 are loop counters, s8, s9 are accumulators
            # a0-a3 will be clobbered by function call
            # t0-t6 are clobbered by __mulhu64_soft
            output.append(f"    remu    s10, s6, s7    # Check if iteration % interval == 0")
            output.append(f"    bnez    s10, use_mul_{i}")
            output.append("    # MULHU_SOFT path (no per-call profiling)")
            # Pick two random temp registers for operands
            reg1 = random.choice(TEMP_REGS)
            reg2 = random.choice(TEMP_REGS)
            output.append("    # Save registers that will be clobbered by __mulhu64_soft (like a trap handler)")
            output.append("    addi    sp, sp, -64")
            output.append("    sd      ra, 56(sp)")
            output.append("    sd      t0, 48(sp)")
            output.append("    sd      t1, 40(sp)")
            output.append("    sd      t2, 32(sp)")
            output.append("    sd      t3, 24(sp)")
            output.append("    sd      t4, 16(sp)")
            output.append("    sd      t5, 8(sp)")
            output.append("    sd      t6, 0(sp)")
            output.append("    # Prepare arguments and call __mulhu64_soft")
            output.append(f"    mv      a0, {reg1}         # First argument")
            output.append(f"    mv      a1, {reg2}         # Second argument")
            output.append("    call    __mulhu64_soft # Call software MULHU")
            output.append("    # Note: result in a0 is discarded (matching MUL behavior)")
            output.append("    # Restore saved registers")
            output.append("    ld      t6, 0(sp)")
            output.append("    ld      t5, 8(sp)")
            output.append("    ld      t4, 16(sp)")
            output.append("    ld      t3, 24(sp)")
            output.append("    ld      t2, 32(sp)")
            output.append("    ld      t1, 40(sp)")
            output.append("    ld      t0, 48(sp)")
            output.append("    ld      ra, 56(sp)")
            output.append("    addi    sp, sp, 64")
            output.append(f"    j       after_mul_{i}")
            output.append(f"use_mul_{i}:")
            output.append("    # MUL path (no profiling)")
            output.append(f"    mul     {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}")
            output.append(f"after_mul_{i}:")
        elif i == mul_position and mulhu_count == 0:
            # Always MUL (no profiling needed)
            output.append(f"    mul     {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}")
        else:
            output.append(f"    {generate_mixed_instruction()}")

    output.append("")
    if mulhu_count > 0:
        output.append("    addi    s6, s6, 1      # Increment iteration counter")
    output.append("    addi    s1, s1, -1")
    output.append("    j       loop_start")
    output.append("")
    output.append("loop_end:")
    if mulhu_count > 0:
        output.append("    # Store accumulated profiling data to memory")
        output.append("    la      a0, profiling_data")
        output.append("    sd      s8, 0(a0)        # Store call_count")
        output.append("    sd      s9, 8(a0)        # Store total_cycles")
    output.append("    ld      ra, 104(sp)")
    output.append("    ld      s0, 96(sp)")
    output.append("    ld      s1, 88(sp)")
    output.append("    ld      s6, 80(sp)")
    output.append("    ld      s7, 72(sp)")
    output.append("    ld      s8, 64(sp)")
    output.append("    ld      s9, 56(sp)")
    output.append("    ld      s10, 48(sp)")
    output.append("    ld      s11, 40(sp)")
    output.append("    addi    sp, sp, 112")
    output.append("    ret")
    output.append("")

    # Add __mulhu64_soft implementation
    output.append("# Software implementation of MULHU (64-bit unsigned high multiply)")
    output.append("# Input: a0 = multiplicand, a1 = multiplier")
    output.append("# Output: a0 = upper 64 bits of (a0 * a1)")
    output.append("# Clobbers: t0, t1, t2, t3, t4, t5, t6")
    output.append("__mulhu64_soft:")
    output.append("    srli    t1, a0, 32                # t1 = high(a0)")
    output.append("    li      t4, -1                    # t4 = 0xFFFFFFFFFFFFFFFF")
    output.append("    srli    t4, t4, 32                # t4 = 0x00000000FFFFFFFF (mask)")
    output.append("    and     t0, a0, t4                # t0 = low(a0)")
    output.append("")
    output.append("    srli    t3, a1, 32                # t3 = high(a1)")
    output.append("    and     t2, a1, t4                # t2 = low(a1)")
    output.append("")
    output.append("    mul     t4, t0, t2                # t4 = low(a0) * low(a1)")
    output.append("    mul     t5, t0, t3                # t5 = low(a0) * high(a1)")
    output.append("    mul     t6, t1, t2                # t6 = high(a0) * low(a1)")
    output.append("    mul     a0, t1, t3                # a0 = high(a0) * high(a1)")
    output.append("")
    output.append("    srli    t0, t4, 32                # t0 = high half of (low*low)")
    output.append("    add     t5, t5, t0                # t5 += high(low*low)")
    output.append("    sltu    t0, t5, t0                # t0 = carry from addition")
    output.append("")
    output.append("    add     t1, t5, t6                # t1 = t5 + t6")
    output.append("    sltu    t2, t1, t6                # t2 = carry from addition")
    output.append("    add     t0, t0, t2                # t0 += carry")
    output.append("")
    output.append("    slli    t0, t0, 32                # t0 = carry << 32")
    output.append("    srli    t1, t1, 32                # t1 = high 32 bits of middle sum")
    output.append("    or      t0, t0, t1                # t0 = combined middle result")
    output.append("    add     a0, a0, t0                # a0 += middle contribution")
    output.append("")
    output.append("    ret")
    output.append("")

    # Data section
    output.append(".section .data")
    output.append(".align 3")
    output.append("profiling_data:")
    output.append("    .dword 0")
    output.append("    .dword 0")
    output.append("    .dword 0")
    output.append("    .dword 0")
    output.append("")
    output.append(".section .tohost")
    output.append(".align 6")
    output.append("tohost:     .dword 0")
    output.append("fromhost:   .dword 0")

    return "\n".join(output)

def main():
    for name, (mulhu_count, mul_count) in MULHU_RATIOS.items():
        random.seed(42)  # Reset seed for each benchmark for consistency
        filename = f"sweep_mulhu_soft_{name}.S"
        print(f"Generating {filename}...")
        print(f"  MULHU_SOFT: {mulhu_count}, MUL: {mul_count}")

        content = generate_benchmark_soft(name, mulhu_count, mul_count)

        with open(filename, 'w') as f:
            f.write(content)

        print(f"  Completed!")

if __name__ == "__main__":
    main()