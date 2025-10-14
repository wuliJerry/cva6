# CVA6 VCS Simulation Workflow

## Separate Build and Run

### Build Simulator Once
```bash
make vcs_uvm_comp target=cv64a6_imac_sv39
```
Creates simulator binary at: `vcs_results/default/vcs.d/simv`

### Run with Different ELF Files

**Option 1: Using Makefile**
```bash
make vcs_uvm_run target=cv64a6_imac_sv39 elf=/path/to/elf1 log=sim1.log
make vcs_uvm_run target=cv64a6_imac_sv39 elf=/path/to/elf2 log=sim2.log
```

**Option 2: Direct Invocation**
```bash
cd vcs_results/default/vcs.d

./simv \
  ++/path/to/your.elf \
  +elf_file=/path/to/your.elf \
  +core_name=cv64a6_imac_sv39 \
  +tohost_addr=$(${RISCV}/bin/riscv64-unknown-elf-nm -B /path/to/your.elf | grep -w tohost | cut -d' ' -f1) \
  +signature=/path/to/your.elf.signature_output \
  +UVM_TESTNAME=uvmt_cva6_firmware_test_c \
  -sv_lib ${SPIKE_INSTALL_DIR}/lib/libcustomext \
  -sv_lib ${SPIKE_INSTALL_DIR}/lib/libyaml-cpp \
  -sv_lib ${SPIKE_INSTALL_DIR}/lib/libriscv \
  -sv_lib ${SPIKE_INSTALL_DIR}/lib/libfesvr \
  -sv_lib ${SPIKE_INSTALL_DIR}/lib/libdisasm
```

## Quick Example
```bash
# Build once
make vcs_uvm_comp target=cv64a6_imac_sv39

# Run multiple benchmarks
make vcs_uvm_run target=cv64a6_imac_sv39 elf=/home/ruijieg/beebs/src/miniz/miniz log=miniz.log
make vcs_uvm_run target=cv64a6_imac_sv39 elf=/home/ruijieg/beebs/src/sha/sha log=sha.log
```

**Time Savings:** Compilation only happens once, subsequent runs are much faster!

## Clean Up

### Clean VCS Files
```bash
make vcs_clean_all
```
Removes:
- `vcs_results/` directory (compiled simulator and cache)
- Waveform files (*.vpd, *.fsdb)
- VCS metadata (verdiLog/, simv*, *.daidir, csrc, etc.)

### Clean All Simulation Outputs
```bash
make clean_all
```
Removes VCS files plus:
- Trace logs (trace*.log, trace*.dasm)
- All waveforms (*.vpd, *.fsdb, *.vcd, *.fst)
- Text files (*.txt, *.trace)