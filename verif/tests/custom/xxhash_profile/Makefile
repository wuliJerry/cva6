# Makefile for XXHash3 Benchmark with Profiling Infrastructure
# Builds the xxh3_4percent benchmark with profiling support

CC = riscv64-unknown-elf-gcc
CFLAGS = -march=rv64imac_zicsr -mabi=lp64 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -O2
LDFLAGS = -T../Zcmp/link.ld -Wl,--section-start=.data=0x80002000 -Wl,--section-start=.text=0x80010000
LIBS = -lgcc

# All benchmark files
SOURCES = $(wildcard xxh3_*.S)
ELFS = $(SOURCES:.S=.elf)
DUMPS = $(SOURCES:.S=.dump)

# Default target
all: $(ELFS)
	@echo "XXHash benchmark built successfully!"
	@echo ""
	@echo "Benchmark:"
	@echo "  xxh3_4percent_profile.elf  - XXHash3 with 4% MULHU ratio (150,000 MULHU, 3,400,000 MUL)"

# Pattern rule for building ELF files
%.elf: %.S
	$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@ $(LIBS)
	@echo "Built: $@"

# Generate disassembly
%.dump: %.elf
	riscv64-unknown-elf-objdump -d $< > $@

dumps: $(DUMPS)

# Clean build artifacts
clean:
	rm -f *.elf *.dump *.o

# Phony targets
.PHONY: all clean dumps