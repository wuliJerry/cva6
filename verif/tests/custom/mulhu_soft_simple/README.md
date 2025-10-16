# Simple Software MULHU Test - Debug Version

## Purpose

This is a **minimal debug test** for the software MULHU implementation. It contains only **3 function calls** to help identify issues with the `mulhu_soft_sweep` benchmarks.

If the larger benchmarks fail, this test will help isolate whether the problem is:
1. The software MULHU function itself
2. The loop structure
3. The performance counter interaction
4. Memory/stack issues

## What This Test Does

Calls the `__mulhu64_soft` function 3 times with known inputs:

1. **Test 1**: `MULHU(7, 9)` → Expected result: `0`
2. **Test 2**: `MULHU(0x123456789ABCDEF0, 2)` → Expected result: `0`
3. **Test 3**: `MULHU(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF)` → Expected result: `0xFFFFFFFFFFFFFFFE`

Results are saved in `s0`, `s1`, `s2` registers.

## Building

```bash
cd /home/ruijieg/cva6/verif/tests/custom/mulhu_soft_simple
make all
```

## Running

### Standard Run (no traces):
```bash
make -C /home/ruijieg/cva6/verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_simple/mulhu_soft_simple.elf \
  issrun_opts="+instr_trace_disable"
```

### With Instruction Traces (for debugging):
```bash
make -C /home/ruijieg/cva6/verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_simple/mulhu_soft_simple.elf
```

### With Performance Counters:
```bash
make -C /home/ruijieg/cva6/verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mulhu_soft_simple/mulhu_soft_simple.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mulhu_soft_simple.log"
```

## Expected Results

After simulation completes, check these register values:

| Register | Expected Value | Hex Value | Test Case |
|----------|----------------|-----------|-----------|
| **s0** (x8) | 0 | 0x0000000000000000 | MULHU(7, 9) |
| **s1** (x9) | 0 | 0x0000000000000000 | MULHU(0x123...DEF0, 2) |
| **s2** (x18) | 18446744073709551614 | 0xFFFFFFFFFFFFFFFE | MULHU(max, max) |

## Debugging the Original mulhu_soft_sweep Issues

### If this simple test PASSES:

The software MULHU function works correctly. The issue in `mulhu_soft_sweep` is likely:
- Loop counter initialization problem
- Stack pointer corruption
- Performance counter interference
- Timeout issue (check if simulation completes)

### If this simple test FAILS:

The software MULHU function has a bug. Check:
1. **Instruction trace** - Look for illegal instructions or exceptions
2. **Register values** - Check if intermediate calculations are correct
3. **Memory access** - Verify the function doesn't access invalid memory

### Common Failure Modes:

1. **Simulation hangs**:
   - Check if timeout is too short
   - Look for infinite loops
   - Verify `tohost` write happens

2. **Wrong results**:
   - Compare with hardware MULHU instruction
   - Check intermediate values in `__mulhu64_soft`
   - Verify MUL instruction works (try `mul_simple` first)

3. **Exception/trap**:
   - Check instruction trace for trap causes
   - Verify stack pointer is valid
   - Check for misaligned accesses

## Verification Commands

### View expected results:
```bash
make check
```

### Compare with hardware MULHU:
Create a version that uses hardware `mulhu` instruction instead:
```assembly
mulhu s0, a0, a1  # Hardware version
```

Then compare results between software and hardware implementations.

### Check instruction count:
```bash
grep -c "jalr\|ret\|mul" mulhu_soft_simple.dump
```

Expected: ~75 instructions total (3 calls × ~20 instructions + overhead)

## Files Generated

- `mulhu_soft_simple.elf` - Executable
- `mulhu_soft_simple.dump` - Disassembly
- `trace_hart_0.log` - Instruction trace (if enabled)
- `perf_mulhu_soft_simple.log` - Performance counters (if enabled)

## Next Steps

1. **Run this test first** before investigating `mulhu_soft_sweep`
2. If it passes, the function is correct
3. If it fails, fix the function before running larger benchmarks
4. Use instruction traces to see exactly where failure occurs

## Code Structure

```
Total: ~60 instructions
├── _start: 3 test cases with function calls (~20 instructions)
├── __mulhu64_soft: Software MULHU implementation (~20 instructions)
└── Overhead: Loading constants, saving results (~20 instructions)
```

Very simple, very fast, very easy to debug!