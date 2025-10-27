# Hardware MULHU Frequency Sweep Benchmark with HPM Profiling
# Measures performance impact of MULHU instruction frequency
# Enhanced with Hardware Performance Monitor counters

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter: 1 MULHU every N MULs (default)
#endif

// Total target = 1,000,000 multiply operations
#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

// HPM Event IDs
#define HPM_EVENT_ICACHE_MISS       1
#define HPM_EVENT_BRANCH_MISPREDICT 10
#define HPM_EVENT_CALL_INSTR        12
#define HPM_EVENT_ICACHE_ACCESS     16

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
    // Setup HPM event selectors
    // Counter 3: I-cache misses
    li      a0, HPM_EVENT_ICACHE_MISS
    csrw    CSR_MHPMEVENT3, a0

    // Counter 4: Branch mispredicts
    li      a0, HPM_EVENT_BRANCH_MISPREDICT
    csrw    CSR_MHPMEVENT4, a0

    // Counter 5: Call instructions (JAL/JALR with rd=x1/x5)
    li      a0, HPM_EVENT_CALL_INSTR
    csrw    CSR_MHPMEVENT5, a0

    // Counter 6: I-cache accesses
    li      a0, HPM_EVENT_ICACHE_ACCESS
    csrw    CSR_MHPMEVENT6, a0

    // Clear all HPM counters
    csrwi   CSR_MHPMCOUNTER3, 0
    csrwi   CSR_MHPMCOUNTER4, 0
    csrwi   CSR_MHPMCOUNTER5, 0
    csrwi   CSR_MHPMCOUNTER6, 0

    // Enable all counters (clear mcountinhibit)
    csrwi   CSR_MCOUNTINHIBIT, 0

    // Initialize test data
    // Use a0-a6 (x10-x16) and s2-s6 (x18-x22) to avoid MULHU expander conflicts
    // MULHU expander clobbers t0-t6 (x5-x7, x28-x31)
    li      x10, 0x123456789ABCDEF0   // a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   // a1 = Test operand 2
    li      x12, 0                    // a2 = Accumulator for results
    li      x13, OUTER_LOOPS          // a3 = outer loop counter
    li      x18, MULHU_INTERVAL - 1   // s2 = inner loop constant

    // Initialize profiling counters
    li      x19, 0                    // s3 (x19) = mulhu_total_cycles
    li      x20, 0                    // s4 (x20) = mulhu_call_count

    // Capture start performance counters
    csrr    x21, CSR_MCYCLE           // s5 (x21) = mcycle - start cycle count
    csrr    x22, CSR_MINSTRET         // s6 (x22) = minstret - start instruction count

outer_loop:
    // Inner loop: perform (MULHU_INTERVAL - 1) MUL operations
    mv      x14, x18                  // a4 = inner loop counter

inner_loop:
    // Perform MUL operations
    mul     x15, x10, x11             // a5 = result
    add     x12, x12, x15             // Accumulate result

    // Rotate operands to vary the multiplication pattern
    addi    x10, x10, 17              // Change operand slightly
    xori    x11, x11, 0x5A            // XOR pattern to vary bits

    // Decrement inner loop counter and continue
    addi    x14, x14, -1
    bnez    x14, inner_loop

    // After MULHU_INTERVAL MULs, perform one profiled MULHU
    csrr    x14, CSR_MCYCLE           // a4 = Entry mcycle
    mulhu   x16, x10, x11             // a6 = MULHU result (measured instruction)
    csrr    x15, CSR_MCYCLE           // a5 = Exit mcycle
    sub     x15, x15, x14             // Delta cycles
    add     x19, x19, x15             // Accumulate mulhu_total_cycles
    addi    x20, x20, 1               // Increment mulhu_call_count
    add     x12, x12, x16             // Accumulate result

    // Restore some entropy to operands
    addi    x10, x10, 23
    xori    x11, x11, 0xA5

    // Decrement outer loop counter and continue
    addi    x13, x13, -1
    bnez    x13, outer_loop

    // Capture end performance counters
    csrr    x9, CSR_MCYCLE            // mcycle - end cycle count
    csrr    x10, CSR_MINSTRET         // minstret - end instruction count

    // Store profiling results in memory
    la      x8, profiling_data

    // Basic profiling fields (offsets 0x00-0x18)
    sd      x20, 0(x8)                // 0x00: call_count (MULHU calls)
    sd      x19, 8(x8)                // 0x08: total_cycles (MULHU cycles only)
    sub     x11, x9, x21              // Total program cycles (end - start)
    sd      x11, 16(x8)               // 0x10: total_program_cycles

    // Calculate average cycles per call: mulhu_total_cycles / mulhu_call_count
    div     x14, x19, x20
    sd      x14, 24(x8)               // 0x18: avg_cycles_per_call

    // Read HPM counters AFTER basic fields (to avoid register clobbering)
    csrr    a0, CSR_MHPMCOUNTER3      // a0 = I-cache misses
    csrr    a1, CSR_MHPMCOUNTER4      // a1 = Branch mispredicts
    csrr    a2, CSR_MHPMCOUNTER5      // a2 = Call instructions (function calls)
    csrr    a3, CSR_MHPMCOUNTER6      // a3 = I-cache accesses

    // HPM fields (offsets 0x20-0x48)
    sd      a0, 32(x8)                // 0x20: icache_misses (triggers HPM mode!)
    sd      a1, 40(x8)                // 0x28: branch_mispredicts
    sd      a2, 48(x8)                // 0x30: call_count_hpm (function calls from HPM)
    sd      a3, 56(x8)                // 0x38: icache_accesses

    // Calculate I-cache miss rate: (icache_misses * 100) / icache_accesses
    // Avoid division by zero
    beqz    a3, skip_icache_rate
    li      x15, 100
    mul     x15, a0, x15
    div     x15, x15, a3
    sd      x15, 64(x8)               // 0x40: icache_miss_rate (%)
    j       calc_mispredicts

skip_icache_rate:
    sd      zero, 64(x8)              // 0x40: icache_miss_rate = 0%

calc_mispredicts:
    // Calculate mispredicts per call: branch_mispredicts / call_count_hpm
    // Avoid division by zero
    beqz    a2, skip_mispredict_rate
    div     x16, a1, a2
    sd      x16, 72(x8)               // 0x48: mispredicts_per_call
    j       write_tohost

skip_mispredict_rate:
    sd      zero, 72(x8)              // 0x48: mispredicts_per_call = 0

write_tohost:
    // Write to tohost to signal completion
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

.section .data
.align 3
profiling_data:
    .dword 0    # 0x00: call_count
    .dword 0    # 0x08: total_cycles
    .dword 0    # 0x10: total_program_cycles
    .dword 0    # 0x18: avg_cycles_per_call
    .dword 0    # 0x20: icache_misses (triggers HPM mode)
    .dword 0    # 0x28: branch_mispredicts
    .dword 0    # 0x30: call_count_hpm
    .dword 0    # 0x38: icache_accesses
    .dword 0    # 0x40: icache_miss_rate (%)
    .dword 0    # 0x48: mispredicts_per_call (marks completion)

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0