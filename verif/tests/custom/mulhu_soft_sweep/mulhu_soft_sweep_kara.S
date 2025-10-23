# MULHU Karatsuba Implementation Sweep Benchmark
# Tests performance impact of Karatsuba-style MULHU vs standard software multiply
# Sweeps N ∈ {10000, 1000, 100, 10} for MULHU frequency
#
# NOTE: This uses a simulated 'khi' CSR (we use mcycle as placeholder)
# to approximate the latency characteristics of the Karatsuba algorithm

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000          // N parameter - number of MULs per MULHU (default)
#endif

// Keep total multiply operations (MUL + MULHU) constant across all configurations
// Total target = 1,000,000 multiply operations
#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

_start:
    # Initialize test data
    li      x5, 0x123456789ABCDEF0    # Test operand 1
    li      x6, 0x0FEDCBA987654321    # Test operand 2
    li      x7, 0                     # Accumulator
    li      x20, OUTER_LOOPS          # Outer loop counter (use s4, not a0!)
    li      x21, MULHU_INTERVAL - 1   # Inner loop constant (save in s5, reload each iteration)

    # Initialize function profiling counters
    li      x22, 0                    # s6 (x22) = mulhu_total_cycles
    li      x23, 0                    # s7 (x23) = mulhu_call_count

    # Capture start performance counters
    csrr    x28, 0xB00                # mcycle start
    csrr    x29, 0xB02                # minstret start

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

    # Call Karatsuba MULHU implementation after N multiplies
    # Instrument call for profiling
    csrr    x24, 0xB00                # entry mcycle
    mv      a0, x5                    # First argument
    mv      a1, x6                    # Second argument
    call    __mulhu64_kara            # Call Karatsuba MULHU
    csrr    x25, 0xB00                # exit mcycle
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
    csrr    x30, 0xB00                # mcycle end
    csrr    x31, 0xB02                # minstret end

    # Store profiling results in memory for extraction
    la      x8, profiling_data
    sd      x23, 0(x8)                # Store call_count
    sd      x22, 8(x8)                # Store total_cycles
    sub     x9, x30, x28              # Total program cycles
    sd      x9, 16(x8)                # Store total_program_cycles

    # Calculate average cycles per call: total_cycles / call_count
    div     x26, x22, x23
    sd      x26, 24(x8)               # Store avg_cycles_per_call

    # Write result to tohost to signal completion
    la      x8, tohost
    li      x9, 1
    sd      x9, 0(x8)

done:
    j       done

# Karatsuba-style MULHU implementation (64-bit unsigned high multiply)
# Input: a0 = x (multiplicand), a1 = y (multiplier)
# Output: a0 = upper 64 bits of (x * y)
# Clobbers: t0-t6, a2-a7
#
# Simulates the latency of the Karatsuba algorithm with 'khi' CSR
# (uses mcycle CSR as placeholder for non-existent 'khi')
#
__mulhu64_kara:
    # --- Split into 32-bit halves (zero-extend) -----------------------------
    slli    t0, a0, 32
    srli    t0, t0, 32          # t0 = a0_lo = low32(x)
    srli    t1, a0, 32          # t1 = a0_hi = high32(x)

    slli    t2, a1, 32
    srli    t2, t2, 32          # t2 = b0_lo = low32(y)
    srli    t3, a1, 32          # t3 = b0_hi = high32(y)

    # --- p00 = a0_lo * b0_lo (mul #1) --------------------------------------
    mul     t4, t0, t2          # t4 = p00 (low 64)

    # --- p11 = a0_hi * b0_hi (mul #2) --------------------------------------
    mul     t5, t1, t3          # t5 = p11 (low 64)

    # --- sA = a0_lo + a0_hi; sB = b0_lo + b0_hi ----------------------------
    add     t6, t0, t1          # t6 = sA
    add     a2, t2, t3          # a2 = sB

    # --- p2 = (sA)*(sB), simulate extracting high bits with CSR read --------
    mul     a3, t6, a2          # a3 = low64(p2)
    csrr    a4, 0xB00           # Simulate 'csrr khi' - read high bits (use mcycle as placeholder)
    andi    a4, a4, 0x3         # Mask to 2 bits to simulate p2[65:64]

    # --- mid = p2 - p11 - p00  (66-bit: (p2_hi2:a3) - 64 - 64) ------------
    sub     a5, a3, t5          # mid_lo = p2_lo - p11
    sltu    a6, a3, t5          # a6: borrow from first subtract
    sub     a4, a4, a6          # mid_hi2 = p2_hi2 - borrow

    # Subtract p00
    sltu    a6, a5, t4          # a6: will we borrow?
    sub     a5, a5, t4          # mid_lo -= p00
    sub     a4, a4, a6          # mid_hi2 -= borrow

    # --- mid >> 32 (logical shift of a 66-bit value by 32) ------------------
    srli    a6, a5, 32          # low part >> 32
    slli    a7, a4, 32          # bring the 2 high bits down to [33:32]
    or      a6, a6, a7          # a6 = (mid >> 32) as 64-bit

    # --- c2 = ((p00 >> 32) + low32(mid_lo)) >> 32  (carry from low limb) ---
    srli    a7, t4, 32          # High 32 of p00
    li      t6, 0xFFFFFFFF      # 32-bit mask
    and     t6, a5, t6          # Low 32 bits of mid_lo
    add     a7, a7, t6
    srli    a7, a7, 32          # c2

    # --- hi = p11 + (mid >> 32) + c2 ---------------------------------------
    add     a0, t5, a6
    add     a0, a0, a7          # a0 = (x*y)>>64
    ret

.section .data
.align 3
profiling_data:
    .dword 0    # call_count (0x00)
    .dword 0    # total_cycles (0x08)
    .dword 0    # total_program_cycles (0x10)
    .dword 0    # avg_cycles_per_call (0x18)
    .dword 0    # reserved (0x20)

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0