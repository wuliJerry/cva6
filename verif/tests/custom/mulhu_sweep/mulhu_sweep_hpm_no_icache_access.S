# Hardware MULHU Frequency Sweep Benchmark with HPM (NO I-cache Access Counter)
# Test to isolate the source of HPM overhead

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter
#endif

#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

// HPM Event IDs
#define HPM_EVENT_ICACHE_MISS       1
#define HPM_EVENT_DCACHE_MISS       2
#define HPM_EVENT_BRANCH_MISPREDICT 10
#define HPM_EVENT_PIPELINE_STALL    22

// CSR Addresses
#define CSR_MCYCLE          0xB00
#define CSR_MINSTRET        0xB02
#define CSR_MHPMCOUNTER3    0xB03
#define CSR_MHPMCOUNTER4    0xB04
#define CSR_MHPMCOUNTER5    0xB05
#define CSR_MHPMCOUNTER6    0xB06
#define CSR_MHPMEVENT3      0x323
#define CSR_MHPMEVENT4      0x324
#define CSR_MHPMEVENT5      0x325
#define CSR_MHPMEVENT6      0x326
#define CSR_MCOUNTINHIBIT   0x320

_start:
    // Setup HPM event selectors - NO I-cache access counter!
    // Counter 3: I-cache misses
    li      a0, HPM_EVENT_ICACHE_MISS
    csrw    CSR_MHPMEVENT3, a0

    // Counter 4: Branch mispredicts
    li      a0, HPM_EVENT_BRANCH_MISPREDICT
    csrw    CSR_MHPMEVENT4, a0

    // Counter 5: D-cache misses (instead of call instructions)
    li      a0, HPM_EVENT_DCACHE_MISS
    csrw    CSR_MHPMEVENT5, a0

    // Counter 6: Pipeline stalls (instead of I-cache accesses)
    li      a0, HPM_EVENT_PIPELINE_STALL
    csrw    CSR_MHPMEVENT6, a0

    // Clear all HPM counters
    csrwi   CSR_MHPMCOUNTER3, 0
    csrwi   CSR_MHPMCOUNTER4, 0
    csrwi   CSR_MHPMCOUNTER5, 0
    csrwi   CSR_MHPMCOUNTER6, 0

    // Enable all counters
    csrwi   CSR_MCOUNTINHIBIT, 0

    // Initialize test data
    li      x10, 0x123456789ABCDEF0   // a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   // a1 = Test operand 2
    li      x12, 0                    // a2 = Accumulator
    li      x13, OUTER_LOOPS          // a3 = outer loop counter
    li      x18, MULHU_INTERVAL - 1   // s2 = inner loop constant

    // Initialize profiling counters
    li      x19, 0                    // s3 = mulhu_total_cycles
    li      x20, 0                    // s4 = mulhu_call_count

    // Capture start performance counters
    csrr    x21, CSR_MCYCLE           // s5 = mcycle start
    csrr    x22, CSR_MINSTRET         // s6 = minstret start

outer_loop:
    // Inner loop
    mv      x14, x18                  // a4 = inner loop counter

inner_loop:
    mul     x15, x10, x11             // a5 = result
    add     x12, x12, x15             // Accumulate
    addi    x10, x10, 17
    xori    x11, x11, 0x5A
    addi    x14, x14, -1
    bnez    x14, inner_loop

    // Profile MULHU
    csrr    x14, CSR_MCYCLE
    mulhu   x16, x10, x11
    csrr    x15, CSR_MCYCLE
    sub     x15, x15, x14
    add     x19, x19, x15
    addi    x20, x20, 1
    add     x12, x12, x16

    addi    x10, x10, 23
    xori    x11, x11, 0xA5
    addi    x13, x13, -1
    bnez    x13, outer_loop

    // Capture end counters
    csrr    x9, CSR_MCYCLE
    csrr    x10, CSR_MINSTRET

    // Store profiling results
    la      x8, profiling_data

    // Basic fields
    sd      x20, 0(x8)                // call_count
    sd      x19, 8(x8)                // total_cycles
    sub     x11, x9, x21
    sd      x11, 16(x8)               // total_program_cycles
    div     x14, x19, x20
    sd      x14, 24(x8)               // avg_cycles_per_call

    // Read HPM counters
    csrr    a0, CSR_MHPMCOUNTER3      // I-cache misses
    csrr    a1, CSR_MHPMCOUNTER4      // Branch mispredicts
    csrr    a2, CSR_MHPMCOUNTER5      // D-cache misses
    csrr    a3, CSR_MHPMCOUNTER6      // Pipeline stalls

    // HPM fields
    sd      a0, 32(x8)                // icache_misses
    sd      a1, 40(x8)                // branch_mispredicts
    sd      a2, 48(x8)                // dcache_misses (was call_count_hpm)
    sd      a3, 56(x8)                // pipeline_stalls (was icache_accesses)

    // Calculate rates
    beqz    a0, skip_icache_rate
    li      x15, 100
    mul     x15, x11, x15             // Use total_program_cycles as denominator
    div     x15, x15, a0
    sd      x15, 64(x8)
    j       calc_stalls

skip_icache_rate:
    sd      zero, 64(x8)

calc_stalls:
    beqz    a3, skip_stall_rate
    div     x16, a3, x11              // stalls per cycle
    sd      x16, 72(x8)
    j       write_tohost

skip_stall_rate:
    sd      zero, 72(x8)

write_tohost:
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
    .dword 0    # icache_misses
    .dword 0    # branch_mispredicts
    .dword 0    # dcache_misses
    .dword 0    # pipeline_stalls
    .dword 0    # cycles_per_miss
    .dword 0    # stalls_per_cycle

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0