# RISC-V Synthetic Benchmark - MULHU Sweep
# Generated benchmark: 1.0pct
# Total instructions: 10,000,000
# Kernel size: 200
# Loop iterations: 50,000
# MUL instructions: 49,500
# MULHU instructions: 500
# Multiplication percentage: 0.5000%
# MULHU/(MUL+MULHU) ratio: 1.0000%
# MULHU interval: every 100 iterations

.section .text.init
.globl _start
_start:
    li      sp, 0x84000000
    la      s0, profiling_data
    sd      zero, 0(s0)
    sd      zero, 8(s0)
    sd      zero, 16(s0)
    sd      zero, 24(s0)
    csrr    s2, 0xB00
    csrr    s3, 0xB02
    call    benchmark_kernel
    csrr    s4, 0xB00
    csrr    s5, 0xB02
    # Profiling data already populated by benchmark_kernel
    # Just add total_program_cycles and avg_cycles_per_call
    la      s0, profiling_data
    sub     a0, s4, s2       # Total program cycles
    sd      a0, 16(s0)       # Store total_program_cycles
    # Calculate avg: total_cycles / call_count
    ld      a1, 8(s0)        # Load total_cycles
    ld      a2, 0(s0)        # Load call_count
    beqz    a2, skip_avg     # Avoid divide by zero
    div     a3, a1, a2       # avg = total / count
    sd      a3, 24(s0)       # Store avg_cycles_per_call
skip_avg:
    la      s0, tohost
    li      s1, 1
    sd      s1, 0(s0)
done:
    j       done

.section .text
benchmark_kernel:
    addi    sp, sp, -96
    sd      ra, 88(sp)
    sd      s0, 80(sp)
    sd      s1, 72(sp)
    sd      s6, 64(sp)
    sd      s7, 56(sp)
    sd      s8, 48(sp)
    sd      s9, 40(sp)

    addi    s0, sp, 1024
    li      t0, 123
    li      t1, 456
    li      t2, 789
    li      t3, 321
    li      t4, 654
    li      t5, 987
    li      t6, 111

    li      s1, 50000
    li      s6, 0         # Iteration counter
    li      s7, 100  # MULHU interval
    li      s8, 0         # MULHU call_count accumulator
    li      s9, 0         # MULHU total_cycles accumulator

