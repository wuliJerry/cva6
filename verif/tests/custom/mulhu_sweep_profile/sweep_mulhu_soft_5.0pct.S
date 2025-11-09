# RISC-V Synthetic Benchmark - MULHU_SOFT Sweep
# Generated benchmark: 5.0pct
# Total instructions: 10,000,000
# Kernel size: 200
# Loop iterations: 50,000
# MUL instructions: 47,500
# MULHU_SOFT calls: 2,500
# Multiplication percentage: 0.5000%
# MULHU_SOFT/(MUL+MULHU_SOFT) ratio: 5.0000%
# MULHU_SOFT interval: every 20 iterations

.section .text.init
.globl _start
.option norvc

_start:
    # Initialize stack pointer
    li      sp, 0x84000000            # Set stack pointer to safe memory region

    # Initialize test data
    li      x10, 0x123456789ABCDEF0   # a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   # a1 = Test operand 2
    li      x12, 0                    # a2 = Accumulator for results
    li      x13, 50000          # a3 = outer loop counter
    li      x14, 0                    # a4 = iteration counter for MULHU_SOFT interval
    li      x15, 20                # a5 = MULHU_SOFT interval

    # Initialize profiling counters
    li      x21, 0                    # s5 (x21) = mulhu_soft_total_cycles
    li      x22, 0                    # s6 (x22) = mulhu_soft_call_count

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
    # Conditional MUL/MULHU_SOFT
    remu    x16, x14, x15             # a6 = iteration % interval
    bnez    x16, use_mul
    # MULHU_SOFT path (with profiling)
    # Save registers that will be clobbered by __mulhu64_soft
    addi    sp, sp, -80
    sd      ra, 72(sp)
    sd      a0, 64(sp)
    sd      a1, 56(sp)
    sd      t0, 48(sp)
    sd      t1, 40(sp)
    sd      t2, 32(sp)
    sd      t3, 24(sp)
    sd      t4, 16(sp)
    sd      t5, 8(sp)
    sd      t6, 0(sp)
    # Prepare arguments and profile the call
    mv      a0, x10                   # First argument
    mv      a1, x11                   # Second argument
    csrr    x20, 0xB00                # s4 = Entry mcycle
    call    __mulhu64_soft            # Call software MULHU
    csrr    x16, 0xB00                # a6 = Exit mcycle
    sub     x16, x16, x20             # Delta cycles
    add     x21, x21, x16             # Accumulate mulhu_soft_total_cycles
    addi    x22, x22, 1               # Increment mulhu_soft_call_count
    mv      x17, a0                   # Save result
    # Restore saved registers
    ld      t6, 0(sp)
    ld      t5, 8(sp)
    ld      t4, 16(sp)
    ld      t3, 24(sp)
    ld      t2, 32(sp)
    ld      t1, 40(sp)
    ld      t0, 48(sp)
    ld      a1, 56(sp)
    ld      a0, 64(sp)
    ld      ra, 72(sp)
    addi    sp, sp, 80
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
    sd      x22, 0(x8)                # Store call_count (MULHU_SOFT calls)
    sd      x21, 8(x8)                # Store total_cycles (MULHU_SOFT cycles only)
    sub     x11, x9, x18              # Total program cycles (end - start)
    sd      x11, 16(x8)               # Store total_program_cycles

    # Calculate average cycles per call: mulhu_soft_total_cycles / mulhu_soft_call_count
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

# Software implementation of MULHU (unsigned 64-bit multiplication high)
# Input: a0, a1 (64-bit operands)
# Output: a0 (high 64 bits of a0 * a1)
# Clobbers: t0-t6
__mulhu64_soft:
    srli    t1, a0, 32                # t1 = high(a0)
    li      t4, -1                    # t4 = 0xFFFFFFFFFFFFFFFF
    srli    t4, t4, 32                # t4 = 0x00000000FFFFFFFF (mask)
    and     t0, a0, t4                # t0 = low(a0)

    srli    t3, a1, 32                # t3 = high(a1)
    and     t2, a1, t4                # t2 = low(a1)

    mul     t4, t0, t2                # t4 = low(a0) * low(a1)
    mul     t5, t0, t3                # t5 = low(a0) * high(a1)
    mul     t6, t1, t2                # t6 = high(a0) * low(a1)
    mul     a0, t1, t3                # a0 = high(a0) * high(a1)

    srli    t0, t4, 32                # t0 = high half of (low*low)
    add     t5, t5, t0                # t5 += high(low*low)
    sltu    t0, t5, t0                # t0 = carry from addition

    add     t1, t5, t6                # t1 = t5 + t6
    sltu    t2, t1, t6                # t2 = carry from addition
    add     t0, t0, t2                # t0 += carry

    slli    t0, t0, 32                # t0 = carry << 32
    srli    t1, t1, 32                # t1 = high 32 bits of middle sum
    or      t0, t0, t1                # t0 = combined middle result
    add     a0, a0, t0                # a0 += middle contribution

    ret

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