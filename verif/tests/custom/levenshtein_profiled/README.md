# CVA6 Profiled Levenshtein Benchmark

A CVA6-compatible version of the BEEBS levenshtein benchmark with integrated function profiling support.

## Quick Start

### Build
```bash
cd /home/ruijieg/cva6/verif/tests/custom/levenshtein_profiled
make
```

### Run Simulation
```bash
cd /home/ruijieg/cva6

make vcs-testharness \
    path_var=../.. \
    elf=/home/ruijieg/cva6/verif/tests/custom/levenshtein_profiled/levenshtein_profiled.elf \
    target=cv64a6_imafdc_sv39 \
    log=results/levenshtein_profiled.log \
    variant=rv64imac \
    tool_path=/home/ruijieg/cva6/tools/spike/bin \
    issrun_opts="+instr_trace_disable +perf_log_file=perf_levenshtein.log"
```

## Overview

The benchmark:
- Implements the Levenshtein distance algorithm (string edit distance)
- Profiles the `levenshtein_distance()` function execution
- Measures cycles, call counts, and performance metrics
- **Contains MULHU instruction** (compiler-generated for division optimization)
- **Safe with MULHU expander** - no register conflicts
- **Compatible with function_profiler.sv** - writes to `0x80002000`

## Key Features

### MULHU Instruction
- **Location**: Address `0x800038f2` in `main()`
- **Purpose**: Optimized division for calculating `avg_cycles_per_call`
- **Count**: 1 MULHU + 8 MUL instructions in the binary

The compiler optimizes `total_func_cycles / call_count` using:
```assembly
mulhu a5, s1, a5    # multiply by reciprocal instead of divide
```

### Profiling Data Address
- **Write address**: `0x80002000` (compatible with function_profiler.sv default)
- **Pointer variable**: `0x80003b60` (holds the value `0x80002000`)

The benchmark writes profiling results to memory at `0x80002000`:
```c
volatile profiling_data_t *profiling_data = (volatile profiling_data_t *)0x80002000;
profiling_data->call_count = ...;
profiling_data->total_cycles = ...;
```

### Register Safety
✓ **No conflicts** with MULHU expander

**MULHU expander uses**: t0-t6 (x5-x7, x28-x31)
**Benchmark uses**: s0-s7, a0-a7
**Result**: No overlap!

## Files

- `levenshtein_profiled.c` - Main benchmark with profiling
- `Makefile` - Build configuration
- `levenshtein_profiled.elf` - Compiled binary (generated)
- `levenshtein_profiled.dump` - Disassembly (generated)
- `README.md` - This file

## Building

### Default Build (100 iterations = 2,500 calls)
```bash
make
```

### Custom Iterations
```bash
make NUM_ITERATIONS=1000  # 25,000 function calls
```

### Clean
```bash
make clean
```

## Running Simulations

### Quick Test (< 1 min)
```bash
make clean
make NUM_ITERATIONS=10
cd /home/ruijieg/cva6
make vcs-testharness \
    path_var=../.. \
    elf=/home/ruijieg/cva6/verif/tests/custom/levenshtein_profiled/levenshtein_profiled.elf \
    target=cv64a6_imafdc_sv39 \
    log=results/levenshtein_quick.log \
    variant=rv64imac \
    tool_path=/home/ruijieg/cva6/tools/spike/bin \
    issrun_opts="+instr_trace_disable +perf_log_file=perf_levenshtein_quick.log"
```

### Standard Test (~2-5 min)
```bash
make clean
make  # NUM_ITERATIONS=100
cd /home/ruijieg/cva6
make vcs-testharness \
    path_var=../.. \
    elf=/home/ruijieg/cva6/verif/tests/custom/levenshtein_profiled/levenshtein_profiled.elf \
    target=cv64a6_imafdc_sv39 \
    log=results/levenshtein_profiled.log \
    variant=rv64imac \
    tool_path=/home/ruijieg/cva6/tools/spike/bin \
    issrun_opts="+instr_trace_disable +perf_log_file=perf_levenshtein.log"
```

### Long Test (~10-20 min)
```bash
make clean
make NUM_ITERATIONS=1000
cd /home/ruijieg/cva6
make vcs-testharness \
    path_var=../.. \
    elf=/home/ruijieg/cva6/verif/tests/custom/levenshtein_profiled/levenshtein_profiled.elf \
    target=cv64a6_imafdc_sv39 \
    log=results/levenshtein_long.log \
    variant=rv64imac \
    tool_path=/home/ruijieg/cva6/tools/spike/bin \
    issrun_opts="+instr_trace_disable +perf_log_file=perf_levenshtein_long.log" \
    max_cycles=20000000
```

## Cycle Estimates & Timeouts

| NUM_ITERATIONS | Total Calls | Est. Cycles | Recommended max_cycles | Est. Time |
|----------------|-------------|-------------|------------------------|-----------|
| 10             | 250         | ~50K        | 10M (default)          | < 1 min   |
| 100 (default)  | 2,500       | ~500K       | 10M (default)          | 2-5 min   |
| 1,000          | 25,000      | ~5M         | 20M                    | 10-20 min |
| 10,000         | 250,000     | ~50M        | 100M                   | 1-2 hours |

