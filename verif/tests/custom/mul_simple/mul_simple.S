# Simple MUL Functionality Test
# Tests basic multiplier operation with a few known test cases

.section .text.init
.globl _start
.option norvc

_start:
    # Test 1: Simple small numbers
    li      x5, 7                     # 7
    li      x6, 9                     # 9
    mul     x7, x5, x6                # x7 = 63 (0x3F)

    # Test 2: Larger numbers
    li      x8, 12345                 # 12345
    li      x9, 6789                  # 6789
    mul     x10, x8, x9               # x10 = 83,810,205 (0x4FEF32D)

    # Test 3: Negative number (sign-extended)
    li      x11, -5                   # -5
    li      x12, 3                    # 3
    mul     x13, x11, x12             # x13 = -15 (0xFFFFFFFFFFFFFFF1 in 64-bit)

    # Test 4: 64-bit values
    li      x14, 0x123456789ABCDEF0  # Large 64-bit value
    li      x15, 2                    # Multiply by 2
    mul     x16, x14, x15             # x16 = 0x2468ACF13579BDE0

    # Test 5: Zero multiplication
    li      x17, 42                   # 42
    li      x18, 0                    # 0
    mul     x19, x17, x18             # x19 = 0

    # Test 6: Multiply by 1 (identity)
    li      x20, 0xDEADBEEF           # 0xDEADBEEF
    li      x21, 1                    # 1
    mul     x22, x20, x21             # x22 = 0xDEADBEEF

    # Test 7: Powers of 2 (shift equivalent)
    li      x23, 100                  # 100
    li      x24, 16                   # 16 = 2^4
    mul     x25, x23, x24             # x25 = 1600 (0x640)

    # Test 8: Both operands same
    li      x26, 13                   # 13
    mul     x27, x26, x26             # x27 = 169 (0xA9)

    # All tests complete - write to tohost
    la      x28, tohost
    li      x29, 1
    sd      x29, 0(x28)

done:
    j       done

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0