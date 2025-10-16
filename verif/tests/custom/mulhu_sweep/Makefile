# Makefile for MULHU Sweep Benchmark

# Configuration
RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC = $(RISCV_PREFIX)gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)objdump

# Target configurations
ARCH = rv64imac_zicsr
ABI = lp64

# Directories
COMMON_DIR = ../common
ENV_DIR = ../env
LINK_DIR = ../Zcmp

# Compiler flags
CFLAGS = -march=$(ARCH) -mabi=$(ABI)
CFLAGS += -static -mcmodel=medany -fvisibility=hidden
CFLAGS += -nostdlib -nostartfiles
CFLAGS += -I$(COMMON_DIR) -I$(ENV_DIR)
CFLAGS += -O2

# Linker flags
LDFLAGS = -T$(LINK_DIR)/link.ld

# Define MULHU_INTERVAL for different sweep points
# You can override this with: make MULHU_INTERVAL=1000
MULHU_INTERVAL ?= 10000

# Source files
ASM_SRC = mulhu_sweep.S
# Note: Our benchmark is self-contained and doesn't need crt.S/syscalls.c
SUPPORT_SRC =

# Output
TARGET = mulhu_sweep_n$(MULHU_INTERVAL).elf
DUMP = $(TARGET:.elf=.dump)

# Phony targets
.PHONY: all clean disasm

# Default target
all: $(TARGET) disasm

# Compile and link
$(TARGET): $(ASM_SRC) $(SUPPORT_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) \
		-DMULHU_INTERVAL=$(MULHU_INTERVAL) \
		$(ASM_SRC) $(SUPPORT_SRC) \
		-o $(TARGET) -lgcc
	@echo ""
	@echo "==================================================================="
	@echo "Built: $(TARGET)"
	@echo "Configuration: MULHU_INTERVAL=$(MULHU_INTERVAL)"
	@echo "  -> MULHU frequency: ~$(shell echo "scale=4; 100.0 / $(MULHU_INTERVAL)" | bc)%"
	@echo "==================================================================="
	@echo ""

# Generate disassembly
disasm: $(TARGET)
	$(RISCV_OBJDUMP) -d $(TARGET) > $(DUMP)
	@echo "Disassembly written to $(DUMP)"

# Build all sweep points
sweep-all: clean
	@echo "Building all sweep configurations..."
	$(MAKE) MULHU_INTERVAL=10000 all
	$(MAKE) MULHU_INTERVAL=1000 all
	$(MAKE) MULHU_INTERVAL=100 all
	$(MAKE) MULHU_INTERVAL=10 all
	@echo ""
	@echo "All configurations built!"
	@ls -lh mulhu_sweep_n*.elf

# Clean
clean:
	rm -f *.elf *.dump *.o

# Help
help:
	@echo "MULHU Sweep Benchmark Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build benchmark with current MULHU_INTERVAL"
	@echo "  sweep-all        - Build all sweep configurations (N=10k,1k,100,10)"
	@echo "  disasm           - Generate disassembly"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "Variables:"
	@echo "  MULHU_INTERVAL   - Number of MULs between each MULHU (default: 10000)"
	@echo ""
	@echo "Examples:"
	@echo "  make                           # Build with N=10000 (0.01% MULHU)"
	@echo "  make MULHU_INTERVAL=1000       # Build with N=1000 (0.1% MULHU)"
	@echo "  make MULHU_INTERVAL=100        # Build with N=100 (1% MULHU)"
	@echo "  make MULHU_INTERVAL=10         # Build with N=10 (10% MULHU)"