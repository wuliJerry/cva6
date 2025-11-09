#!/usr/bin/env python3
"""
Generate RISC-V assembly benchmarks with controlled MULHU_SOFT/MUL ratios.
Uses simplified approach with NOPs and software MULHU implementation.

Approach:
- Fixed 200-instruction kernel with NOPs
- Loop 50,000 times → 10M total instructions
- Each kernel has 1 MUL or 1 MULHU_SOFT (0.5% of 200)
- Use counter modulo to determine when to use MULHU_SOFT vs MUL
- Example: For 0.01% MULHU_SOFT ratio → MULHU_SOFT every 10,000 iterations
"""

# Configuration
TOTAL_INSTRUCTIONS = 10_000_000
KERNEL_SIZE = 200
TOTAL_ITERATIONS = 50_000  # 50K × 200 = 10M
TOTAL_MUL_INSTRUCTIONS = 50_000  # One per iteration

# MULHU_SOFT ratios: MULHU_SOFT/(MUL+MULHU_SOFT)
MULHU_RATIOS = {
    "0.01pct": (5, 49995),      # 5 MULHU_SOFT, 49,995 MUL
    "0.05pct": (25, 49975),     # 25 MULHU_SOFT, 49,975 MUL
    "0.1pct": (50, 49950),      # 50 MULHU_SOFT, 49,950 MUL
    "1.0pct": (500, 49500),     # 500 MULHU_SOFT, 49,500 MUL
    "5.0pct": (2500, 47500),    # 2,500 MULHU_SOFT, 47,500 MUL
    "10.0pct": (5000, 45000),   # 5,000 MULHU_SOFT, 45,000 MUL
}

def generate_mulhu_soft_implementation():
    """Generate the software MULHU implementation"""
    impl = []
    impl.append("# Software implementation of MULHU (unsigned 64-bit multiplication high)")
    impl.append("# Input: a0, a1 (64-bit operands)")
    impl.append("# Output: a0 (high 64 bits of a0 * a1)")
    impl.append("# Clobbers: t0-t6")
    impl.append("__mulhu64_soft:")
    impl.append("    srli    t1, a0, 32                # t1 = high(a0)")
    impl.append("    li      t4, -1                    # t4 = 0xFFFFFFFFFFFFFFFF")
    impl.append("    srli    t4, t4, 32                # t4 = 0x00000000FFFFFFFF (mask)")
    impl.append("    and     t0, a0, t4                # t0 = low(a0)")
    impl.append("")
    impl.append("    srli    t3, a1, 32                # t3 = high(a1)")
    impl.append("    and     t2, a1, t4                # t2 = low(a1)")
    impl.append("")
    impl.append("    mul     t4, t0, t2                # t4 = low(a0) * low(a1)")
    impl.append("    mul     t5, t0, t3                # t5 = low(a0) * high(a1)")
    impl.append("    mul     t6, t1, t2                # t6 = high(a0) * low(a1)")
    impl.append("    mul     a0, t1, t3                # a0 = high(a0) * high(a1)")
    impl.append("")
    impl.append("    srli    t0, t4, 32                # t0 = high half of (low*low)")
    impl.append("    add     t5, t5, t0                # t5 += high(low*low)")
    impl.append("    sltu    t0, t5, t0                # t0 = carry from addition")
    impl.append("")
    impl.append("    add     t1, t5, t6                # t1 = t5 + t6")
    impl.append("    sltu    t2, t1, t6                # t2 = carry from addition")
    impl.append("    add     t0, t0, t2                # t0 += carry")
    impl.append("")
    impl.append("    slli    t0, t0, 32                # t0 = carry << 32")
    impl.append("    srli    t1, t1, 32                # t1 = high 32 bits of middle sum")
    impl.append("    or      t0, t0, t1                # t0 = combined middle result")
    impl.append("    add     a0, a0, t0                # a0 += middle contribution")
    impl.append("")
    impl.append("    ret")
    impl.append("")
    return "\n".join(impl)

