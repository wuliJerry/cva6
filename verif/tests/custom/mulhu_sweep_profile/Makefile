# Makefile for MULHU Software Sweep Benchmarks
# Builds 6 benchmarks with varying MULHU_SOFT/(MUL+MULHU_SOFT) ratios

CC = riscv64-unknown-elf-gcc
CFLAGS = -march=rv64imac_zicsr -mabi=lp64 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -O2
LDFLAGS = -T../Zcmp/link.ld -Wl,--section-start=.data=0x80002000 -Wl,--section-start=.text=0x80010000
LIBS = -lgcc

# All benchmark files
SOURCES = $(wildcard sweep_mulhu_soft_*.S)
ELFS = $(SOURCES:.S=.elf)
DUMPS = $(SOURCES:.S=.dump)

# Default target
all: $(ELFS)
	@echo "All benchmarks built successfully!"
	@echo ""
	@echo "Benchmarks:"
	@echo "  sweep_mulhu_soft_0.01pct.elf  - 0.01% MULHU_SOFT ratio (5 calls, 49,995 MUL)"
	@echo "  sweep_mulhu_soft_0.05pct.elf  - 0.05% MULHU_SOFT ratio (25 calls, 49,975 MUL)"
	@echo "  sweep_mulhu_soft_0.1pct.elf   - 0.1% MULHU_SOFT ratio (50 calls, 49,950 MUL)"
	@echo "  sweep_mulhu_soft_1.0pct.elf    - 1.0% MULHU_SOFT ratio (500 calls, 49,500 MUL)"
	@echo "  sweep_mulhu_soft_5.0pct.elf    - 5.0% MULHU_SOFT ratio (2,500 calls, 47,500 MUL)"
	@echo "  sweep_mulhu_soft_10.0pct.elf   - 10.0% MULHU_SOFT ratio (5,000 calls, 45,000 MUL)"

# Pattern rule for building ELF files
%.elf: %.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ $(LIBS)
	@echo "Built: $@ ($(shell grep 'MULHU_SOFT/(MUL+MULHU_SOFT) ratio:' $< | sed 's/.*ratio: //'))"

# Generate disassembly
%.dump: %.elf
	riscv64-unknown-elf-objdump -d $< > $@

dumps: $(DUMPS)

# Clean build artifacts
clean:
	rm -f *.elf *.dump *.o

# Phony targets
.PHONY: all clean dumps