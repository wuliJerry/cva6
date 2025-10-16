# Simple Software MULHU Sweep - 1000 Operations (N=10)
# Exactly the same code as mulhu_soft_sweep but with smaller total count
# This is for quick testing to verify the register allocation fix works

.section .text.init
.globl _start
.option norvc

#define MULHU_INTERVAL 10             // N=10 (10% MULHU frequency)
#define TARGET_TOTAL_OPS 1000         // Only 1000 total ops instead of 1M
#define OUTER_LOOPS (TARGET_TOTAL_OPS / MULHU_INTERVAL)  // = 100 iterations

_start:
    # Initialize test data (EXACT SAME as mulhu_soft_sweep)
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x20, OUTER_LOOPS          # Outer loop counter = 100 (use s4, not a0!)
    li      x21, MULHU_INTERVAL - 1   # Inner loop constant (save in s5, reload each iteration)

    # Initialize function profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_call_count

    # Configure HPM counters (mhpmcounter3-6)
    # mhpmevent3 = 0x01 (I-cache miss)
    # mhpmevent4 = 0x0A (Branch mispredict)
    # mhpmevent5 = 0x0C (Function calls)
    # mhpmevent6 = 0x10 (I-cache access)
    li      t0, 0x01
    csrw    0x323, t0                 # mhpmevent3 = I-cache miss
    li      t0, 0x0A
    csrw    0x324, t0                 # mhpmevent4 = Branch mispredict
    li      t0, 0x0C
    csrw    0x325, t0                 # mhpmevent5 = Function calls
    li      t0, 0x10
    csrw    0x326, t0                 # mhpmevent6 = I-cache access

    # Capture start performance counters
    csrr    x28, 0xB00                # t3 (x28) = mcycle start
    csrr    x29, 0xB02                # t4 (x29) = minstret start
    csrr    x30, 0xB03                # t5 (x30) = mhpmcounter3 start (I-cache misses)
    csrr    x31, 0xB04                # t6 (x31) = mhpmcounter4 start (branch mispredicts)
    csrr    s2, 0xB05                 # s2 (x18) = mhpmcounter5 start (function calls)
    csrr    s3, 0xB06                 # s3 (x19) = mhpmcounter6 start (I-cache accesses)

outer_loop:
    mv      x11, x21                  # Reload inner loop counter from constant (1 instruction always!)

inner_loop:
    # Regular multiply operations
    mul     x12, x5, x6               # Regular multiply
    add     x7, x7, x12               # Accumulate result
    addi    x5, x5, 17                # Vary operand 1 (prime increment)
    xori    x6, x6, 0x5A              # Vary operand 2 (XOR pattern)

    addi    x11, x11, -1              # Decrement inner counter
    bnez    x11, inner_loop           # Continue inner loop

    # Call software MULHU implementation after N multiplies
    # Instrument call for profiling
    csrr    x24, 0xB00                # s8 (x24) = entry mcycle
    mv      a0, x5                    # First argument
    mv      a1, x6                    # Second argument
    call    __mulhu64_soft            # Call software MULHU
    csrr    x25, 0xB00                # s9 (x25) = exit mcycle
    sub     x25, x25, x24             # x25 = delta cycles
    add     x22, x22, x25             # Accumulate total cycles in s6
    addi    x23, x23, 1               # Increment call count in s7
    add     x7, x7, a0                # Accumulate MULHU result

    # Update operands for next iteration
    addi    x5, x5, 23                # Vary operand 1 (different prime)
    xori    x6, x6, 0xA5              # Vary operand 2 (different XOR)

    addi    x20, x20, -1              # Decrement outer counter (s4, not a0!)
    bnez    x20, outer_loop           # Continue outer loop

    # Capture end performance counters
    csrr    s8, 0xB00                 # s8 = mcycle end
    csrr    s9, 0xB02                 # s9 = minstret end
    csrr    t0, 0xB03                 # t0 = mhpmcounter3 end (I-cache misses)
    csrr    t1, 0xB04                 # t1 = mhpmcounter4 end (branch mispredicts)
    csrr    t2, 0xB05                 # t2 = mhpmcounter5 end (function calls)
    csrr    t3, 0xB06                 # t3 = mhpmcounter6 end (I-cache accesses)

    # Calculate HPM deltas
    sub     t0, t0, x30               # Delta I-cache misses (end - start)
    sub     t1, t1, x31               # Delta branch mispredicts (end - start)
    sub     t2, t2, s2                # Delta function calls (end - start)
    sub     t3, t3, s3                # Delta I-cache accesses (end - start)

    # Store profiling results in memory for extraction
    la      x8, profiling_data
    sd      x23, 0(x8)                # Store call_count
    sd      x22, 8(x8)                # Store total_cycles
    sub     x9, s8, x28               # Total program cycles (end - start)
    sd      x9, 16(x8)                # Store total_program_cycles

    # Calculate average cycles per call: total_cycles / call_count
    # x26 = x22 / x23
    div     x26, x22, x23
    sd      x26, 24(x8)               # Store avg_cycles_per_call

    # Store HPM metrics at offset 0x20-0x48
    sd      t0, 32(x8)                # Store icache_misses (0x20)
    sd      t1, 40(x8)                # Store branch_mispredicts (0x28)
    sd      t2, 48(x8)                # Store call_count_hpm (0x30)
    sd      t3, 56(x8)                # Store icache_accesses (0x38)

    # Calculate I-cache miss rate: (misses * 100) / accesses
    beqz    t3, skip_miss_rate        # Avoid divide by zero
    li      t4, 100
    mul     t4, t0, t4
    div     t4, t4, t3
    sd      t4, 64(x8)                # Store icache_miss_rate (0x40)
    j       calc_mispredicts
skip_miss_rate:
    sd      zero, 64(x8)              # Store 0 if no accesses

calc_mispredicts:
    # Calculate mispredicts per call: mispredicts / call_count
    beqz    x23, skip_mispredicts     # Avoid divide by zero
    div     t5, t1, x23
    sd      t5, 72(x8)                # Store mispredicts_per_call (0x48)
    j       test_complete
skip_mispredicts:
    sd      zero, 72(x8)              # Store 0 if no calls

test_complete:

    # Write result to tohost to signal completion
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

# Software implementation of MULHU (64-bit unsigned high multiply)
# Input: a0 = multiplicand, a1 = multiplier
# Output: a0 = upper 64 bits of (a0 * a1)
# Clobbers: t0, t1, t2, t3, t4, t5, t6
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
    .dword 0    # call_count (0x00)
    .dword 0    # total_cycles (0x08)
    .dword 0    # total_program_cycles (0x10)
    .dword 0    # avg_cycles_per_call (0x18)
    .dword 0    # icache_misses (0x20)
    .dword 0    # branch_mispredicts (0x28)
    .dword 0    # call_count_hpm (0x30)
    .dword 0    # icache_accesses (0x38)
    .dword 0    # icache_miss_rate (0x40)
    .dword 0    # mispredicts_per_call (0x48)

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0