#!/usr/bin/env python3
"""
Generate RISC-V assembly benchmarks with controlled MULHU/MUL ratios.

Correct approach:
- Fixed 200-instruction kernel
- Loop 50,000 times → 10M total instructions
- Each kernel has 1 MUL or 1 MULHU (0.5% of 200)
- Use counter modulo to determine when to use MULHU vs MUL
- Example: For 0.01% MULHU ratio → MULHU every 10,000 iterations
"""

import random

# Configuration
TOTAL_INSTRUCTIONS = 10_000_000
KERNEL_SIZE = 200
TOTAL_ITERATIONS = 50_000  # 50K × 200 = 10M
TOTAL_MUL_INSTRUCTIONS = 50_000  # One per iteration

# MULHU ratios: MULHU/(MUL+MULHU)
MULHU_RATIOS = {
    "0.01pct": (5, 49995),      # 5 MULHU, 49,995 MUL
    "0.05pct": (25, 49975),     # 25 MULHU, 49,975 MUL
    "0.1pct": (50, 49950),      # 50 MULHU, 49,950 MUL
    "1.0pct": (500, 49500),     # 500 MULHU, 49,500 MUL
    "5.0pct": (2500, 47500),    # 2,500 MULHU, 47,500 MUL
    "10.0pct": (5000, 45000),   # 5,000 MULHU, 45,000 MUL
}

# Registers
TEMP_REGS = ['t0', 't1', 't2', 't3', 't4', 't5', 't6']
BASE_REG = 's0'

def generate_alu_instruction():
    ops = [
        lambda: f"add {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"sub {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"addi {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(-2048, 2047)}",
    ]
    return random.choice(ops)()

def generate_logic_instruction():
    ops = [
        lambda: f"and {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"or {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"xor {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"andi {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(0, 2047)}",
        lambda: f"ori {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(0, 2047)}",
        lambda: f"xori {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(-2048, 2047)}",
    ]
    return random.choice(ops)()

def generate_shift_instruction():
    ops = [
        lambda: f"sll {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"srl {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"sra {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"slli {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(0, 31)}",
        lambda: f"srli {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(0, 31)}",
        lambda: f"srai {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(0, 31)}",
    ]
    return random.choice(ops)()

def generate_compare_instruction():
    ops = [
        lambda: f"slt {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"sltu {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}",
        lambda: f"slti {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.randint(-2048, 2047)}",
    ]
    return random.choice(ops)()

def generate_memory_instruction():
    offset = random.randint(0, 1020) & ~0x7
    ops = [
        lambda: f"lw {random.choice(TEMP_REGS)}, {offset}({BASE_REG})",
        lambda: f"sw {random.choice(TEMP_REGS)}, {offset}(sp)",
    ]
    return random.choice(ops)()

def generate_mixed_instruction():
    instruction_pool = (
        [generate_alu_instruction] * 40 +
        [generate_logic_instruction] * 25 +
        [generate_shift_instruction] * 15 +
        [generate_compare_instruction] * 10 +
        [generate_memory_instruction] * 10
    )
    return random.choice(instruction_pool)()

def generate_benchmark(name, mulhu_count, mul_count):
    """Generate benchmark with looped kernel"""

    # Calculate interval for MULHU insertion
    # If we need 5 MULHU in 50,000 iterations → every 10,000 iterations
    mulhu_interval = TOTAL_ITERATIONS // mulhu_count if mulhu_count > 0 else float('inf')

    output = []
    output.append(f"# RISC-V Synthetic Benchmark - MULHU Sweep")
    output.append(f"# Generated benchmark: {name}")
    output.append(f"# Total instructions: {TOTAL_INSTRUCTIONS:,}")
    output.append(f"# Kernel size: {KERNEL_SIZE}")
    output.append(f"# Loop iterations: {TOTAL_ITERATIONS:,}")
    output.append(f"# MUL instructions: {mul_count:,}")
    output.append(f"# MULHU instructions: {mulhu_count:,}")
    output.append(f"# Multiplication percentage: 0.5000%")
    output.append(f"# MULHU/(MUL+MULHU) ratio: {mulhu_count/(mulhu_count+mul_count)*100:.4f}%")
    output.append(f"# MULHU interval: every {mulhu_interval} iterations" if mulhu_count > 0 else "# No MULHU")
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
    output.append("    addi    sp, sp, -96")
    output.append("    sd      ra, 88(sp)")
    output.append("    sd      s0, 80(sp)")
    output.append("    sd      s1, 72(sp)")
    output.append("    sd      s6, 64(sp)")   # Save s6 for iteration counter
    output.append("    sd      s7, 56(sp)")   # Save s7 for mul interval
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
    output.append(f"    li      s1, {TOTAL_ITERATIONS}")
    if mulhu_count > 0:
        output.append(f"    li      s6, 0         # Iteration counter")
        output.append(f"    li      s7, {mulhu_interval}  # MULHU interval")
        output.append(f"    li      s8, 0         # MULHU call_count accumulator")
        output.append(f"    li      s9, 0         # MULHU total_cycles accumulator")
    output.append("")
    output.append("loop_start:")
    output.append("    beqz    s1, loop_end")
    output.append("")

    # Generate kernel instructions
    # Place the MUL/MULHU at a random position in the kernel
    mul_position = random.randint(0, KERNEL_SIZE - 10)  # Leave room for modulo check

    for i in range(KERNEL_SIZE):
        if i == mul_position and mulhu_count > 0:
            # Insert conditional MUL/MULHU (no per-call profiling)
            output.append("    # Conditional MUL/MULHU (no per-call profiling)")
            output.append(f"    remu    a0, s6, s7     # Check if iteration % interval == 0")
            output.append(f"    bnez    a0, use_mul_{i}")
            output.append("    # MULHU path (no cycle counting)")
            output.append(f"    mulhu   {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}, {random.choice(TEMP_REGS)}")
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
        filename = f"sweep_mulhu_{name}.S"
        print(f"Generating {filename}...")
        print(f"  MULHU: {mulhu_count}, MUL: {mul_count}")

        content = generate_benchmark(name, mulhu_count, mul_count)

        with open(filename, 'w') as f:
            f.write(content)

        print(f"  Completed!")

if __name__ == "__main__":
    main()