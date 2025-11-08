# CVA6 Levenshtein Benchmark - Pure Assembly with MULHU
# Implements levenshtein distance algorithm
# Contains ~1% MULHU instructions (in profiling/division code)
#
# Based on BEEBS benchmark but written in assembly for full control

.section .text.init
.globl _start
.option norvc

#define NUM_ITERATIONS 100    // 100 iterations × 25 string pairs = 2500 calls

_start:
    # Initialize all registers to zero
    li      x1, 0
    li      x2, 0
    li      x3, 0
    li      x4, 0
    li      x5, 0
    li      x6, 0
    li      x7, 0
    li      x8, 0
    li      x9, 0
    li      x10, 0
    li      x11, 0
    li      x12, 0
    li      x13, 0
    li      x14, 0
    li      x15, 0
    li      x16, 0
    li      x17, 0
    li      x18, 0
    li      x19, 0
    li      x20, 0
    li      x21, 0
    li      x22, 0
    li      x23, 0
    li      x24, 0
    li      x25, 0
    li      x26, 0
    li      x27, 0
    li      x28, 0
    li      x29, 0
    li      x30, 0
    li      x31, 0

    # Set up stack pointer
    la      sp, _end
    li      t0, 8192          # 8KB stack
    add     sp, sp, t0

    # Initialize profiling counters
    li      s5, 0             # s5 (x21) = total_cycles in function
    li      s6, 0             # s6 (x22) = call_count

    # Capture start performance counters
    csrr    s2, 0xB00         # s2 (x18) = mcycle_start
    csrr    s3, 0xB02         # s3 (x19) = minstret_start

    # Initialize iteration counter and sum
    li      s7, NUM_ITERATIONS  # s7 (x23) = outer loop counter
    li      s8, 0               # s8 (x24) = sum accumulator
    li      s1, 0               # s1 (x9) = mulhu_checksum (separate from sum)

outer_loop:
    # Inner loops: compare all 5×5 string pairs
    la      s9, string_ptrs     # s9 (x25) = outer string array pointer
    li      s10, 5              # s10 (x26) = outer loop counter (i)

outer_string_loop:
    ld      s4, 0(s9)           # s4 (x20) = strings[i]
    la      s11, string_ptrs    # s11 (x27) = inner string array pointer
    li      t3, 5               # t3 (x28) = inner loop counter (j)

inner_string_loop:
    # Load string pointers
    mv      a0, s4              # a0 = strings[i]
    ld      a1, 0(s11)          # a1 = strings[j]

    # Profile function entry
    csrr    a4, 0xB00           # a4 (x14) = entry mcycle

    # Call levenshtein_distance(strings[i], strings[j])
    call    levenshtein_distance

    # Profile function exit
    csrr    a5, 0xB00           # a5 (x15) = exit mcycle
    sub     a5, a5, a4          # Delta cycles
    add     s5, s5, a5          # Accumulate total cycles
    addi    s6, s6, 1           # Increment call count

    # Accumulate result
    add     s8, s8, a0          # sum += result

    # Mixed multiply operations to achieve ~1% MULHU ratio
    # For every 1 MULHU, we need ~99 MUL operations
    # We'll compute some dummy MUL-based operations using loop indices
    # NOTE: Uses a2-a3 which are NOT used by mulhu_expander (uses t0-t6)

    # Add 100 MUL operations per levenshtein call to balance 1 MULHU
    li      a2, 100             # Counter for MUL operations
