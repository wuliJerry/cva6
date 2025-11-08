# XXHash MULHU Benchmark for CVA6

Two benchmarks measuring XXH3 hash functions with different MULHU intensity.

## Benchmarks

### 1. xxh3_mulhu_benchmark.S (40% MULHU - High Intensity)
**Purpose**: Stress-test MULHU performance with cryptography-heavy workload

**Configuration**:
- All benchmarks: 1000 iterations each
- Dynamic execution:
  - Bench 1 (mul128_fold64): 1000 MULHU, 1000 MUL
  - Bench 2 (XXH3 16-byte): 1000 MULHU, 2000 MUL
  - Bench 3 (XXH3 64-byte): 4000 MULHU, 6000 MUL
  - **Total: 6000 MULHU / 15000 total = 40.0% MULHU**

### 2. xxh3_4percent.S (4% MULHU - Realistic Mix)
**Purpose**: Represent typical application with mixed workload

**Configuration**:
- Bench 1: 100 iterations
- Bench 2: 1000 iterations
- Bench 3: 100 iterations
- Bench 4: 3330 iterations (avalanche mixing, MUL-only)

**Dynamic execution**:
  - Bench 1: 100 MULHU, 100 MUL
  - Bench 2: 1000 MULHU, 2000 MUL
  - Bench 3: 400 MULHU, 600 MUL
  - Bench 4: 0 MULHU, 33300 MUL
  - **Total: 1500 MULHU / 37500 total = 4.0% MULHU**

## Building

```bash
make all  # Builds xxh3_mulhu_benchmark.elf (40% MULHU)
```

For 4% variant:
```bash
riscv64-unknown-elf-gcc -march=rv64imac_zicsr -mabi=lp64 \
  -static -mcmodel=medany -nostdlib -nostartfiles \
  -T../Zcmp/link.ld xxh3_4percent.S -o xxh3_4percent.elf -lgcc
```

## Key Features

**XXH3 Algorithm Components**:
1. `XXH3_mul128_fold64`: 64×64→128 multiply with fold (MUL+MULHU+XOR)
2. `XXH3_len_9to16_64b`: Small input hash (1 MULHU per call)
3. `XXH3_64bytes`: Medium input hash (4 MULHU per call)
4. Avalanche mixing: Final diffusion (MUL-only, no MULHU)

**Multiply Instruction Pattern**:
```assembly
mul   a0, s8, s9    # Low 64 bits  of (s8 × s9)
mulhu a1, s8, s9    # High 64 bits of (s8 × s9)
xor   a0, a0, a1    # Fold: low ^ high
```

## Files

- `xxh3_mulhu_benchmark.S` - 40% MULHU variant
- `xxh3_4percent.S` - 4% MULHU variant  
- `xxh3_mulhu_benchmark.c` - C reference (for compiler analysis)
- `Makefile` - Build system

## Analysis

Run `make check` to verify MULHU instruction counts.

Expected results:
- Static count (40% variant): 7 MULHU in binary
- Static count (4% variant): 6 MULHU in binary
- Dynamic counts match iteration calculations above

## Use Cases

**40% variant**: 
- Measure MULHU latency under heavy load
- Stress-test multiplier pipeline
- Profile cryptographic workloads

**4% variant**:
- Realistic application mix
- Test impact of occasional MULHU on overall IPC
- Compare MULHU vs MUL performance in mixed workload

## Performance Expectations

On CVA6 (estimated):
- MUL latency: 1-2 cycles
- MULHU latency: 2-3 cycles

**40% variant** (per call):
- mul128_fold64: ~4-6 cycles
- XXH3 16-byte: ~15-40 cycles
- XXH3 64-byte: ~50-120 cycles

**4% variant** (per call):
- Similar per-call latencies
- Lower aggregate MULHU pressure
- May show better overall IPC due to more MUL-only work

## References

- xxHash: https://github.com/Cyan4973/xxHash
- CVA6: https://github.com/openhwgroup/cva6