loop_start:
    beqz    s1, loop_end

    add t5, t2, t1
    add t5, t0, t5
    lw t4, 912(s0)
    and t0, t0, t1
    addi t4, t0, -420
    sw t1, 664(sp)
    ori t2, t6, 26
    lw t5, 824(s0)
    xor t2, t1, t1
    lw t0, 344(s0)
    and t2, t6, t2
    sra t6, t0, t5
    ori t0, t3, 322
    sra t6, t5, t4
    ori t1, t5, 284
    addi t1, t6, 322
    add t6, t0, t3
    sub t5, t6, t2
    sub t2, t1, t5
    addi t5, t5, -1464
    srai t1, t4, 15
    sub t3, t2, t5
    slti t1, t5, 608
    lw t1, 792(s0)
    sub t3, t2, t0
    addi t5, t2, -307
    sltu t3, t5, t3
    sub t1, t1, t5
    srli t2, t5, 27
    slli t2, t1, 8
    slli t0, t6, 3
    add t5, t1, t6
    sltu t4, t0, t3
    ori t3, t4, 1029
    sll t5, t5, t0
    slti t6, t2, 738
    sub t3, t1, t3
    addi t5, t2, -585
    and t6, t5, t2
    slti t4, t1, -796
    or t4, t6, t4
    addi t2, t3, -1889
    sub t6, t6, t2
    add t1, t4, t0
    addi t3, t6, -1482
    lw t1, 544(s0)
    sltu t4, t1, t2
    srli t3, t1, 12
    sw t5, 312(sp)
    sltu t3, t4, t3
    add t1, t0, t2
    addi t4, t1, -244
    add t5, t5, t0
    add t0, t6, t2
    addi t1, t2, 1928
    addi t1, t5, 1824
    sub t6, t3, t1
    add t5, t3, t2
    andi t3, t6, 221
    slti t5, t0, -1552
    xori t2, t6, -1153
    add t1, t4, t3
    sub t1, t2, t3
    add t3, t6, t6
    sll t0, t5, t4
    add t6, t6, t1
    sub t3, t3, t1
    and t1, t3, t0
    xor t6, t6, t3
    sub t5, t5, t6
    srai t5, t3, 9
    sub t1, t0, t4
    lw t5, 552(s0)
    and t0, t4, t3
    ori t1, t0, 328
    add t4, t0, t5
    sub t0, t4, t1
    srli t0, t4, 5
    xori t4, t4, 543
    add t5, t5, t2
    sub t3, t1, t5
    sltu t3, t2, t6
    add t3, t4, t4
    add t4, t1, t4
    add t2, t0, t1
    xor t1, t3, t6
    srai t2, t4, 0
    slti t2, t5, -1200
    sub t0, t0, t5
    srl t2, t2, t4
    addi t2, t1, 114
    andi t2, t6, 208
    addi t3, t6, 218
    add t2, t6, t1
    sltu t1, t5, t3
    srai t3, t4, 0
    add t5, t1, t4
    sub t4, t4, t1
    or t0, t2, t2
    sub t1, t5, t1
    slt t2, t6, t4
    ori t5, t1, 969
    add t3, t0, t1
    sw t6, 944(sp)
    xori t6, t5, -16
    add t6, t5, t0
    and t6, t3, t1
    sub t2, t2, t6
    add t0, t5, t1
    xor t2, t6, t0
    sw t5, 280(sp)
    slli t5, t6, 21
    add t2, t1, t4
    add t0, t4, t3
    xori t6, t2, 1526
    srli t0, t3, 12
    add t5, t3, t0
    srli t5, t5, 12
    andi t0, t5, 1352
    sra t5, t6, t0
    sw t4, 920(sp)
    addi t3, t2, 1248
    sltu t4, t1, t1
    xori t3, t5, -623
    srli t2, t3, 0
    sub t1, t3, t6
    srli t5, t2, 29
    andi t5, t1, 1938
    lw t2, 168(s0)
    srai t5, t4, 21
    add t5, t2, t1
    add t0, t0, t1
    ori t6, t6, 298
    andi t5, t4, 796
    sw t3, 712(sp)
    or t1, t5, t5
    add t6, t3, t1
    addi t4, t3, -1637
    srl t6, t0, t3
    sub t5, t4, t4
    sra t6, t3, t4
    sw t6, 912(sp)
    slli t1, t5, 30
    xor t6, t1, t6
    sltu t6, t6, t4
    xori t1, t2, 1555
    addi t2, t1, 177
    xor t4, t0, t1
    add t3, t5, t1
    lw t3, 216(s0)
    xor t4, t3, t3
    add t6, t3, t3
    lw t6, 592(s0)
    sw t3, 584(sp)
    sub t2, t6, t3
    ori t5, t5, 903
    or t2, t3, t3
    sub t2, t5, t5
    xori t1, t6, 1780
    addi t4, t0, 1179
    srli t5, t0, 5
    sltu t1, t6, t3
    add t2, t3, t2
    # Conditional MUL/MULHU (no per-call profiling)
    remu    a0, s6, s7     # Check if iteration % interval == 0
    bnez    a0, use_mul_163
    # MULHU path (no cycle counting)
    mulhu   t1, t3, t2
    j       after_mul_163
use_mul_163:
    # MUL path (no profiling)
    mul     t2, t6, t3
after_mul_163:
    sub t2, t6, t0
    and t5, t4, t0
    or t5, t0, t6
    slt t6, t0, t1
    add t4, t1, t1
    sub t5, t0, t4
    sub t5, t2, t6
    or t4, t4, t5
    lw t2, 112(s0)
    addi t0, t2, 1026
    xori t1, t0, -59
    addi t6, t2, -1057
    sll t2, t4, t3
    sltu t0, t4, t5
    and t6, t3, t6
    and t3, t2, t5
    xori t1, t3, -606
    sw t4, 528(sp)
    slli t3, t3, 17
    or t6, t0, t2
    or t6, t3, t4
    srai t3, t2, 1
    xor t1, t3, t1
    xor t2, t2, t4
    sltu t4, t0, t4
    add t1, t5, t3
    ori t6, t1, 1950
    slti t3, t3, -1907
    sub t1, t3, t5
    sub t5, t4, t2
    ori t4, t2, 1742
    sw t2, 560(sp)
    sltu t2, t2, t2
    add t5, t1, t2
    addi t4, t6, -532
    add t5, t3, t2

    addi    s6, s6, 1      # Increment iteration counter
    addi    s1, s1, -1
    j       loop_start

loop_end:
    # Store accumulated profiling data to memory
    la      a0, profiling_data
    sd      s8, 0(a0)        # Store call_count
    sd      s9, 8(a0)        # Store total_cycles
    ld      ra, 88(sp)
    ld      s0, 80(sp)
    ld      s1, 72(sp)
    ld      s6, 64(sp)
    ld      s7, 56(sp)
    ld      s8, 48(sp)
    ld      s9, 40(sp)
    addi    sp, sp, 96
    ret

.section .data
.align 3
profiling_data:
    .dword 0
    .dword 0
    .dword 0
    .dword 0

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0