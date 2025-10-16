# Makefile for Hardware MULHU Profiling Benchmarks

RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC = $(RISCV_PREFIX)gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)objdump
RISCV_NM = $(RISCV_PREFIX)nm

ARCH = rv64imac_zicsr
ABI = lp64

LINK_DIR = ../Zcmp

CFLAGS = -march=$(ARCH) -mabi=$(ABI)
CFLAGS += -static -mcmodel=medany -fvisibility=hidden
CFLAGS += -nostdlib -nostartfiles
CFLAGS += -O2

LDFLAGS = -T$(LINK_DIR)/link.ld

# Source files
SINGLE_SRC = mulhu_single_instr.S
DEPENDENT_SRC = mulhu_dependent_chain.S
PARALLEL_SRC = mulhu_parallel_independent.S
CALIB_SRC = csr_overhead_calibration.S

# Targets
SINGLE_ELF = mulhu_single_instr.elf
DEPENDENT_ELF = mulhu_dependent_chain.elf
PARALLEL_ELF = mulhu_parallel_independent.elf
CALIB_ELF = csr_overhead_calibration.elf

ALL_ELFS = $(SINGLE_ELF) $(DEPENDENT_ELF) $(PARALLEL_ELF) $(CALIB_ELF)

# Dump files
SINGLE_DUMP = mulhu_single_instr.dump
DEPENDENT_DUMP = mulhu_dependent_chain.dump
PARALLEL_DUMP = mulhu_parallel_independent.dump
CALIB_DUMP = csr_overhead_calibration.dump

ALL_DUMPS = $(SINGLE_DUMP) $(DEPENDENT_DUMP) $(PARALLEL_DUMP) $(CALIB_DUMP)

.PHONY: all clean single dependent parallel calib disasm check

all: $(ALL_ELFS) disasm
	@echo ""
	@echo "All hardware MULHU profiling benchmarks built successfully!"
	@echo ""
	@ls -lh *.elf

# Individual targets
single: $(SINGLE_ELF) $(SINGLE_DUMP)

dependent: $(DEPENDENT_ELF) $(DEPENDENT_DUMP)

parallel: $(PARALLEL_ELF) $(PARALLEL_DUMP)

calib: $(CALIB_ELF) $(CALIB_DUMP)

# Build rules
$(SINGLE_ELF): $(SINGLE_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (Single-instruction MULHU profiling)"

$(DEPENDENT_ELF): $(DEPENDENT_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (Dependent chain latency test)"

$(PARALLEL_ELF): $(PARALLEL_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (Parallel independent throughput test)"

$(CALIB_ELF): $(CALIB_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (CSR overhead calibration)"

# Disassembly
disasm: $(ALL_DUMPS)

%.dump: %.elf
	$(RISCV_OBJDUMP) -d $< > $@
	@echo "Disassembly written to $@"

# Information
check:
	@echo "Hardware MULHU Profiling Benchmarks:"
	@echo ""
	@echo "1. mulhu_single_instr.elf"
	@echo "   Measures single MULHU instruction latency"
	@echo "   Most direct comparison to software implementation"
	@echo "   Expected result: 1-5 cycles per MULHU"
	@echo ""
	@echo "2. mulhu_dependent_chain.elf"
	@echo "   Measures latency with dependent operations"
	@echo "   Reveals true critical path delay"
	@echo "   Expected result: Shows if pipeline can overlap"
	@echo ""
	@echo "3. mulhu_parallel_independent.elf"
	@echo "   Measures throughput with independent operations"
	@echo "   Reveals instruction-level parallelism"
	@echo "   Expected result: <1 cycle if superscalar, ~latency if scalar"
	@echo ""
	@echo "4. csr_overhead_calibration.elf"
	@echo "   Measures CSR read overhead"
	@echo "   Used to calibrate other measurements"
	@echo "   Expected result: 2-4 cycles per measurement"
	@echo ""
	@echo "To run:"
	@echo "  cd ../../sim"
	@echo "  make vcs-testharness path_var=../.. \\"
	@echo "    elf=/path/to/mulhu_single_instr.elf \\"
	@echo "    issrun_opts=\"+instr_trace_disable +perf_log_file=mulhu_hw_single.log\""

clean:
	rm -f *.elf *.dump *.o

help: check