#!/usr/bin/env python3
"""
Generate a SMALL validation test (1000 iterations instead of 50,000)
Same dataflow/structure, just scaled down for quick validation
"""

import sys
sys.path.insert(0, '.')
from generate_sweep_final import *

# Override constants for small test
TOTAL_INSTRUCTIONS_SMALL = 200_000  # 1000 × 200
TOTAL_ITERATIONS_SMALL = 1000
TOTAL_MUL_INSTRUCTIONS_SMALL = 1000

def generate_small_test():
    """Generate small validation test with 1% MULHU ratio"""
    random.seed(42)
    
    mulhu_count = 10
    mul_count = 990
    mulhu_interval = TOTAL_ITERATIONS_SMALL // mulhu_count  # 100
    
    output = []
    output.append(f"# RISC-V Synthetic Benchmark - SMALL VALIDATION TEST")
    output.append(f"# Total instructions: {TOTAL_INSTRUCTIONS_SMALL:,}")
    output.append(f"# Kernel size: {KERNEL_SIZE}")
    output.append(f"# Loop iterations: {TOTAL_ITERATIONS_SMALL:,}")
    output.append(f"# MUL instructions: {mul_count:,}")
    output.append(f"# MULHU instructions: {mulhu_count:,}")
    output.append(f"# Multiplication percentage: 0.5000%")
    output.append(f"# MULHU/(MUL+MULHU) ratio: 1.0000%")
    output.append(f"# MULHU interval: every {mulhu_interval} iterations")
    output.append("")

    # Same structure as main benchmarks
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

    output.append(".section .text")
    output.append("benchmark_kernel:")
    output.append("    addi    sp, sp, -96")
    output.append("    sd      ra, 88(sp)")
    output.append("    sd      s0, 80(sp)")
    output.append("    sd      s1, 72(sp)")
    output.append("    sd      s6, 64(sp)")
    output.append("    sd      s7, 56(sp)")
    output.append("    sd      s8, 48(sp)")   # Save s8 for mulhu_call_count accumulator
    output.append("    sd      s9, 40(sp)")   # Save s9 for mulhu_total_cycles accumulator
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
    output.append(f"    li      s1, {TOTAL_ITERATIONS_SMALL}")
    output.append(f"    li      s6, 0         # Iteration counter")
    output.append(f"    li      s7, {mulhu_interval}  # MULHU interval")
    output.append(f"    li      s8, 0         # MULHU call_count accumulator")
    output.append(f"    li      s9, 0         # MULHU total_cycles accumulator")
    output.append("")
    output.append("loop_start:")
    output.append("    beqz    s1, loop_end")
    output.append("")

    # Generate kernel with same random instructions as full benchmarks
    mul_position = random.randint(0, KERNEL_SIZE - 10)

    for i in range(KERNEL_SIZE):
        if i == mul_position:
            output.append("    # Conditional MUL/MULHU with profiling")
            output.append(f"    remu    a0, s6, s7     # Check if iteration % interval == 0")
            output.append(f"    bnez    a0, use_mul_{i}")
            output.append("    # MULHU path with cycle counting (register accumulation)")
            output.append("    csrr    a0, 0xB00      # mcycle before MULHU")
            output.append(f"    mulhu   {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}")
            output.append("    csrr    a1, 0xB00      # mcycle after MULHU")
            output.append("    sub     a1, a1, a0     # Delta cycles")
            output.append("    add     s9, s9, a1     # Accumulate to total_cycles register")
            output.append("    addi    s8, s8, 1      # Increment call_count register")
            output.append(f"    j       after_mul_{i}")
            output.append(f"use_mul_{i}:")
            output.append("    # MUL path (no profiling)")
            output.append(f"    mul     {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}")
            output.append(f"after_mul_{i}:")
        else:
            output.append(f"    {generate_mixed_instruction()}")

    output.append("")
    output.append("    addi    s6, s6, 1")
    output.append("    addi    s1, s1, -1")
    output.append("    j       loop_start")
    output.append("")
    output.append("loop_end:")
    output.append("    # Store accumulated profiling data to memory")
    output.append("    la      a0, profiling_data")
    output.append("    sd      s8, 0(a0)        # Store call_count")
    output.append("    sd      s9, 8(a0)        # Store total_cycles")
    output.append("    ld      ra, 88(sp)")
    output.append("    ld      s0, 80(sp)")
    output.append("    ld      s1, 72(sp)")
    output.append("    ld      s6, 64(sp)")
    output.append("    ld      s7, 56(sp)")
    output.append("    ld      s8, 48(sp)")
    output.append("    ld      s9, 40(sp)")
    output.append("    addi    sp, sp, 96")
    output.append("    ret")
    output.append("")

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

if __name__ == "__main__":
    print("Generating small validation test...")
    content = generate_small_test()
    
    with open("validation_small.S", 'w') as f:
        f.write(content)
    
    print("Generated: validation_small.S")
    print("  200,000 instructions (1000 iterations × 200)")
    print("  10 MULHU, 990 MUL (1% MULHU ratio)")
