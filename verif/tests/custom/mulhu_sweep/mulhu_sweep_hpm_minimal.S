# Minimal HPM Test - Only Branch Mispredict Counter
# To isolate HPM overhead source

.section .text.init
.globl _start
.option norvc

#ifndef MULHU_INTERVAL
#define MULHU_INTERVAL 10000
#endif

#define TARGET_TOTAL_OPS 1000000
#define OUTER_LOOPS      (TARGET_TOTAL_OPS / MULHU_INTERVAL)

#define HPM_EVENT_BRANCH_MISPREDICT 10

#define CSR_MCYCLE          0xB00
#define CSR_MINSTRET        0xB02
#define CSR_MHPMCOUNTER3    0xB03
#define CSR_MHPMEVENT3      0x323
#define CSR_MCOUNTINHIBIT   0x320

_start:
    // Setup ONLY ONE HPM counter - branch mispredicts
    li      a0, HPM_EVENT_BRANCH_MISPREDICT
    csrw    CSR_MHPMEVENT3, a0
    csrwi   CSR_MHPMCOUNTER3, 0
    csrwi   CSR_MCOUNTINHIBIT, 0

    // Initialize test data
    li      x10, 0x123456789ABCDEF0
    li      x11, 0x0FEDCBA987654321
    li      x12, 0
    li      x13, OUTER_LOOPS
    li      x18, MULHU_INTERVAL - 1

    li      x19, 0                    // mulhu_total_cycles
    li      x20, 0                    // mulhu_call_count

    csrr    x21, CSR_MCYCLE
    csrr    x22, CSR_MINSTRET

outer_loop:
    mv      x14, x18

inner_loop:
    mul     x15, x10, x11
    add     x12, x12, x15
    addi    x10, x10, 17
    xori    x11, x11, 0x5A
    addi    x14, x14, -1
    bnez    x14, inner_loop

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

    csrr    x9, CSR_MCYCLE
    csrr    x10, CSR_MINSTRET

    la      x8, profiling_data

    sd      x20, 0(x8)
    sd      x19, 8(x8)
    sub     x11, x9, x21
    sd      x11, 16(x8)
    div     x14, x19, x20
    sd      x14, 24(x8)

    csrr    a0, CSR_MHPMCOUNTER3      // Branch mispredicts

    sd      a0, 32(x8)                // branch_mispredicts (triggers HPM mode)
    sd      zero, 40(x8)
    sd      zero, 48(x8)
    sd      zero, 56(x8)
    sd      zero, 64(x8)
    sd      zero, 72(x8)

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
    .dword 0    # branch_mispredicts (offset 0x20 to trigger HPM)
    .dword 0
    .dword 0
    .dword 0
    .dword 0
    .dword 0

.section .tohost
.align 6
tohost:     .dword 0
fromhost:   .dword 0