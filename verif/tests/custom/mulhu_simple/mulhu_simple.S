# Hardware MULHU Simple Test
# Quick test with only 100 MULHU operations to verify profiling works

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 100        // Just 100 MULHU operations for quick test

_start:
    // Initialize test data
    // Use a0-a7 (x10-x17) and s-registers to avoid conflict with MULHU expander
    li      x10, 0x123456789ABCDEF0   // a0 = Test operand 1
    li      x11, 0x0FEDCBA987654321   // a1 = Test operand 2
    li      x12, 0                    // a2 = Accumulator
    li      x13, NUM_ITERATIONS       // a3 = Loop counter

    // Initialize profiling counters
    li      x21, 0                    // s5 (x21) = mulhu_total_cycles
    li      x22, 0                    // s6 (x22) = mulhu_call_count

    // Capture start performance counters
    csrr    x18, 0xB00                // s2 (x18) = mcycle - start
    csrr    x19, 0xB02                // s3 (x19) = minstret - start

test_loop:
    // Vary operands
    addi    x10, x10, 17
    xori    x11, x11, 0x5A

    // Profile single MULHU instruction
    csrr    x14, 0xB00                // a4 = Entry mcycle
    mulhu   x16, x10, x11             // a6 = MULHU result
    csrr    x15, 0xB00                // a5 = Exit mcycle
    sub     x15, x15, x14             // Delta cycles
    add     x21, x21, x15             // Accumulate total cycles
    addi    x22, x22, 1               // Increment call count
    add     x12, x12, x16             // Accumulate result

    // Continue loop
    addi    x13, x13, -1
    bnez    x13, test_loop

    // Capture end performance counters
    csrr    x9, 0xB00                 // mcycle - end
    csrr    x10, 0xB02                // minstret - end

    // Store profiling results in memory
    la      x8, profiling_data
    sd      x22, 0(x8)                // Store call_count
    sd      x21, 8(x8)                // Store total_cycles
    sub     x11, x9, x18              // Total program cycles
    sd      x11, 16(x8)               // Store total_program_cycles

    // Calculate average cycles per call
    div     x14, x21, x22
    sd      x14, 24(x8)               // Store avg_cycles_per_call

    // Calculate percentage: (mulhu_cycles * 100) / total_cycles
    li      x15, 100
    mul     x15, x21, x15
    div     x15, x15, x11
    sd      x15, 32(x8)               // Store percentage_of_total

    // Write to tohost to signal completion
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
    .dword 0    # percentage_of_total

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0