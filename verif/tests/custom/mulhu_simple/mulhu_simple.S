# Hardware MULHU Simple Test
# Quick test with only 100 MULHU operations to verify profiling works with FunctionProfiler window.

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 100
#define PROFILER_BASE         0x80002000
#define PROFILER_CALL_COUNT   (PROFILER_BASE + 0x00)
#define PROFILER_TOTAL_CYCLES (PROFILER_BASE + 0x08)
#define PROFILER_RETIRED_INSNS (PROFILER_BASE + 0x10)
#define PROFILER_AVG_CYCLES   (PROFILER_BASE + 0x18)
#define PROFILER_AVG_INSNS    (PROFILER_BASE + 0x20)

_start:
    li      a0, 0x123456789ABCDEF0   # operand 1
    li      a1, 0x0FEDCBA987654321   # operand 2
    li      a2, 0                    # accumulator
    li      a3, NUM_ITERATIONS       # loop counter

    li      s5, 0                    # mulhu_total_cycles
    li      s6, 0                    # mulhu_call_count

    csrr    s2, 0xB00                # mcycle start
    csrr    s3, 0xB02                # minstret start

test_loop:
    addi    a0, a0, 17
    xori    a1, a1, 0x5A

    csrr    a4, 0xB00                # entry mcycle
    mulhu   a6, a0, a1
    csrr    a5, 0xB00                # exit mcycle
    sub     a5, a5, a4               # delta cycles
    add     s5, s5, a5               # accumulate cycles
    addi    s6, s6, 1                # increment call count
    add     a2, a2, a6               # accumulate result

    addi    a3, a3, -1
    bnez    a3, test_loop

    csrr    t0, 0xB00                # mcycle end
    csrr    t1, 0xB02                # minstret end
    sub     t2, t0, s2               # total program cycles
    sub     t3, t1, s3               # total program instret

    # Calculate averages
    # s5 = mulhu_total_cycles, s6 = mulhu_call_count
    divu    s7, s5, s6               # avg cycles per call
    li      s8, 1                    # avg insns per call (1 mulhu per call)

    # Write profiling data to FunctionProfiler memory region
    li      t4, PROFILER_BASE

    sd      s6, 0(t4)                # offset 0x00: call_count
    sd      s5, 8(t4)                # offset 0x08: total_cycles (function)
    li      s9, 100                  # total retired insns in function (approx)
    sd      s9, 16(t4)               # offset 0x10: retired_insns (function)
    sd      s7, 24(t4)               # offset 0x18: avg_cycles
    sd      s8, 32(t4)               # offset 0x20: avg_insns (triggers profiler output)

    fence   io, io

    la      t6, tohost
    li      t0, 1
    sd      t0, 0(t6)

done:
    j       done

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0

