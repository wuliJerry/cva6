# VCS Testharness Quick Reference Card

## Basic Command Template

```bash
make vcs-testharness \
  path_var=../.. \
  elf=<path/to/file.elf> \
  target=<config> \
  variant=<isa> \
  tool_path=<spike/bin/path> \
  log=<output.log>
```

---

## Required Arguments Quick Reference

| Argument | Description | Example |
|----------|-------------|---------|
| `path_var` | CVA6 root directory | `../..` or `/home/user/cva6` |
| `elf` | ELF binary to simulate | `/tmp/hello_world.elf` |
| `target` | Hardware config | `cv64a6_imafdc_sv39`, `cv32a60x` |
| `variant` | ISA string for disassembler | `rv64imac`, `rv32imac` |
| `tool_path` | Spike tools directory | `/path/to/cva6/tools/spike/bin` |
| `log` | Output log file | `results/test.log` |

---

## Common Target Configurations

| Target | XLEN | ISA | Variant |
|--------|------|-----|---------|
| `cv64a6_imafdc_sv39` | 64 | IMAFDC + Sv39 MMU | `rv64imac` or `rv64gc` |
| `cv32a60x` | 32 | IMAC | `rv32imac` |
| `cv32a6_imac_sv0` | 32 | IMAC, no MMU | `rv32imac` |
| `cv32a6_imac_sv32` | 32 | IMAC + Sv32 MMU | `rv32imac` |
| `cv32a6_imafc_sv32` | 32 | IMAFC + Sv32 MMU | `rv32imac` or `rv32gc` |

---

## Optional Waveform Arguments (Mutually Exclusive)

| Argument | Format | File Size | Use Case |
|----------|--------|-----------|----------|
| `TRACE_FAST=1` | VPD | Large | Quick debugging |
| `TRACE_COMPACT=1` | FSDB | Small | Long simulations |
| `VERDI=1` | Interactive | N/A | GUI debugging |

**Example:**
```bash
make vcs-testharness ... TRACE_COMPACT=1
```

---

## Optional Debug Arguments

| Argument | Purpose | Example |
|----------|---------|---------|
| `isspostrun_opts` | Search pattern in trace | `"80000000"` or `"jal"` |
| `issrun_opts` | Runtime options | `"+verbose"` |
| `isscomp_opts` | Compile defines | `"+define+DEBUG"` |
| `UVM_VERBOSITY` | Message verbosity | `UVM_HIGH` |
| `gate` | Gate-level sim | `gate=1` |
| `DEBUG` | Enable debug mode | `DEBUG=1` |

---

## Address Format Reference

### 32-bit Targets (cv32a6_*)
- Addresses: **8 hex digits**
- Example in trace: `0x80000000`
- Search pattern: `isspostrun_opts="0x80000000"` or `"80000000"`

### 64-bit Targets (cv64a6_*)
- Addresses: **16 hex digits**
- Example in trace: `0x0000000080000000`
- Search pattern: `isspostrun_opts="0x0000000080000000"` or `"80000000"`

**Tip:** Use shorter pattern `"80000000"` to match both formats

---

## Common Recipes

### Basic RTL Simulation
```bash
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/test.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=$HOME/cva6/tools/spike/bin \
  log=results/test.log
```

### With Waveforms (FSDB)
```bash
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/test.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=$HOME/cva6/tools/spike/bin \
  log=results/test.log \
  TRACE_COMPACT=1
```

### Interactive Debug with Verdi
```bash
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/test.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=$HOME/cva6/tools/spike/bin \
  log=results/test.log \
  VERDI=1
```

### Verify Specific Address Executed
```bash
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/test.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=$HOME/cva6/tools/spike/bin \
  log=results/test.log \
  isspostrun_opts="80000000"
```

### 32-bit Simulation
```bash
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/test32.elf \
  target=cv32a60x \
  variant=rv32imac \
  tool_path=$HOME/cva6/tools/spike/bin \
  log=results/test.log
```

---

## Troubleshooting Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| grep: no match found | Remove `isspostrun_opts` or use shorter pattern `"80000000"` |
| spike-dasm: not found | Check `tool_path` points to directory with `spike-dasm` |
| No such file (log) | `mkdir -p results` before running |
| vcs_build: No such target | Check `path_var` points to CVA6 root (has main Makefile) |
| Wrong XLEN | Match ELF to target: RV32 ELF → cv32a6_*, RV64 ELF → cv64a6_* |

---

## Environment Setup

Before running, ensure these are set:

```bash
# Load VCS module
module load vcs

# Set RISC-V toolchain
export RISCV=/path/to/riscv/toolchain

# Spike tools (usually auto-detected)
export SPIKE_INSTALL_DIR=$HOME/cva6/tools/spike
```

---

## Output Files

| File | Location | Description |
|------|----------|-------------|
| Trace | `trace_rvfi_hart_00.dasm` | Raw instruction trace |
| Log | `$(log)` | Disassembled trace |
| UART | `uart` | Serial console output |
| Waveform | `$(log_dir)/$(basename).vpd/fsdb` | Signal waveform |
| Coverage | `simv.vdb/` | Coverage database (if `cov=1`) |

---

## More Information

See [VCS_TESTHARNESS_ARGS.md](VCS_TESTHARNESS_ARGS.md) for detailed documentation.