# Hardware MULHU Sweep with Single HPM Counter
# Configurable via -DHPM_EVENT_SELECT at compile time
# EVENT_SELECT: 1=branch_mispredict, 2=icache_miss, 3=icache_access, 4=pipeline_stall

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000
#endif

#ifndef HPM_EVENT_SELECT
#define HPM_EVENT_SELECT 1  // Default: branch mispredicts
#endif

#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

// HPM Event IDs
#define HPM_EVENT_ICACHE_MISS       1
#define HPM_EVENT_BRANCH_MISPREDICT 10
#define HPM_EVENT_ICACHE_ACCESS     16
#define HPM_EVENT_PIPELINE_STALL    22

// CSR Addresses
#define CSR_MCYCLE          0xB00
#define CSR_MINSTRET        0xB02
#define CSR_MHPMCOUNTER3    0xB03
#define CSR_MHPMEVENT3      0x323
#define CSR_MCOUNTINHIBIT   0x320

_start:
    // Setup SINGLE HPM event based on compile-time selection
#if HPM_EVENT_SELECT == 1
    li      a0, HPM_EVENT_BRANCH_MISPREDICT
#elif HPM_EVENT_SELECT == 2
    li      a0, HPM_EVENT_ICACHE_MISS
#elif HPM_EVENT_SELECT == 3
    li      a0, HPM_EVENT_ICACHE_ACCESS
#elif HPM_EVENT_SELECT == 4
    li      a0, HPM_EVENT_PIPELINE_STALL
#endif
    csrw    CSR_MHPMEVENT3, a0
    csrwi   CSR_MHPMCOUNTER3, 0
    csrwi   CSR_MCOUNTINHIBIT, 0

    // Initialize test data
    li      x10, 0x123456789ABCDEF0   // a0 = operand 1
    li      x11, 0x0FEDCBA987654321   // a1 = operand 2
    li      x12, 0                    // a2 = accumulator
    li      x13, OUTER_LOOPS          // a3 = outer loop counter
    li      x18, MULHU_INTERVAL - 1   // s2 = inner loop constant

    // Initialize profiling counters
    li      x19, 0                    // s3 = mulhu_total_cycles
    li      x20, 0                    // s4 = mulhu_call_count

    // Capture start performance counters
    csrr    x21, CSR_MCYCLE           // s5 = mcycle start
    csrr    x22, CSR_MINSTRET         // s6 = minstret start

outer_loop:
    mv      x14, x18                  // a4 = inner loop counter

inner_loop:
    mul     x15, x10, x11             // a5 = result
    add     x12, x12, x15             // accumulate
    addi    x10, x10, 17
    xori    x11, x11, 0x5A
    addi    x14, x14, -1
    bnez    x14, inner_loop

    // Profile MULHU
    csrr    x14, CSR_MCYCLE
    mulhu   x16, x10, x11
    csrr    x15, CSR_MCYCLE
    sub     x15, x15, x14
    add     x19, x19, x15             // accumulate MULHU cycles
    addi    x20, x20, 1               // increment call count
    add     x12, x12, x16

    addi    x10, x10, 23
    xori    x11, x11, 0xA5
    addi    x13, x13, -1
    bnez    x13, outer_loop

    // Capture end performance counters
    csrr    x9, CSR_MCYCLE
    csrr    x10, CSR_MINSTRET

    // Store profiling results
    la      x8, profiling_data

    // Basic profiling fields
    sd      x20, 0(x8)                // call_count
    sd      x19, 8(x8)                // total_cycles
    sub     x11, x9, x21              // total_program_cycles
    sd      x11, 16(x8)               // total_program_cycles
    div     x14, x19, x20             // avg_cycles_per_call
    sd      x14, 24(x8)               // avg_cycles_per_call

    // Read the single HPM counter
    csrr    a0, CSR_MHPMCOUNTER3

    // Store HPM value at offset 0x20 (triggers HPM mode in profiler)
    sd      a0, 32(x8)                // hpm_event_count
    sd      zero, 40(x8)
    sd      zero, 48(x8)
    sd      zero, 56(x8)
    sd      zero, 64(x8)
    sd      zero, 72(x8)

    // Signal completion
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
    .dword 0    # hpm_event_count (offset 0x20, triggers HPM mode)
    .dword 0
    .dword 0
    .dword 0
    .dword 0
    .dword 0

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0