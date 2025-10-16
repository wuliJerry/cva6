# CVA6 Verilator Simulation Workflow

This guide mirrors the VCS workflow and captures the steps required to build and run the cycle-accurate Verilator model for the `cv64a6_imac_sv39` configuration.

## Prerequisites
- `RISCV` environment variable points to a RISC-V GCC toolchain (e.g., `export RISCV=/opt/riscv`).
- Spike is built under `tools/spike` (default used by the makefile).
- `verif/core-v-verif/vendor/riscv/riscv-isa-sim` has been built at least once so that `build/config.h` and `fesvr/elfloader.cc` are available. Run  
  ```bash
  make -C verif/core-v-verif/vendor/riscv/riscv-isa-sim build
  ```
  if those artifacts are missing.

## Build the Verilator Simulator
```bash
cd /home/ruijieg/cva6
make verilate target=cv64a6_imac_sv39 NUM_JOBS=<n>
```

- Generates the binary at `work-ver/Variane_testharness`.
- Adjust `NUM_JOBS` to match local cores.
- Re-run the command whenever RTL or DPI source files change; use `rm -rf work-ver` for a clean rebuild.

### Optional Flags
- `TRACE_FAST=1` adds VCD tracing, `TRACE_COMPACT=1` enables FST tracing.
- `PROFILE=1` builds with `-pg` instrumentation.
- `SPIKE_TANDEM=1` enables Spike tandem co-simulation support.

## Run a Benchmark
Use the make wrapper (keeps defaults aligned with the build):
```bash
make sim-verilator target=cv64a6_imac_sv39 elf_file=/abs/path/to/app.elf
```

Or invoke the binary directly:
```bash
./work-ver/Variane_testharness /abs/path/to/app.elf
```

### Common Runtime Options
`Variane_testharness --help` prints the full list. Frequently used flags include:
- `--max-cycles <N>` or `-m <N>`: terminate after *N* cycles (default: unlimited).
- `--vcd trace.vcd` or `--fst trace.fst`: generate waveforms (requires matching build flag).
- `--rbb-port <PORT>`: open a remote bit-bang port for OpenOCD/GDB.
- `--seed <N>`: set the random seed passed to internal components.

Log output reports success/failure and final cycle count; exit code mirrors the design's `tohost` value.

## Building Benchmarks

### Using the DV Helper Script (quick start)
```bash
cd /home/ruijieg/cva6/verif/sim
python3 cva6.py     --target cv64a6_imac_sv39     --c_tests ../tests/custom/hello_world/hello_world.c     --co     --gcc_opts "-O2 -static -nostdlib -nostartfiles -lgcc"     --linker ../../config/gen_from_riscv_config/linker/link.ld
```

- The ELF is written under `verif/sim/out_*/directed_tests/`.
- Add `--gcc_opts` or `--isa` overrides for custom ISA extensions or optimisation levels.

### Manual GCC Invocation
For bespoke build systems, replicate the DV settings:
```bash
$RISCV/bin/riscv64-unknown-elf-gcc     -march=rv64imac -mabi=lp64 -mcmodel=medany     -O2 -static -nostdlib -nostartfiles -lgcc -mno-relax     -Iverif/tests/custom/debug_test/bsp     verif/tests/custom/debug_test/bsp/crt0.S     verif/tests/custom/debug_test/bsp/handlers.S     verif/tests/custom/debug_test/bsp/vectors.S     verif/tests/custom/debug_test/bsp/syscalls.c     your_app.c     -T config/gen_from_riscv_config/linker/link.ld     -o your_app.elf
```

- Replace `your_app.c` with the benchmark sources (C or assembly).
- For C++ sources add `-lstdc++` (and the corresponding runtime support) as required.

## Troubleshooting
- **`Invalid Option: --no-timing`** – Upgrade Verilator to ≥ 4.x or remove the flag temporarily.
- **`config.h: No such file or directory`** – Build Spike (`make -C verif/core-v-verif/vendor/riscv/riscv-isa-sim build`) or add the include directory manually.
- **Undefined DPI symbols (`read_elf`, `get_section`, etc.)** – Ensure both `fesvr_dpi.cc` and `elfloader.cc` are included (already handled in the makefile). Clean `work-ver` and rebuild.
- **Runtime `tohost` non-zero** – Inspect console log and generated `trace_*` files; if waveforms were enabled, view them with GTKWave or a compatible viewer.

## Clean Up
```bash
rm -rf work-ver
```
Removes generated Verilator build artifacts (binary, object files, and makefiles).
