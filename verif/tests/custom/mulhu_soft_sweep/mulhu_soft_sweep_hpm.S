# MULHU Software Implementation with HPM Profiling
# Captures branch mispredictions, I-cache misses, and function call overhead

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000
#endif

#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

# CSR addresses for HPM counters
#define CSR_MHPMEVENT3   0x323
#define CSR_MHPMEVENT4   0x324
#define CSR_MHPMEVENT5   0x325
#define CSR_MHPMEVENT6   0x326
#define CSR_MHPMCOUNTER3 0xB03
#define CSR_MHPMCOUNTER4 0xB04
#define CSR_MHPMCOUNTER5 0xB05
#define CSR_MHPMCOUNTER6 0xB06

# HPM Event IDs
#define EVENT_ICACHE_MISS       0x01
#define EVENT_BRANCH_MISPREDICT 0x0A
#define EVENT_CALLS             0x0C
#define EVENT_RETURNS           0x0D
#define EVENT_ICACHE_ACCESS     0x10
#define EVENT_PIPELINE_STALLS   0x16

_start:
    # Configure HPM event selectors
    li      t0, EVENT_ICACHE_MISS
    csrw    CSR_MHPMEVENT3, t0          # Counter 3 = I-cache misses

    li      t0, EVENT_BRANCH_MISPREDICT
    csrw    CSR_MHPMEVENT4, t0          # Counter 4 = Branch mispredicts

    li      t0, EVENT_CALLS
    csrw    CSR_MHPMEVENT5, t0          # Counter 5 = Function calls

    li      t0, EVENT_ICACHE_ACCESS
    csrw    CSR_MHPMEVENT6, t0          # Counter 6 = I-cache accesses

    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x20, OUTER_LOOPS          # Outer loop counter
    li      x21, MULHU_INTERVAL - 1   # Inner loop constant

    # Initialize function profiling counters
    li      x22, 0                    # s6 = mulhu_total_cycles
    li      x23, 0                    # s7 = mulhu_call_count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle - start
    csrr    x29, 0xB02                # minstret - start
    csrr    s8, CSR_MHPMCOUNTER3      # I-cache misses - start
    csrr    s9, CSR_MHPMCOUNTER4      # Branch mispredicts - start
    csrr    s10, CSR_MHPMCOUNTER5     # Calls - start
    csrr    s11, CSR_MHPMCOUNTER6     # I-cache accesses - start

outer_loop:
    mv      x11, x21                  # Reload inner loop counter

inner_loop:
    mul     x12, x5, x6
    add     x7, x7, x12
    addi    x5, x5, 17
    xori    x6, x6, 0x5A
    addi    x11, x11, -1
    bnez    x11, inner_loop

    # Profile software MULHU call
    csrr    x24, 0xB00                # Entry mcycle
    mv      a0, x5
    mv      a1, x6
    call    __mulhu64_soft
    csrr    x25, 0xB00                # Exit mcycle
    sub     x25, x25, x24
    add     x22, x22, x25             # Accumulate cycles
    addi    x23, x23, 1               # Count calls
    add     x7, x7, a0

    addi    x5, x5, 23
    xori    x6, x6, 0xA5
    addi    x20, x20, -1
    bnez    x20, outer_loop

    # Capture end performance counters
    csrr    x30, 0xB00                # mcycle - end
    csrr    x31, 0xB02                # minstret - end
    csrr    t3, CSR_MHPMCOUNTER3      # I-cache misses - end
    csrr    t4, CSR_MHPMCOUNTER4      # Branch mispredicts - end
    csrr    t5, CSR_MHPMCOUNTER5      # Calls - end
    csrr    t6, CSR_MHPMCOUNTER6      # I-cache accesses - end

    # Store basic profiling results
    la      x8, profiling_data
    sd      x23, 0(x8)                # call_count
    sd      x22, 8(x8)                # total_cycles
    sub     x9, x30, x28
    sd      x9, 16(x8)                # total_program_cycles
    div     x26, x22, x23
    sd      x26, 24(x8)               # avg_cycles_per_call

    # Store HPM counter deltas
    sub     t3, t3, s8                # Delta I-cache misses
    sd      t3, 32(x8)                # icache_misses

    sub     t4, t4, s9                # Delta branch mispredicts
    sd      t4, 40(x8)                # branch_mispredicts

    sub     t5, t5, s10               # Delta calls
    sd      t5, 48(x8)                # call_count_hpm

    sub     t6, t6, s11               # Delta I-cache accesses
    sd      t6, 56(x8)                # icache_accesses

    # Calculate derived metrics
    # I-cache miss rate = (misses * 100) / accesses
    li      a0, 100
    mul     a0, t3, a0
    beqz    t6, skip_icache_rate
    div     a0, a0, t6
skip_icache_rate:
    sd      a0, 64(x8)                # icache_miss_rate (%)

    # Branch mispredict rate per call = mispredicts / calls
    beqz    x23, skip_mispredict_rate
    div     a1, t4, x23
skip_mispredict_rate:
    sd      a1, 72(x8)                # mispredicts_per_call

    # Write to tohost
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

# Software MULHU implementation
__mulhu64_soft:
    srli    t1, a0, 32
    li      t4, -1
    srli    t4, t4, 32
    and     t0, a0, t4
    srli    t3, a1, 32
    and     t2, a1, t4
    mul     t4, t0, t2
    mul     t5, t0, t3
    mul     t6, t1, t2
    mul     a0, t1, t3
    srli    t0, t4, 32
    add     t5, t5, t0
    sltu    t0, t5, t0
    add     t6, t6, t5
    sltu    t5, t6, t5
    add     t0, t0, t5
    slli    t0, t0, 32
    srli    t5, t6, 32
    or      t0, t0, t5
    add     a0, a0, t0
    ret

.section .data
.align 3
profiling_data:
    .dword 0    # 0x00: call_count
    .dword 0    # 0x08: total_cycles
    .dword 0    # 0x10: total_program_cycles
    .dword 0    # 0x18: avg_cycles_per_call
    .dword 0    # 0x20: icache_misses
    .dword 0    # 0x28: branch_mispredicts
    .dword 0    # 0x30: call_count_hpm (verification)
    .dword 0    # 0x38: icache_accesses
    .dword 0    # 0x40: icache_miss_rate (%)
    .dword 0    # 0x48: mispredicts_per_call

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0