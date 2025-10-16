# Simple MUL Functionality Test

## Purpose

This is a minimal test benchmark containing only **8 MUL instructions** with known expected results. It's designed to verify basic multiplier functionality, especially useful for testing a pruned multiplier that only supports MUL (not MULH/MULHU/MULHSU).

## Test Cases

The benchmark tests the following scenarios:

| Test | Operation | Operands | Expected Result | Hex Result | Notes |
|------|-----------|----------|-----------------|------------|-------|
| 1 | `mul x7, x5, x6` | 7 × 9 | 63 | 0x000000000000003F | Small positive numbers |
| 2 | `mul x10, x8, x9` | 12345 × 6789 | 83,810,205 | 0x0000000004FEF32D | Larger numbers |
| 3 | `mul x13, x11, x12` | -5 × 3 | -15 | 0xFFFFFFFFFFFFFFF1 | Negative operand |
| 4 | `mul x16, x14, x15` | 0x123456789ABCDEF0 × 2 | - | 0x2468ACF13579BDE0 | 64-bit value |
| 5 | `mul x19, x17, x18` | 42 × 0 | 0 | 0x0000000000000000 | Multiply by zero |
| 6 | `mul x22, x20, x21` | 0xDEADBEEF × 1 | 3,735,928,559 | 0x00000000DEADBEEF | Identity (×1) |
| 7 | `mul x25, x23, x24` | 100 × 16 | 1,600 | 0x0000000000000640 | Power of 2 |
| 8 | `mul x27, x26, x26` | 13 × 13 | 169 | 0x00000000000000A9 | Same operands |

## Building

```bash
cd /home/ruijieg/cva6/verif/tests/custom/mul_simple
make all
```

This produces:
- `mul_simple.elf` - The executable
- `mul_simple.dump` - Disassembly for inspection

## Running

### VCS Testharness (without traces):
```bash
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mul_simple/mul_simple.elf \
  issrun_opts="+instr_trace_disable"
```

### With performance counters:
```bash
make -C verif/sim vcs-testharness \
  isspostrunelf=/home/ruijieg/cva6/verif/tests/custom/mul_simple/mul_simple.elf \
  issrun_opts="+instr_trace_disable +perf_log_file=perf_mul_simple.log"
```

## Verification

### Automatic Verification (recommended):

Check the simulation log for register values before the final `sd` instruction:

```bash
# The simulation should show these register values:
x7  (t2)  = 0x000000000000003F  (63)
x10 (a0)  = 0x0000000004FEF32D  (83810205)
x13 (a3)  = 0xFFFFFFFFFFFFFFF1  (-15)
x16 (a6)  = 0x2468ACF13579BDE0
x19 (s3)  = 0x0000000000000000  (0)
x22 (s6)  = 0x00000000DEADBEEF  (3735928559)
x25 (s9)  = 0x0000000000000640  (1600)
x27 (s11) = 0x00000000000000A9  (169)
```

### Manual Verification:

Run `make check` to see expected results:

```bash
make check
```

### Using Trace Files:

If you enable instruction tracing (remove `+instr_trace_disable`), you can grep for MUL instructions:

```bash
grep "mul" trace_hart_0.log
```

## Expected Behavior

- **Total instructions**: ~30-40 (mostly loads + 8 MULs + overhead)
- **Execution time**: Very fast (< 100 cycles)
- **All MUL results**: Should match the expected values in the table above
- **No MULH* instructions**: This test uses only MUL

## Use Cases

1. **Sanity check** after modifying the multiplier module
2. **Regression test** for MUL instruction functionality
3. **Comparing pruned vs full multiplier** - results should be identical
4. **Quick functional verification** before running larger benchmarks

## Notes

- This benchmark does NOT test MULH, MULHU, or MULHSU instructions
- The pruned multiplier (MUL-only) should produce identical results to the full multiplier
- All test values are carefully chosen to avoid overflow in the lower 64 bits
- The negative number test (Test 3) verifies sign handling in MUL operation