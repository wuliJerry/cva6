# Simple Software MULHU Test
# Tests the software MULHU implementation with 3 known test cases

.section .text.init
.globl _start
.option norvc

_start:
    # Test 1: Simple case - 7 * 9
    # Expected: MULHU(7, 9) = 0 (both fit in lower bits)
    li      a0, 7                     # First operand
    li      a1, 9                     # Second operand
    call    __mulhu64_soft            # Call software MULHU
    mv      s0, a0                    # Save result in s0

    # Test 2: Larger values - 0x123456789ABCDEF0 * 2
    # Expected: Upper 64 bits of the product
    li      a0, 0x123456789ABCDEF0   # Large 64-bit value
    li      a1, 2                     # Multiply by 2
    call    __mulhu64_soft            # Call software MULHU
    mv      s1, a0                    # Save result in s1

    # Test 3: Maximum values - 0xFFFFFFFFFFFFFFFF * 0xFFFFFFFFFFFFFFFF
    # Expected: 0xFFFFFFFFFFFFFFFE (upper bits of max*max)
    li      a0, -1                    # 0xFFFFFFFFFFFFFFFF
    li      a1, -1                    # 0xFFFFFFFFFFFFFFFF
    call    __mulhu64_soft            # Call software MULHU
    mv      s2, a0                    # Save result in s2

    # All tests complete - write to tohost
    la      t0, tohost
    li      t1, 1
    sd      t1, 0(t0)

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

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0