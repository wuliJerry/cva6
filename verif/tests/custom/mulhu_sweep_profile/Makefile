# Makefile for MULHU sweep benchmarks
# 10M instructions each, 0.5% multiplication, varying MULHU ratios

RISCV_PREFIX = riscv64-unknown-elf-
CC = $(RISCV_PREFIX)gcc
OBJDUMP = $(RISCV_PREFIX)objdump

ARCH = rv64imac_zicsr
ABI = lp64

LINK_DIR = ../Zcmp
LDFLAGS = -T$(LINK_DIR)/link.ld \
          -Wl,--section-start=.data=0x80002000 \
          -Wl,--section-start=.text=0x80010000

CFLAGS = -march=$(ARCH) -mabi=$(ABI) -static -mcmodel=medany \
         -fvisibility=hidden -nostdlib -nostartfiles -O2

# Benchmark targets
SWEEP_001PCT_ELF = sweep_mulhu_0.01pct.elf
SWEEP_005PCT_ELF = sweep_mulhu_0.05pct.elf
SWEEP_01PCT_ELF = sweep_mulhu_0.1pct.elf
SWEEP_1PCT_ELF = sweep_mulhu_1.0pct.elf
SWEEP_5PCT_ELF = sweep_mulhu_5.0pct.elf
SWEEP_10PCT_ELF = sweep_mulhu_10.0pct.elf

ALL_ELFS = $(SWEEP_001PCT_ELF) $(SWEEP_005PCT_ELF) $(SWEEP_01PCT_ELF) \
           $(SWEEP_1PCT_ELF) $(SWEEP_5PCT_ELF) $(SWEEP_10PCT_ELF)

all: $(ALL_ELFS)
	@echo "All benchmarks built successfully!"
	@echo ""
	@echo "Benchmarks:"
	@echo "  $(SWEEP_001PCT_ELF)  - 0.01% MULHU ratio (5 MULHU, 49,995 MUL)"
	@echo "  $(SWEEP_005PCT_ELF)  - 0.05% MULHU ratio (25 MULHU, 49,975 MUL)"
	@echo "  $(SWEEP_01PCT_ELF)   - 0.1% MULHU ratio (50 MULHU, 49,950 MUL)"
	@echo "  $(SWEEP_1PCT_ELF)    - 1.0% MULHU ratio (500 MULHU, 49,500 MUL)"
	@echo "  $(SWEEP_5PCT_ELF)    - 5.0% MULHU ratio (2,500 MULHU, 47,500 MUL)"
	@echo "  $(SWEEP_10PCT_ELF)   - 10.0% MULHU ratio (5,000 MULHU, 45,000 MUL)"

# Build rules
$(SWEEP_001PCT_ELF): sweep_mulhu_soft_0.01pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (0.01% MULHU ratio)"

$(SWEEP_005PCT_ELF): sweep_mulhu_soft_0.05pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (0.05% MULHU ratio)"

$(SWEEP_01PCT_ELF): sweep_mulhu_soft_0.1pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (0.1% MULHU ratio)"

$(SWEEP_1PCT_ELF): sweep_mulhu_soft_1.0pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (1.0% MULHU ratio)"

$(SWEEP_5PCT_ELF): sweep_mulhu_soft_5.0pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (5.0% MULHU ratio)"

$(SWEEP_10PCT_ELF): sweep_mulhu_soft_10.0pct.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo "Built: $@ (10.0% MULHU ratio)"

# Utility targets
clean:
	rm -f *.elf *.dump *.o

.PHONY: all clean

# VCS simulation commands
help:
	@echo "MULHU Sweep Benchmark Suite"
	@echo "==========================="
	@echo ""
	@echo "Build targets:"
	@echo "  make all    - Build all 6 benchmarks"
	@echo "  make clean  - Remove all built files"
	@echo ""
	@echo "VCS Simulation:"
	@echo "  cd ../../sim"
	@echo "  make vcs-testharness \\"
	@echo "    path_var=../.. \\"
	@echo "    elf=<path_to_elf> \\"
	@echo "    target=cv64a6_imafdc_sv39 \\"
	@echo "    log=results/sweep_<name>.log \\"
	@echo "    variant=rv64imac \\"
	@echo "    tool_path=\$$HOME/cva6/tools/spike/bin \\"
	@echo "    issrun_opts=\"+instr_trace_disable +perf_log_file=perf_<name>.log +time_out=100000000000\""
	@echo ""
	@echo "Note: 10M instructions will take significant time in RTL simulation"
	@echo "      Estimated: ~30-60 minutes per benchmark"

.DEFAULT_GOAL := help