mul_loop:
    mul     a3, a0, s6          # Dummy: result * call_count (low 64 bits)
    add     s1, s1, a3          # Accumulate (keeps CPU busy, doesn't affect correctness)
    addi    a2, a2, -1
    bnez    a2, mul_loop

    # Now add 1 MULHU operation (high 64 bits)
    li      a2, 0x9E3779B97F4A7C15  # Large prime constant
    mulhu   a3, a0, a2          # High 64 bits: this is the 1%
    add     s1, s1, a3          # Accumulate checksum

    # Inner loop control
    addi    s11, s11, 8         # Next string pointer
    addi    t3, t3, -1
    bnez    t3, inner_string_loop

    # Outer loop control
    addi    s9, s9, 8           # Next string pointer
    addi    s10, s10, -1
    bnez    s10, outer_string_loop

    # Iteration control
    addi    s7, s7, -1
    bnez    s7, outer_loop

    # Capture end performance counters
    csrr    a3, 0xB00           # a3 (x13) = mcycle_end
    csrr    a4, 0xB02           # a4 (x14) = minstret_end

    # Calculate total program cycles
    sub     a5, a3, s2          # a5 = total_program_cycles

    # Store profiling results in memory
    la      a2, profiling_data
    sd      s6, 0(a2)           # call_count
    sd      s5, 8(a2)           # total_cycles
    sd      a5, 16(a2)          # total_program_cycles

    # Calculate average cycles per call using division
    # This generates MULHU when optimized, or we use mulhu64_soft simulation
    div     a6, s5, s6
    sd      a6, 24(a2)          # avg_cycles_per_call

    # NOTE: Do NOT write to offset 0x20 (32)!
    # The profiler interprets offset 0x20 as icache_misses (HPM field)
    # and will trigger HPM mode, expecting more fields at 0x28, 0x30, etc.
    # The percentage calculation is done automatically by the profiler.

    # Verify result: expected = 122 * NUM_ITERATIONS
    li      t1, 122
    li      t2, NUM_ITERATIONS
    mul     t1, t1, t2          # Another MUL instruction
    bne     s8, t1, test_fail

test_pass:
    # Success: write 1 to tohost
    la      t0, tohost
    li      t1, 1
    sd      t1, 0(t0)
    j       done

test_fail:
    # Failure: write 3 to tohost
    la      t0, tohost
    li      t1, 3
    sd      t1, 0(t0)

done:
    j       done

#==============================================================================
# levenshtein_distance - compute edit distance between two strings
# Input:  a0 = pointer to string s
#         a1 = pointer to string t
# Output: a0 = edit distance
# Uses: distance matrix in data section (avoids stack issues)
#==============================================================================
levenshtein_distance:
    addi    sp, sp, -80
    sd      ra, 72(sp)
    sd      s0, 64(sp)
    sd      s1, 56(sp)
    sd      s2, 48(sp)
    sd      s3, 40(sp)
    sd      s4, 32(sp)
    sd      s5, 24(sp)
    sd      s6, 16(sp)
    sd      s7, 8(sp)
    sd      s8, 0(sp)

    mv      s0, a0              # s0 = string s
    mv      s1, a1              # s1 = string t

    # Get string lengths
    call    my_strlen
    mv      s2, a0              # s2 = sl (length of s)

    mv      a0, s1
    call    my_strlen
    mv      s3, a0              # s3 = tl (length of t)

    # Load base address of distance matrix
    la      s4, dist_matrix

    # Initialize first column: d[i][0] = i
    li      s5, 0               # i = 0
init_first_column:
    # Calculate address: &d[i][0] = base + i * 16 * 4
    slli    t0, s5, 6           # i * 64 (16 words/row * 4 bytes/word)
    add     t0, s4, t0
    sw      s5, 0(t0)           # d[i][0] = i
    addi    s5, s5, 1
    addi    t1, s2, 2
    blt     s5, t1, init_first_column

    # Initialize first row: d[0][j] = j
    li      s5, 0               # j = 0
init_first_row:
    slli    t0, s5, 2           # j * 4
    add     t0, s4, t0
    sw      s5, 0(t0)           # d[0][j] = j
    addi    s5, s5, 1
    addi    t1, s3, 2
    blt     s5, t1, init_first_row

    # Main DP algorithm: for j = 1 to tl
    li      s6, 1               # j = 1
dp_outer_loop:
    # for i = 1 to sl
    li      s7, 1               # i = 1

dp_inner_loop:
    # Load s[i-1]
    addi    t0, s7, -1
    add     t0, s0, t0
    lbu     t0, 0(t0)           # t0 = s[i-1]

    # Load t[j-1]
    addi    t1, s6, -1
    add     t1, s1, t1
    lbu     t1, 0(t1)           # t1 = t[j-1]

    # Calculate address of d[i][j]: base + i*64 + j*4
    slli    t2, s7, 6
    slli    t3, s6, 2
    add     t2, t2, t3
    add     t2, s4, t2          # t2 = &d[i][j]

    # Check if s[i-1] == t[j-1]
    bne     t0, t1, chars_differ

    # Characters match: d[i][j] = d[i-1][j-1]
    addi    t3, s7, -1
    slli    t3, t3, 6
    addi    t4, s6, -1
    slli    t4, t4, 2
    add     t3, t3, t4
    add     t3, s4, t3
    lw      t3, 0(t3)           # t3 = d[i-1][j-1]
    sw      t3, 0(t2)           # d[i][j] = d[i-1][j-1]
    j       dp_next_i

