# VCS Testharness Makefile Arguments Reference

This document describes all arguments for the `vcs-testharness` target in the CVA6 verification Makefile.

## Quick Start Example

```bash
make vcs-testharness \
  path_var=../.. \
  elf=/path/to/program.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=/home/user/cva6/tools/spike/bin \
  log=results/simulation.log
```

---

## Required Arguments

### `path_var`
**Description:** Path to the CVA6 root directory containing the main Makefile with `vcs_build` target.

**Type:** Directory path

**Example:**
```bash
path_var=../..              # From verif/sim directory
path_var=/home/user/cva6    # Absolute path
```

**Notes:**
- This is where the `vcs_build` target will be invoked
- Must point to CVA6 repository root, not a test directory
- The build will create a `work-vcs/` directory at this location

---

### `elf`
**Description:** Path to the ELF binary to execute in the simulation.

**Type:** File path (absolute or relative)

**Example:**
```bash
elf=/tmp/hello_world.elf
elf=../../tests/custom/my_test/my_test.elf
```

**Notes:**
- The ELF file must be compiled for the RISC-V target architecture
- Must match the `target` architecture (32-bit vs 64-bit)
- The simulator extracts `tohost` address from this ELF for test completion detection

---

### `target`
**Description:** CVA6 hardware configuration to simulate.

**Type:** Configuration name (string)

**Valid Options:**
- `cv64a6_imafdc_sv39` (64-bit, default)
- `cv32a6_imac_sv0` (32-bit, no MMU)
- `cv32a6_imac_sv32` (32-bit, Sv32 MMU)
- `cv32a6_imafc_sv32` (32-bit, with FPU)
- `cv32a60x` (32-bit, OpenHW configuration)

**Example:**
```bash
target=cv64a6_imafdc_sv39
target=cv32a60x
```

**Notes:**
- Determines XLEN (32 or 64 bit)
- Configures available ISA extensions
- Selects appropriate configuration package from `core/include/`

---

### `variant`
**Description:** RISC-V ISA string for the spike-dasm disassembler.

**Type:** ISA string

**Common Values:**
- `rv64imac` - 64-bit, Integer, Multiply, Atomic, Compressed
- `rv64gc` - 64-bit, General purpose (IMAFD + Zicsr + Zifencei)
- `rv32imac` - 32-bit, Integer, Multiply, Atomic, Compressed
- `rv32gc` - 32-bit, General purpose

**Example:**
```bash
variant=rv64imac    # For cv64a6_imafdc_sv39
variant=rv32imac    # For cv32a60x
```

**Notes:**
- Must match the target architecture's XLEN (32/64)
- Used by `spike-dasm` to disassemble instruction trace
- Should match or be a subset of the hardware configuration

---

### `tool_path`
**Description:** Directory containing spike tools (spike-dasm).

**Type:** Directory path

**Example:**
```bash
tool_path=/home/user/cva6/tools/spike/bin
tool_path=$(SPIKE_INSTALL_DIR)/bin
```

**Default Location:** `$(CVA6_REPO_DIR)/tools/spike/bin`

**Notes:**
- Must contain the `spike-dasm` executable
- Used for post-simulation disassembly of instruction traces
- Verify path with: `ls $tool_path/spike-dasm`

---

### `log`
**Description:** Output file path for the disassembled instruction trace.

**Type:** File path

**Example:**
```bash
log=results/hello_world.log
log=/tmp/simulation_output.log
```

**Notes:**
- Directory will NOT be created automatically - ensure it exists first
- Contains human-readable disassembled trace after simulation
- Also used to name waveform files (e.g., `hello_world.vpd`)

---

## Optional Arguments

### `gate`
**Description:** Enable gate-level simulation (post-synthesis).

**Type:** Boolean flag (set to any value to enable)

**Example:**
```bash
gate=1                    # Enable gate-level simulation
# or omit entirely for RTL simulation
```

**Default:** Not set (RTL simulation)

