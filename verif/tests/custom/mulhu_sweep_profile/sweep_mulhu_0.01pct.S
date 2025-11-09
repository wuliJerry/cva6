# RISC-V Synthetic Benchmark - MULHU Sweep
# Generated benchmark: 0.01pct
# Total instructions: 10,000,000
# Kernel size: 200
# Loop iterations: 50,000
# MUL instructions: 49,995
# MULHU instructions: 5
# Multiplication percentage: 0.5000%
# MULHU/(MUL+MULHU) ratio: 0.0100%
# MULHU interval: every 10000 iterations

.section .text.init
.globl _start
.option norvc

_start:
    # Initialize test data
    li      x10, 0x123456789ABCDEF0   # a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   # a1 = Test operand 2
    li      x12, 0                    # a2 = Accumulator for results
    li      x13, 50000          # a3 = outer loop counter
    li      x14, 0                    # a4 = iteration counter for MULHU interval
    li      x15, 10000                # a5 = MULHU interval

    # Initialize profiling counters
    li      x21, 0                    # s5 (x21) = mulhu_total_cycles
    li      x22, 0                    # s6 (x22) = mulhu_call_count

    # Capture start performance counters
    csrr    x18, 0xB00                # s2 (x18) = mcycle - start cycle count
    csrr    x19, 0xB02                # s3 (x19) = minstret - start instruction count

outer_loop:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    # Conditional MUL/MULHU
    remu    x16, x14, x15             # a6 = iteration % interval
    bnez    x16, use_mul
    # MULHU path (with profiling)
    csrr    x16, 0xB00                # a6 = Entry mcycle
    mulhu   x17, x10, x11             # a7 = MULHU result
    csrr    x20, 0xB00                # s4 = Exit mcycle
    sub     x20, x20, x16             # Delta cycles
    add     x21, x21, x20             # Accumulate mulhu_total_cycles
    addi    x22, x22, 1               # Increment mulhu_call_count
    add     x12, x12, x17             # Accumulate result
    j       after_mul
use_mul:
    # MUL path
    mul     x17, x10, x11             # a7 = MUL result
    add     x12, x12, x17             # Accumulate result
after_mul:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    # Rotate operands to vary the multiplication pattern
    addi    x10, x10, 17              # Change operand slightly
    xori    x11, x11, 0x5A            # XOR pattern to vary bits

    # Increment iteration counter
    addi    x14, x14, 1

    # Decrement loop counter and continue
    addi    x13, x13, -1
    bnez    x13, outer_loop

    # Capture end performance counters
    csrr    x9, 0xB00                 # mcycle - end cycle count
    csrr    x10, 0xB02                # minstret - end instruction count

    # Store profiling results in memory for extraction
    la      x8, profiling_data
    sd      x22, 0(x8)                # Store call_count (MULHU calls)
    sd      x21, 8(x8)                # Store total_cycles (MULHU cycles only)
    sub     x11, x9, x18              # Total program cycles (end - start)
    sd      x11, 16(x8)               # Store total_program_cycles

    # Calculate average cycles per call: mulhu_total_cycles / mulhu_call_count
    beqz    x22, skip_avg             # Avoid divide by zero
    div     x12, x21, x22
    sd      x12, 24(x8)               # Store avg_cycles_per_call
skip_avg:

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

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0