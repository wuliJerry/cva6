# MULHU Software Implementation Sweep Benchmark

## Overview

This benchmark compares the performance of a **software implementation** of the MULHU (multiply high unsigned) instruction against the hardware MULHU instruction used in the `mulhu_sweep` benchmark.

The software implementation decomposes a 64-bit × 64-bit multiply into four 32-bit × 32-bit multiplies and combines them to compute the upper 64 bits of the 128-bit result.

## Software MULHU Implementation

The `__mulhu64_soft` function implements MULHU using only basic RV64I multiply instructions:

```assembly
__mulhu64_soft:
    # Decompose inputs into 32-bit halves
    srli t1, a0, 32        # t1 = high(a0)
    li   t4, -1
    srli t4, t4, 32        # t4 = 0x00000000FFFFFFFF (mask)
    and  t0, a0, t4        # t0 = low(a0)

    srli t3, a1, 32        # t3 = high(a1)
    and  t2, a1, t4        # t2 = low(a1)

    # Four partial products
    mul  t4, t0, t2        # low × low
    mul  t5, t0, t3        # low × high
    mul  t6, t1, t2        # high × low
    mul  a0, t1, t3        # high × high

    # Combine partial products to get upper 64 bits
    srli t0, t4, 32        # high half of (low×low)
    add  t5, t5, t0        # add to middle
    sltu t0, t5, t0        # capture carry

    add  t1, t5, t6        # combine middle terms
    sltu t2, t1, t6        # capture carry
    add  t0, t0, t2        # total carry

    slli t0, t0, 32        # position carry
    srli t1, t1, 32        # high bits of middle
    or   t0, t0, t1        # combine
    add  a0, a0, t0        # final result

    ret
```

## Benchmark Structure

Similar to the hardware MULHU sweep, this benchmark:
- Executes N regular `mul` instructions in an inner loop
- Calls `__mulhu64_soft` after every N multiplies
- Repeats the pattern 100 times for each configuration
- Measures mcycle and minstret for performance analysis

**Key Difference**: Instead of executing a single MULHU instruction, it performs a function call to the software implementation, which uses ~20 instructions.

## Configurations

Four sweep points model different MULHU occurrence frequencies:

| Config | N value | MULHU Frequency | ELF File |
|--------|---------|-----------------|----------|
| n10000 | 10,000  | ~0.01%          | mulhu_soft_sweep_n10000.elf |
| n1000  | 1,000   | ~0.1%           | mulhu_soft_sweep_n1000.elf |
| n100   | 100     | ~1%             | mulhu_soft_sweep_n100.elf |
| n10    | 10      | ~10%            | mulhu_soft_sweep_n10.elf |

## Building

```bash
# Build all configurations
make all

# Or build individual configurations
make build-variant MULHU_INTERVAL=10000
make build-variant MULHU_INTERVAL=1000
```

## Running Simulations

### With trace files disabled (recommended for performance):

```bash
# Window 1 - N=10000
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_sweep/mulhu_soft_sweep_n10000.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mulhu_soft_n10000.log"

# Window 2 - N=1000
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_sweep/mulhu_soft_sweep_n1000.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mulhu_soft_n1000.log"

# Window 3 - N=100
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_sweep/mulhu_soft_sweep_n100.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mulhu_soft_n100.log"

# Window 4 - N=10
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_sweep/mulhu_soft_sweep_n10.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mulhu_soft_n10.log"
```

## Performance Analysis

After running simulations, compare the performance counters between:
- **Hardware MULHU**: `perf_mulhu_n*.log`
- **Software MULHU**: `perf_mulhu_soft_n*.log`

Expected results:
- Software implementation will have **higher instruction count** (~20 instructions per MULHU vs 1)
- Software implementation may have **higher cycle count** depending on pipeline behavior
- The overhead will be more visible at higher MULHU frequencies (N=10)

## Instruction Count Comparison

For N=10000 configuration (100 MULHU operations):

**Hardware MULHU**:
- ~1,000,100 instructions (100 MULHU + 1M MUL + overhead)

**Software MULHU**:
- ~1,002,000 instructions (100 × 20 instruction function + 1M MUL + overhead)
- **Delta**: ~2000 more instructions (2%)

For N=10 configuration (100,000 MULHU operations):

**Hardware MULHU**:
- ~1,100,000 instructions

**Software MULHU**:
- ~3,000,000 instructions
- **Delta**: ~1.9M more instructions (173%)

## Use Case

This benchmark helps quantify:
1. The performance cost of emulating MULHU in software
2. Whether MULHU instruction is worth the hardware complexity for different workload profiles
3. Pipeline efficiency for function calls vs single-instruction execution