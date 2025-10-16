# Makefile for MULHU Software Implementation Sweep Benchmark
# Compares software MULHU implementation vs hardware instruction

# Configuration
RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC = $(RISCV_PREFIX)gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)objdump

# Target configurations
ARCH = rv64imac_zicsr
ABI = lp64

# Directories
LINK_DIR = ../Zcmp

# Compiler flags
CFLAGS = -march=$(ARCH) -mabi=$(ABI)
CFLAGS += -static -mcmodel=medany -fvisibility=hidden
CFLAGS += -nostdlib -nostartfiles
CFLAGS += -O2

# Linker flags
LDFLAGS = -T$(LINK_DIR)/link.ld

# Source files
ASM_SRC = mulhu_soft_sweep.S

# Phony targets
.PHONY: all clean sweep-all help

# Default target builds all variants
all: sweep-all

# Build all sweep points
sweep-all:
	@echo "Building all software MULHU sweep configurations..."
	$(MAKE) build-variant MULHU_INTERVAL=10000
	$(MAKE) build-variant MULHU_INTERVAL=1000
	$(MAKE) build-variant MULHU_INTERVAL=100
	$(MAKE) build-variant MULHU_INTERVAL=10
	@echo ""
	@echo "All configurations built!"
	@ls -lh mulhu_soft_sweep_n*.elf

# Build a single variant
build-variant:
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) \
		-DMULHU_INTERVAL=$(MULHU_INTERVAL) \
		$(ASM_SRC) \
		-o mulhu_soft_sweep_n$(MULHU_INTERVAL).elf -lgcc
	$(RISCV_OBJDUMP) -d mulhu_soft_sweep_n$(MULHU_INTERVAL).elf > mulhu_soft_sweep_n$(MULHU_INTERVAL).dump
	@echo "Built: mulhu_soft_sweep_n$(MULHU_INTERVAL).elf (Software MULHU, ~$(shell echo "scale=4; 100.0 / $(MULHU_INTERVAL)" | bc)% frequency)"

clean:
	rm -f *.elf *.dump *.o

help:
	@echo "MULHU Software Implementation Sweep Benchmark Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build all sweep configurations (N=10k,1k,100,10)"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "This benchmark uses a software implementation of MULHU to compare"
	@echo "performance against the hardware MULHU instruction."