**Effects:**
- Uses `Flist.cva6_gate` instead of `Flist.cva6`
- Sets top-level to `ariane_gate_tb` instead of `ariane_tb`
- Uses `init_gate.do` script instead of `init_testharness.do`
- Requires SDF (Standard Delay Format) file for timing

---

### `VERDI`
**Description:** Launch Verdi GUI for interactive waveform debugging.

**Type:** Boolean flag

**Example:**
```bash
VERDI=1
```

**Default:** Not set (batch mode)

**Notes:**
- Mutually exclusive with `TRACE_FAST` and `TRACE_COMPACT`
- Opens Verdi GUI instead of batch simulation
- Automatically enables debug mode
- Requires VERDI_HOME environment variable

---

### `TRACE_FAST`
**Description:** Generate waveform in VPD (VCD Plus) format.

**Type:** Boolean flag

**Example:**
```bash
TRACE_FAST=1
```

**Default:** Not set

**Output:** Creates `novas.vpd` waveform file

**Notes:**
- Mutually exclusive with `TRACE_COMPACT` and `VERDI`
- VPD format: faster generation, larger file size
- Moved to `$(log_dir)/$(basename).vpd` after simulation
- View with: `verdi -vpd file.vpd` or DVE

---

### `TRACE_COMPACT`
**Description:** Generate waveform in FSDB (Fast Signal Database) format.

**Type:** Boolean flag

**Example:**
```bash
TRACE_COMPACT=1
```

**Default:** Not set

**Output:** Creates `novas.fsdb` waveform file

**Notes:**
- Mutually exclusive with `TRACE_FAST` and `VERDI`
- FSDB format: slower generation, smaller file size, better compression
- Moved to `$(log_dir)/$(basename).fsdb` after simulation
- View with: `verdi -ssf file.fsdb`

---

### `isscomp_opts`
**Description:** Additional compilation options (preprocessor defines).

**Type:** String with `+define+` prefixed options

**Example:**
```bash
isscomp_opts="+define+DEBUG+define+VERBOSE"
```

**Default:** Empty

**Notes:**
- Passed to VCS compiler as SystemVerilog defines
- The `+define+` prefix is automatically stripped and re-added
- Common uses: feature flags, debug enables, configuration overrides

---

### `issrun_opts`
**Description:** Additional runtime simulation options.

**Type:** String with plusargs

**Example:**
```bash
issrun_opts="+verbose +max_cycles=100000"
```

**Default:** Empty

**Notes:**
- Passed directly to the `simv` executable
- Can include any valid VCS runtime option
- Use for runtime configuration, not compilation

---

### `isspostrun_opts`
**Description:** Pattern for grep search in instruction trace after simulation.

**Type:** Grep pattern (string or regex)

**Example:**
```bash
isspostrun_opts="0x0000000080000000"    # Search for address (64-bit)
isspostrun_opts="80000000"              # Search for pattern (works for both 32/64-bit)
isspostrun_opts="jal\|jalr"             # Search for jump instructions
isspostrun_opts="-c sw"                 # Count store-word instructions
```

**Default:** Empty (grep is skipped)

**Notes:**
- Used to verify specific code was executed
- For **32-bit targets**: addresses are 8 hex digits (e.g., `0x80000000`)
- For **64-bit targets**: addresses are 16 hex digits (e.g., `0x0000000080000000`)
- If pattern not found, simulation fails with exit code 1
- Common patterns:
  - Specific address: `"80000000"` (omit leading zeros for flexibility)
  - Register writes: `"x10"` or `"x 5"`
  - Instruction types: `"mul"`, `"div"`, `"jalr"`
  - Count matches: `"-c pattern"`
  - Case insensitive: `"-i pattern"`

---

### `spike-tandem` or `SPIKE_TANDEM`
**Description:** Enable Spike ISA simulator in tandem mode for co-simulation.

**Type:** Boolean (set environment variable)

**Example:**
```bash
export SPIKE_TANDEM=1
make vcs-testharness ...
```

**Default:** Not set

**Notes:**
- Runs Spike simulator alongside RTL for instruction-level comparison
- Requires Spike libraries to be built and available
- Used for verification - detects RTL bugs by comparing with golden model
- Adds compile-time define `SPIKE_TANDEM=1`