def generate_benchmark(name, mulhu_count, mul_count):
    """Generate benchmark with looped kernel using simplified profiling and software MULHU"""

    # Calculate interval for MULHU_SOFT insertion
    # If we need 5 MULHU_SOFT in 50,000 iterations → every 10,000 iterations
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

    # Start section
    output.append(".section .text.init")
    output.append(".globl _start")
    output.append(".option norvc")
    output.append("")
    output.append("_start:")
    output.append("    # Initialize stack pointer")
    output.append("    li      sp, 0x84000000            # Set stack pointer to safe memory region")
    output.append("")
    output.append("    # Initialize test data")
    output.append("    li      x10, 0x123456789ABCDEF0   # a0 = Test operand 1")
    output.append("    li      x11, 0x0FEDCBA987654321   # a1 = Test operand 2")
    output.append("    li      x12, 0                    # a2 = Accumulator for results")
    output.append(f"    li      x13, {TOTAL_ITERATIONS}          # a3 = outer loop counter")
    if mulhu_count > 0:
        output.append(f"    li      x14, 0                    # a4 = iteration counter for MULHU_SOFT interval")
        output.append(f"    li      x15, {mulhu_interval}                # a5 = MULHU_SOFT interval")
    output.append("")
    output.append("    # Initialize profiling counters")
    output.append("    li      x21, 0                    # s5 (x21) = mulhu_soft_total_cycles")
    output.append("    li      x22, 0                    # s6 (x22) = mulhu_soft_call_count")
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
                # Conditional MUL/MULHU_SOFT based on iteration counter
                output.append("    # Conditional MUL/MULHU_SOFT")
                output.append("    remu    x16, x14, x15             # a6 = iteration % interval")
                output.append("    bnez    x16, use_mul")
                output.append("    # MULHU_SOFT path (with profiling)")
                output.append("    # Save registers that will be clobbered by __mulhu64_soft")
                output.append("    addi    sp, sp, -80")
                output.append("    sd      ra, 72(sp)")
                output.append("    sd      a0, 64(sp)")
                output.append("    sd      a1, 56(sp)")
                output.append("    sd      t0, 48(sp)")
                output.append("    sd      t1, 40(sp)")
                output.append("    sd      t2, 32(sp)")
                output.append("    sd      t3, 24(sp)")
                output.append("    sd      t4, 16(sp)")
                output.append("    sd      t5, 8(sp)")
                output.append("    sd      t6, 0(sp)")
                output.append("    # Prepare arguments and profile the call")
                output.append("    mv      a0, x10                   # First argument")
                output.append("    mv      a1, x11                   # Second argument")
                output.append("    csrr    x20, 0xB00                # s4 = Entry mcycle")
                output.append("    call    __mulhu64_soft            # Call software MULHU")
                output.append("    csrr    x16, 0xB00                # a6 = Exit mcycle")
                output.append("    sub     x16, x16, x20             # Delta cycles")
                output.append("    add     x21, x21, x16             # Accumulate mulhu_soft_total_cycles")
                output.append("    addi    x22, x22, 1               # Increment mulhu_soft_call_count")
                output.append("    mv      x17, a0                   # Save result")
                output.append("    # Restore saved registers")
                output.append("    ld      t6, 0(sp)")
                output.append("    ld      t5, 8(sp)")
                output.append("    ld      t4, 16(sp)")
                output.append("    ld      t3, 24(sp)")
                output.append("    ld      t2, 32(sp)")
                output.append("    ld      t1, 40(sp)")
                output.append("    ld      t0, 48(sp)")
                output.append("    ld      a1, 56(sp)")
                output.append("    ld      a0, 64(sp)")
                output.append("    ld      ra, 72(sp)")
                output.append("    addi    sp, sp, 80")
                output.append("    add     x12, x12, x17             # Accumulate result")
                output.append("    j       after_mul")
                output.append("use_mul:")
                output.append("    # MUL path")
                output.append("    mul     x17, x10, x11             # a7 = MUL result")
                output.append("    add     x12, x12, x17             # Accumulate result")
                output.append("after_mul:")
            else:
                # Always MUL (no MULHU_SOFT in this benchmark)
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
    output.append("    sd      x22, 0(x8)                # Store call_count (MULHU_SOFT calls)")
    output.append("    sd      x21, 8(x8)                # Store total_cycles (MULHU_SOFT cycles only)")
    output.append("    sub     x11, x9, x18              # Total program cycles (end - start)")
    output.append("    sd      x11, 16(x8)               # Store total_program_cycles")
    output.append("")
    output.append("    # Calculate average cycles per call: mulhu_soft_total_cycles / mulhu_soft_call_count")
    if mulhu_count > 0:
        output.append("    beqz    x22, skip_avg             # Avoid divide by zero")
        output.append("    div     x12, x21, x22")
        output.append("    sd      x12, 24(x8)               # Store avg_cycles_per_call")
        output.append("skip_avg:")
    else:
        output.append("    sd      zero, 24(x8)              # No MULHU_SOFT, avg = 0")
    output.append("")
    output.append("    # Write result to tohost to signal completion")
    output.append("    la      x8, tohost")
    output.append("    li      x9, 1")
    output.append("    sd      x9, 0(x8)")
    output.append("")
    output.append("done:")
    output.append("    j       done")
    output.append("")

    # Add software MULHU implementation (in same section to avoid AXI errors)
    output.append(generate_mulhu_soft_implementation())

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
        filename = f"sweep_mulhu_soft_{name}.S"
        print(f"Generating {filename}...")
        print(f"  MULHU_SOFT: {mulhu_count}, MUL: {mul_count}")
        print(f"  MULHU_SOFT interval: every {TOTAL_ITERATIONS // mulhu_count if mulhu_count > 0 else 'N/A'} iterations")

        content = generate_benchmark(name, mulhu_count, mul_count)

        with open(filename, 'w') as f:
            f.write(content)

        print(f"  Completed!")

if __name__ == "__main__":
    main()