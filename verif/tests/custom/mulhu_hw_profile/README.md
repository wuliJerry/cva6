# Hardware MULHU Profiling Benchmarks

This directory contains benchmarks to measure the performance characteristics of the hardware MULHU instruction on CVA6.

## Overview

These benchmarks complement the software MULHU implementation benchmarks by providing direct measurements of hardware MULHU latency and throughput.

## Benchmarks

### 1. Single-Instruction Profiling (`mulhu_single_instr.S`)

**Purpose**: Measure the latency of a single MULHU instruction with realistic operand patterns.

**Method**:
- Execute 10,000 MULHU instructions
- Measure each with CSR reads before/after
- Vary operand values to avoid optimization

**Expected Results**:
- **Best case**: 1-2 cycles (fully pipelined)
- **Typical**: 3-5 cycles (multi-stage pipeline)
- **Worst case**: 10-20 cycles (sequential multiplier)

**Comparison**: Directly comparable to software MULHU's 28-29 cycles/call.

### 2. Dependent Chain (`mulhu_dependent_chain.S`)

**Purpose**: Measure true instruction latency by creating data dependencies.

**Method**:
- Chain 10 dependent MULHU operations
- Each MULHU uses the result of the previous one
- Measure 1,000 chains

**What it reveals**:
- **True latency**: If MULHU takes L cycles, chain takes ~10×L cycles
- **Pipeline depth**: How many stages the multiplier has
- **Forwarding**: Whether results can be forwarded before completion

**Example**:
```assembly
mulhu x13, x5, x6    # Cycle 0: start
mulhu x14, x13, x6   # Must wait for x13
mulhu x15, x14, x6   # Must wait for x14
...
```

If chain of 10 takes 30 cycles → each MULHU is 3 cycles latency.

### 3. Parallel Independent (`mulhu_parallel_independent.S`)

**Purpose**: Measure instruction-level parallelism (ILP) and throughput.

**Method**:
- Execute 10 independent MULHU operations
- No data dependencies between them
- Measure 1,000 groups

**What it reveals**:
- **Throughput**: Can multiple MULHUs execute simultaneously?
- **Superscalar**: Does CVA6 have multiple execution units?
- **Resource conflicts**: Are there multiplier port bottlenecks?

**Example**:
```assembly
mulhu x18, x5, x6     # Independent
mulhu x19, x10, x11   # Independent
mulhu x21, x12, x13   # Independent
...
```

**Possible outcomes**:
- **10 MULHUs in 10 cycles**: No parallelism (scalar execution)
- **10 MULHUs in 5 cycles**: 2-way superscalar
- **10 MULHUs in 30 cycles**: 3-cycle latency, no overlap

### 4. CSR Overhead Calibration (`csr_overhead_calibration.S`)

**Purpose**: Measure the overhead of performance measurement itself.

**Method**:
- Measure cycles around NOP instruction
- This gives the cost of: `csrr + nop + csrr + sub + add + addi`
- Subtract this from MULHU measurements

**Expected overhead**: 2-4 cycles per measurement.

**How to use**:
```
True MULHU latency = Measured latency - CSR overhead
```

## Building

```bash
make all      # Build all benchmarks
make single   # Build only single-instruction test
make calib    # Build only calibration test
make clean    # Clean build artifacts
make check    # Show benchmark descriptions
```

## Running

From `verif/sim` directory:

```bash
# Run single-instruction profiling
make vcs-testharness path_var=../.. \
  elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_hw_profile/mulhu_single_instr.elf \
  target=cv64a6_imafdc_sv39 \
  log=results/mulhu_hw_single.log \
  issrun_opts="+instr_trace_disable +perf_log_file=mulhu_hw_single_perf.log"

# Run dependent chain test
make vcs-testharness path_var=../.. \
  elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_hw_profile/mulhu_dependent_chain.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=mulhu_hw_dependent_perf.log"

# Run parallel independent test
make vcs-testharness path_var=../.. \
  elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_hw_profile/mulhu_parallel_independent.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=mulhu_hw_parallel_perf.log"

# Run calibration
make vcs-testharness path_var=../.. \
  elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_hw_profile/csr_overhead_calibration.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=csr_overhead_perf.log"
```

## Interpreting Results

After running, check the performance log files for the "__mulhu64_soft FUNCTION PROFILING RESULTS" section (even though it's hardware MULHU, the profiler module will capture it with the same format).

### Example Analysis

**Calibration result**: 3 cycles overhead
**Single-instruction result**: 8 cycles measured
**True MULHU latency**: 8 - 3 = **5 cycles**

**Dependent chain result**: 52 cycles for 10 MULHUs
**Per-MULHU latency**: 52 / 10 = **5.2 cycles** ✓ (matches single-instruction)

**Parallel independent result**: 55 cycles for 10 MULHUs
**Interpretation**: ~5.5 cycles per MULHU, no significant ILP benefit → likely scalar execution

### Comparison to Software

If hardware MULHU is 5 cycles and software is 28 cycles:
- **Speedup**: 28 / 5 = **5.6×** faster with hardware
- **At 10% frequency**: Software overhead = 28 × 100K = 2.8M cycles
                         Hardware overhead = 5 × 100K = 500K cycles
                         **Savings**: 2.3M cycles (82% reduction)

## Files

- `mulhu_single_instr.S` - Single instruction profiling
- `mulhu_dependent_chain.S` - Dependent chain latency test
- `mulhu_parallel_independent.S` - Parallel throughput test
- `csr_overhead_calibration.S` - Measurement overhead calibration
- `Makefile` - Build system
- `README.md` - This file

## Implementation Notes

All benchmarks use the same profiling infrastructure as software MULHU:
- Profile data stored at `0x80002000`
- Captured by `function_profiler.sv` module
- Results appended to performance log
- Same metrics: call count, total cycles, avg cycles/call, percentage

This ensures direct comparability between hardware and software implementations.