---

### `UVM_VERBOSITY`
**Description:** Set UVM message verbosity level.

**Type:** UVM verbosity level

**Valid Values:**
- `UVM_NONE`
- `UVM_LOW` (default)
- `UVM_MEDIUM`
- `UVM_HIGH`
- `UVM_FULL`
- `UVM_DEBUG`

**Example:**
```bash
UVM_VERBOSITY=UVM_HIGH
```

**Default:** `UVM_LOW`

---

### `cov`
**Description:** Enable code coverage collection.

**Type:** Boolean (environment variable)

**Example:**
```bash
export cov=1
make vcs-testharness ...
```

**Default:** Not set

**Effects:**
- Enables line, condition, and toggle coverage (`-cm line+cond+tgl`)
- Creates coverage database
- Uses `cov-exclude-list` to exclude certain modules
- Coverage saved as `$(TESTNAME).ucdb`

---

### `DEBUG`
**Description:** Enable debug mode (automatically set by TRACE_* or VERDI).

**Type:** Boolean flag

**Example:**
```bash
DEBUG=1
```

**Default:** Not set (unless TRACE_FAST/TRACE_COMPACT/VERDI is set)

**Effects:**
- Enables full debug access (`-debug_access+all`)
- Preserves more design hierarchy
- Allows runtime waveform dumping

---

## Environment Variables

These are typically set in your shell environment or setup script:

### `CVA6_REPO_DIR`
**Description:** Path to CVA6 repository root

**Default:** Auto-detected from Makefile location

### `RISCV`
**Description:** RISC-V toolchain installation directory

**Required:** Yes (for extracting tohost address)

### `SPIKE_INSTALL_DIR`
**Description:** Spike ISA simulator installation directory

**Default:** `$(CVA6_REPO_DIR)/tools/spike`

### `VCS_HOME`
**Description:** Synopsys VCS installation directory

**Required:** Yes (set by VCS module)

---

## Complete Example with All Common Options

```bash
# Create output directory
mkdir -p results

# Run simulation with waveforms and post-processing
make vcs-testharness \
  path_var=../.. \
  elf=/tmp/hello_world.elf \
  target=cv64a6_imafdc_sv39 \
  variant=rv64imac \
  tool_path=/home/user/cva6/tools/spike/bin \
  log=results/hello_world.log \
  TRACE_COMPACT=1 \
  isspostrun_opts="80000000" \
  UVM_VERBOSITY=UVM_MEDIUM
```

---

## Common Issues and Solutions

### Issue: "grep: no match found"
**Cause:** The `isspostrun_opts` pattern doesn't exist in trace file.

**Solution:**
- For 64-bit targets, use 16-digit addresses: `0x0000000080000000`
- Or use shorter pattern without leading zeros: `"80000000"`
- Omit `isspostrun_opts` if you don't need pattern matching

### Issue: "spike-dasm: command not found"
**Cause:** `tool_path` is incorrect or spike-dasm not installed.

**Solution:**
```bash
# Check if spike-dasm exists
ls /home/user/cva6/tools/spike/bin/spike-dasm

# Set correct path
tool_path=/home/user/cva6/tools/spike/bin
```

### Issue: "No such file or directory" for log file
**Cause:** Output directory doesn't exist.

**Solution:**
```bash
mkdir -p results  # Create directory first
log=results/test.log
```

### Issue: ELF/target mismatch
**Cause:** 32-bit ELF with 64-bit target or vice versa.

**Solution:** Ensure ELF matches target:
- `cv64a6_*` targets need RV64 ELF (`riscv64-*` toolchain)
- `cv32a6_*` targets need RV32 ELF (`riscv32-*` toolchain)

---

## See Also

- [VCS_WORKFLOW.md](VCS_WORKFLOW.md) - General VCS simulation workflow
- [VERILATOR_WORKFLOW.md](VERILATOR_WORKFLOW.md) - Verilator simulation
- `make help` - Show available targets
- Main Makefile: `verif/sim/Makefile`
