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

def generate_benchmark(name, mulhu_count, mul_count):
    """Generate benchmark with looped kernel using simplified profiling"""

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

    # Start section
    output.append(".section .text.init")
    output.append(".globl _start")
    output.append(".option norvc")
    output.append("")
    output.append("_start:")
    output.append("    # Initialize test data")
    output.append("    li      x10, 0x123456789ABCDEF0   # a0 = Test operand 1")
    output.append("    li      x11, 0x0FEDCBA987654321   # a1 = Test operand 2")
    output.append("    li      x12, 0                    # a2 = Accumulator for results")
    output.append(f"    li      x13, {TOTAL_ITERATIONS}          # a3 = outer loop counter")
    if mulhu_count > 0:
        output.append(f"    li      x14, 0                    # a4 = iteration counter for MULHU interval")
        output.append(f"    li      x15, {mulhu_interval}                # a5 = MULHU interval")
    output.append("")
    output.append("    # Initialize profiling counters")
    output.append("    li      x21, 0                    # s5 (x21) = mulhu_total_cycles")
    output.append("    li      x22, 0                    # s6 (x22) = mulhu_call_count")
    output.append("")
    output.append("    # Capture start performance counters")
    output.append("    csrr    x18, 0xB00                # s2 (x18) = mcycle - start cycle count")
    output.append("    csrr    x19, 0xB02                # s3 (x19) = minstret - start instruction count")
    output.append("")
    output.append("outer_loop:")

    # Generate kernel instructions (all NOPs except for the multiply operation)
    # Insert multiply operation in the middle of the kernel
    mul_position = KERNEL_SIZE // 2

    for i in range(KERNEL_SIZE):
        if i == mul_position:
            if mulhu_count > 0:
                # Conditional MUL/MULHU based on iteration counter
                output.append("    # Conditional MUL/MULHU")
                output.append("    remu    x16, x14, x15             # a6 = iteration % interval")
                output.append("    bnez    x16, use_mul")
                output.append("    # MULHU path (with profiling)")
                output.append("    csrr    x16, 0xB00                # a6 = Entry mcycle")
                output.append("    mulhu   x17, x10, x11             # a7 = MULHU result")
                output.append("    csrr    x20, 0xB00                # s4 = Exit mcycle")
                output.append("    sub     x20, x20, x16             # Delta cycles")
                output.append("    add     x21, x21, x20             # Accumulate mulhu_total_cycles")
                output.append("    addi    x22, x22, 1               # Increment mulhu_call_count")
                output.append("    add     x12, x12, x17             # Accumulate result")
                output.append("    j       after_mul")
                output.append("use_mul:")
                output.append("    # MUL path")
                output.append("    mul     x17, x10, x11             # a7 = MUL result")
                output.append("    add     x12, x12, x17             # Accumulate result")
                output.append("after_mul:")
            else:
                # Always MUL (no MULHU in this benchmark)
                output.append("    # MUL operation")
                output.append("    mul     x17, x10, x11             # a7 = result")
                output.append("    add     x12, x12, x17             # Accumulate result")
        else:
            # Fill with NOPs
            output.append("    nop")

    output.append("")
    output.append("    # Rotate operands to vary the multiplication pattern")
    output.append("    addi    x10, x10, 17              # Change operand slightly")
    output.append("    xori    x11, x11, 0x5A            # XOR pattern to vary bits")
    output.append("")
    if mulhu_count > 0:
        output.append("    # Increment iteration counter")
        output.append("    addi    x14, x14, 1")
        output.append("")
    output.append("    # Decrement loop counter and continue")
    output.append("    addi    x13, x13, -1")
    output.append("    bnez    x13, outer_loop")
    output.append("")
    output.append("    # Capture end performance counters")
    output.append("    csrr    x9, 0xB00                 # mcycle - end cycle count")
    output.append("    csrr    x10, 0xB02                # minstret - end instruction count")
    output.append("")
    output.append("    # Store profiling results in memory for extraction")
    output.append("    la      x8, profiling_data")
    output.append("    sd      x22, 0(x8)                # Store call_count (MULHU calls)")
    output.append("    sd      x21, 8(x8)                # Store total_cycles (MULHU cycles only)")
    output.append("    sub     x11, x9, x18              # Total program cycles (end - start)")
    output.append("    sd      x11, 16(x8)               # Store total_program_cycles")
    output.append("")
    output.append("    # Calculate average cycles per call: mulhu_total_cycles / mulhu_call_count")
    if mulhu_count > 0:
        output.append("    beqz    x22, skip_avg             # Avoid divide by zero")
        output.append("    div     x12, x21, x22")
        output.append("    sd      x12, 24(x8)               # Store avg_cycles_per_call")
        output.append("skip_avg:")
    else:
        output.append("    sd      zero, 24(x8)              # No MULHU, avg = 0")
    output.append("")
    output.append("    # Write result to tohost to signal completion")
    output.append("    la      x8, tohost")
    output.append("    li      x9, 1")
    output.append("    sd      x9, 0(x8)")
    output.append("")
    output.append("done:")
    output.append("    j       done")
    output.append("")

    # Data section
    output.append(".section .data")
    output.append(".align 3")
    output.append("profiling_data:")
    output.append("    .dword 0    # call_count")
    output.append("    .dword 0    # total_cycles")
    output.append("    .dword 0    # total_program_cycles")
    output.append("    .dword 0    # avg_cycles_per_call")
    output.append("")
    output.append(".section .tohost")
    output.append(".align 6")
    output.append("tohost:     .dword 0")
    output.append("fromhost:   .dword 0")

    return "\n".join(output)

def main():
    for name, (mulhu_count, mul_count) in MULHU_RATIOS.items():
        filename = f"sweep_mulhu_{name}.S"
        print(f"Generating {filename}...")
        print(f"  MULHU: {mulhu_count}, MUL: {mul_count}")
        print(f"  MULHU interval: every {TOTAL_ITERATIONS // mulhu_count if mulhu_count > 0 else 'N/A'} iterations")

        content = generate_benchmark(name, mulhu_count, mul_count)

        with open(filename, 'w') as f:
            f.write(content)

        print(f"  Completed!")

if __name__ == "__main__":
    main()