chars_differ:
    # Load d[i-1][j] + 1 (deletion)
    addi    t3, s7, -1
    slli    t3, t3, 6
    slli    t4, s6, 2
    add     t3, t3, t4
    add     t3, s4, t3
    lw      t3, 0(t3)
    addi    t3, t3, 1           # t3 = d[i-1][j] + 1

    # Load d[i][j-1] + 1 (insertion)
    slli    t4, s7, 6
    addi    t5, s6, -1
    slli    t5, t5, 2
    add     t4, t4, t5
    add     t4, s4, t4
    lw      t4, 0(t4)
    addi    t4, t4, 1           # t4 = d[i][j-1] + 1

    # min(t3, t4)
    blt     t3, t4, use_deletion
    mv      t3, t4
use_deletion:

    # Load d[i-1][j-1] + 1 (substitution)
    addi    t4, s7, -1
    slli    t4, t4, 6
    addi    t5, s6, -1
    slli    t5, t5, 2
    add     t4, t4, t5
    add     t4, s4, t4
    lw      t4, 0(t4)
    addi    t4, t4, 1           # t4 = d[i-1][j-1] + 1

    # min(t3, t4)
    blt     t3, t4, store_min
    mv      t3, t4

store_min:
    sw      t3, 0(t2)           # d[i][j] = min value

dp_next_i:
    addi    s7, s7, 1           # i++
    addi    t0, s2, 1
    ble     s7, t0, dp_inner_loop

    addi    s6, s6, 1           # j++
    addi    t0, s3, 1
    ble     s6, t0, dp_outer_loop

    # Return d[sl][tl]
    slli    t0, s2, 6
    slli    t1, s3, 2
    add     t0, t0, t1
    add     t0, s4, t0
    lw      a0, 0(t0)           # a0 = d[sl][tl]

    ld      ra, 72(sp)
    ld      s0, 64(sp)
    ld      s1, 56(sp)
    ld      s2, 48(sp)
    ld      s3, 40(sp)
    ld      s4, 32(sp)
    ld      s5, 24(sp)
    ld      s6, 16(sp)
    ld      s7, 8(sp)
    ld      s8, 0(sp)
    addi    sp, sp, 80
    ret

#==============================================================================
# my_strlen - calculate string length
# Input:  a0 = pointer to string
# Output: a0 = length
#==============================================================================
my_strlen:
    mv      t0, a0              # Save original pointer
    li      a0, 0               # Length = 0
strlen_loop:
    lbu     t1, 0(t0)
    beqz    t1, strlen_done
    addi    t0, t0, 1
    addi    a0, a0, 1
    j       strlen_loop
strlen_done:
    ret

#==============================================================================
# Data section
#==============================================================================
.section .rodata
.align 3

# Test strings (same as BEEBS)
str0: .string "srrjngre"
str1: .string "asfcjnsdkj"
str2: .string "string"
str3: .string "msd"
str4: .string "strings"

.align 3
string_ptrs:
    .dword str0
    .dword str1
    .dword str2
    .dword str3
    .dword str4

.section .data
# Force profiling_data to start at 0x80002000 to match function_profiler.sv default
.org 0x2000

# Profiling data - address will be visible to function_profiler.sv
profiling_data:
    .dword 0    # +0x00: call_count
    .dword 0    # +0x08: total_cycles
    .dword 0    # +0x10: total_program_cycles
    .dword 0    # +0x18: avg_cycles_per_call

# Reserve space for potential HPM fields (0x20 to 0x4F)
# Even though we don't use them, we need to prevent dist_matrix from overlapping
# Otherwise writes to dist_matrix will trigger profiler's HPM detection
.space 64       # Reserve 64 bytes (0x20-0x5F) to avoid HPM field collision

# Distance matrix (16×16 words = 1024 bytes)
.align 3
dist_matrix:
    .space 1024

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0
