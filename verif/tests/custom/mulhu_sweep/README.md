# MULHU Frequency Sweep Benchmark

A synthetic RISC-V assembly benchmark to measure the performance impact of MULHU (multiply high unsigned) instruction frequency.

## Overview

This benchmark performs a tight loop of `MUL` instructions with periodic `MULHU` operations. By varying the ratio of MULHU to MUL, you can measure how MULHU frequency affects overall IPC (Instructions Per Cycle).

## Benchmark Design

**Structure:**
- Inner loop: Performs `N` MUL operations
- After each inner loop: Performs 1 MULHU operation
- Outer loop: Repeats the pattern 100 times

**Key Features:**
- Uses mcycle/minstret CSRs for accurate performance measurement
- Accumulates results to prevent compiler optimization
- Varies operands to prevent hardware prediction/optimization
- Self-contained (no external dependencies)

## Configurations

| N Value | MULHU Frequency | Description |
|---------|----------------|-------------|
| 10,000  | ~0.01%         | Baseline (very rare MULHU) |
| 1,000   | ~0.1%          | Occasional MULHU |
| 100     | ~1%            | Moderate MULHU |
| 10      | ~10%           | Frequent MULHU |

### Total Instruction Count

Each configuration performs approximately:
- **N=10000**: ~1,000,000 MULs + 100 MULHUs + overhead
- **N=1000**: ~100,000 MULs + 100 MULHUs + overhead
- **N=100**: ~10,000 MULs + 100 MULHUs + overhead
- **N=10**: ~1,000 MULs + 100 MULHUs + overhead

Total instruction count varies but remains in the same order of magnitude for fair comparison.

## Building

### Single Configuration

```bash
# Build with N=10000 (0.01% MULHU)
make

# Build with custom N value
make MULHU_INTERVAL=1000
make MULHU_INTERVAL=100
make MULHU_INTERVAL=10
```

### All Configurations

```bash
# Build all sweep points at once
make sweep-all
```

This will create:
- `mulhu_sweep_n10000.elf` - 0.01% MULHU
- `mulhu_sweep_n1000.elf` - 0.1% MULHU
- `mulhu_sweep_n100.elf` - 1% MULHU
- `mulhu_sweep_n10.elf` - 10% MULHU

## Running Simulations

### With VCS Testharness

```bash
cd /home/ruijieg/cva6/verif/sim

# Run N=10000 configuration
make vcs-testharness \
  path_var=../.. \
  elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10000.elf \
  target=cv64a6_imafdc_sv39 \
  log=results/mulhu_n10000.log \
  variant=rv64imac \
  tool_path=/home/ruijieg/cva6/tools/spike/bin

# Repeat for other configurations...
```

### Automated Sweep Script

You can create a script to run all configurations:

```bash
#!/bin/bash
cd /home/ruijieg/cva6/verif/sim

for N in 10000 1000 100 10; do
  echo "Running MULHU sweep with N=$N..."
  make vcs-testharness \
    path_var=../.. \
    elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n${N}.elf \
    target=cv64a6_imafdc_sv39 \
    log=results/mulhu_n${N}.log \
    variant=rv64imac \
    tool_path=/home/ruijieg/cva6/tools/spike/bin

  # Extract performance data
  echo "N=$N Results:"
  cat perf_counters_hart_00.log | grep -E "Total|IPC"
  echo ""
done
```

## Expected Results

Performance metrics will be available in:
1. **Console output**: Summary at end of simulation
2. **perf_counters_hart_00.log**: Detailed cycle/instruction counts
3. **Simulation log**: Full trace

### Analysis Metrics

Compare across configurations:
- **IPC (Instructions Per Cycle)**
- **CPI (Cycles Per Instruction)**
- **Total execution time**
- **MULHU impact**: How IPC changes as MULHU frequency increases

### Example Expected Behavior

If MULHU has higher latency than MUL:
- N=10000 (0.01% MULHU): Highest IPC (MULHU impact negligible)
- N=1000 (0.1% MULHU): Slightly lower IPC
- N=100 (1% MULHU): Noticeably lower IPC
- N=10 (10% MULHU): Lowest IPC (MULHU latency dominates)

## Files

- `mulhu_sweep.S` - Assembly source code
- `Makefile` - Build system
- `README.md` - This file
- `mulhu_sweep_n*.elf` - Compiled binaries (after build)
- `mulhu_sweep_n*.dump` - Disassembly files (after build)

## Modifying the Benchmark

To adjust the benchmark characteristics, edit `mulhu_sweep.S`:

```assembly
#define MULHU_INTERVAL 10000    // N parameter
#define OUTER_LOOPS    100      // Number of repetitions
```

**Note**: The `MULHU_INTERVAL` is overridden by the Makefile's `-DMULHU_INTERVAL` flag.

## License

Apache-2.0

## Author

Created for CVA6 performance analysis