**Default** `max_cycles=10000000` is sufficient for up to 1000 iterations.

## Profiling Output

### 1. Performance Counters (perf_counter_logger.sv)

File: `perf_levenshtein.log`

```
================================================================================
 CVA6 Performance Summary (Hart 0x00)
================================================================================
 Total Cycles:       XXXXXX
 Total Instructions: XXXXXX
 IPC:                X.XXXXXX
 CPI:                X.XXXXXX
================================================================================
```

### 2. Function Profiling (function_profiler.sv)

**Requirement**: function_profiler.sv must be instantiated with `PROFILING_ADDR = 64'h80002000`

Appended to `perf_levenshtein.log`:

```
================================================================================
 levenshtein_distance FUNCTION PROFILING RESULTS
================================================================================

Call Count:             2500
Total Cycles in Func:   XXXXXX
Total Program Cycles:   XXXXXX
Avg Cycles per Call:    XXX
Percentage of Total:    XX%

================================================================================
```

## Verification

The benchmark self-verifies:
- Expected result: `122 × NUM_ITERATIONS`
- Exit code `0` = PASS
- Exit code `1` = FAIL

## Comparison with BEEBS Original

### Same As BEEBS
- Levenshtein distance algorithm implementation
- Test data: 5 strings {"srrjngre", "asfcjnsdkj", "string", "msd", "strings"}
- Verification: sum = 122

### Modified for CVA6
- **Profiling**: Added cycle counting around each function call
- **Iterations**: Default 100 (vs 4096 in BEEBS) for faster simulation
- **Startup**: Uses CVA6's [crt.S](../common/crt.S) instead of BEEBS board support
- **Exit**: Uses CVA6 tohost/fromhost mechanism
- **Profiling address**: Writes to fixed address `0x80002000`

## Troubleshooting

### Simulation times out
```bash
# Increase max_cycles
make vcs-testharness ... max_cycles=100000000
```

### No profiling output in log
1. Verify `function_profiler.sv` is instantiated in testbench
2. Check `PROFILING_ADDR` parameter is `64'h80002000`
3. Ensure `+perf_log_file` is passed in `issrun_opts`
4. Check simulation completed successfully (not timed out)

### Test fails (wrong result)
1. Verify NUM_ITERATIONS matches between build and expected result
2. Check for stack overflow in logs
3. Look for memory corruption issues

### Want to verify MULHU location
```bash
grep -i "mulhu" levenshtein_profiled.dump
# Should show: 800038f2:	02f4b7b3          	mulhu	a5,s1,a5
```

### Want to verify profiling address
```bash
riscv64-unknown-elf-objdump -s levenshtein_profiled.elf | grep -A 5 "Contents of section .sdata"
# Should show profiling_data pointer = 0x0000000080002000
```

## Advanced Topics

### Adding HPM (Hardware Performance Monitor) Profiling

To add microarchitectural metrics (like icache misses, branch mispredicts), extend the profiling_data structure:

```c
typedef struct {
    uint64_t call_count;              // +0x00
    uint64_t total_cycles;            // +0x08
    uint64_t total_program_cycles;    // +0x10
    uint64_t avg_cycles_per_call;     // +0x18
    uint64_t percentage_of_total;     // +0x20
    // Extended HPM fields:
    uint64_t icache_misses;           // +0x28
    uint64_t branch_mispredicts;      // +0x30
    uint64_t icache_accesses;         // +0x38
    // ... etc
} profiling_data_t;
```

Then read the HPM CSRs and write values. The function_profiler.sv will automatically detect and log them if present.

### Profiling Individual MULHU

The current implementation profiles the entire `levenshtein_distance` function, which includes one MULHU instruction in the profiling calculation code.

To profile ONLY the MULHU instruction (like [mulhu_single_instr.S](../mulhu_hw_profile/mulhu_single_instr.S)), you would need to:

1. Isolate the division calculation
2. Wrap it with CSR reads:
```c
uint64_t mulhu_start = read_mcycle();
result = total_cycles / call_count;  // Contains MULHU
uint64_t mulhu_end = read_mcycle();
```

However, this adds measurement overhead and may affect the MULHU timing.

## Related Files

- Original: `/home/ruijieg/beebs/src/levenshtein/liblevenshtein.c`
- CVA6 startup: [../common/crt.S](../common/crt.S)
- Linker script: [../Zcmp/link.ld](../Zcmp/link.ld)
- MULHU expander: [../../../core/mulhu_expander.sv](../../../core/mulhu_expander.sv)
- Function profiler: [../../../corev_apu/tb/function_profiler.sv](../../../corev_apu/tb/function_profiler.sv)
- Perf logger: [../../../corev_apu/tb/perf_counter_logger.sv](../../../corev_apu/tb/perf_counter_logger.sv)

## License

Based on BEEBS (Bristol/Embecosm Embedded Benchmark Suite)
- Original: GPL-3.0 (Copyright 2011 Miguel Serrano, 2014 Embecosm Limited)
- CVA6 additions: Compatible with CVA6 project license
