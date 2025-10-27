# Hardware MULHU Single-Instruction Profiling with HPM
# Measures the latency of a single MULHU instruction
# Enhanced with Hardware Performance Monitor counters

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 100        // Number of MULHU operations to profile

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
    # Setup HPM event selectors
    # Counter 3: I-cache misses
    li      x10, HPM_EVENT_ICACHE_MISS
    csrw    CSR_MHPMEVENT3, x10

    # Counter 4: Branch mispredicts
    li      x10, HPM_EVENT_BRANCH_MISPREDICT
    csrw    CSR_MHPMEVENT4, x10

    # Counter 5: Call instructions
    li      x10, HPM_EVENT_CALL_INSTR
    csrw    CSR_MHPMEVENT5, x10

    # Counter 6: I-cache accesses
    li      x10, HPM_EVENT_ICACHE_ACCESS
    csrw    CSR_MHPMEVENT6, x10

    # Clear all HPM counters
    csrwi   CSR_MHPMCOUNTER3, 0
    csrwi   CSR_MHPMCOUNTER4, 0
    csrwi   CSR_MHPMCOUNTER5, 0
    csrwi   CSR_MHPMCOUNTER6, 0

    # Enable all counters (clear mcountinhibit)
    csrwi   CSR_MCOUNTINHIBIT, 0

    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x20, NUM_ITERATIONS       # Loop counter

    # Initialize profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_call_count

    # Capture start performance counters
    csrr    x18, CSR_MCYCLE           # s2 (x18) = mcycle - start cycle count
    csrr    x19, CSR_MINSTRET         # s3 (x19) = minstret - start instruction count

test_loop:
    # Update operands to vary data patterns
    addi    x5, x5, 17                # Vary operand 1
    xori    x6, x6, 0x5A              # Vary operand 2

    # Profile single MULHU instruction
    csrr    x14, CSR_MCYCLE           # s4 (x14) = Entry mcycle
    mulhu   x13, x5, x6               # ← HARDWARE MULHU (what we measure)
    csrr    x15, CSR_MCYCLE           # s5 (x15) = Exit mcycle
    sub     x15, x15, x14             # Delta cycles
    add     x22, x22, x15             # Accumulate total cycles
    addi    x23, x23, 1               # Increment call count
    add     x7, x7, x13               # Accumulate result

    # Continue loop
    addi    x20, x20, -1
    bnez    x20, test_loop

    # Capture end performance counters
    csrr    x9, CSR_MCYCLE            # mcycle - end cycle count
    csrr    x10, CSR_MINSTRET         # minstret - end instruction count

    # Read HPM counters
    csrr    x24, CSR_MHPMCOUNTER3     # s8 (x24) = I-cache misses
    csrr    x25, CSR_MHPMCOUNTER4     # s9 (x25) = Branch mispredicts
    csrr    x26, CSR_MHPMCOUNTER5     # s10 (x26) = Call instructions
    csrr    x27, CSR_MHPMCOUNTER6     # s11 (x27) = I-cache accesses

    # Store profiling results in memory for extraction
    la      x8, profiling_data

    # Basic profiling fields (offsets 0x00-0x18)
    sd      x23, 0(x8)                # 0x00: Store call_count
    sd      x22, 8(x8)                # 0x08: Store total_cycles
    sub     x11, x9, x18              # Total program cycles (end - start)
    sd      x11, 16(x8)               # 0x10: Store total_program_cycles

    # Calculate average cycles per call: total_cycles / call_count
    div     x12, x22, x23
    sd      x12, 24(x8)               # 0x18: Store avg_cycles_per_call

    # HPM fields (offsets 0x20-0x48)
    sd      x24, 32(x8)               # 0x20: icache_misses (triggers HPM mode!)
    sd      x25, 40(x8)               # 0x28: branch_mispredicts
    sd      x26, 48(x8)               # 0x30: call_count_hpm
    sd      x27, 56(x8)               # 0x38: icache_accesses

    # Calculate I-cache miss rate: (icache_misses * 100) / icache_accesses
    # Avoid division by zero
    beqz    x27, skip_icache_rate
    li      x13, 100
    mul     x13, x24, x13
    div     x13, x13, x27
    sd      x13, 64(x8)               # 0x40: icache_miss_rate (%)
    j       calc_mispredicts

skip_icache_rate:
    sd      zero, 64(x8)              # 0x40: icache_miss_rate = 0%

calc_mispredicts:
    # Calculate mispredicts per call: branch_mispredicts / call_count_hpm
    # Avoid division by zero
    beqz    x26, skip_mispredict_rate
    div     x14, x25, x26
    sd      x14, 72(x8)               # 0x48: mispredicts_per_call
    j       write_tohost

skip_mispredict_rate:
    sd      zero, 72(x8)              # 0x48: mispredicts_per_call = 0

write_tohost:
    # Write result to tohost to signal completion
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