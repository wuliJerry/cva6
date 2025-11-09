# Makefile for MULHU Simple Test
# Quick verification test with 100 MULHU operations

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

# Source files
ASM_SRC = mulhu_simple.S
SUPPORT_SRC =

# Output
TARGET = mulhu_simple.elf
DUMP = $(TARGET:.elf=.dump)

# Phony targets
.PHONY: all clean disasm

# Default target
all: $(TARGET) disasm

# Compile and link
$(TARGET): $(ASM_SRC) $(SUPPORT_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) \
		$(ASM_SRC) $(SUPPORT_SRC) \
		-o $(TARGET) -lgcc
	@echo ""
	@echo "==================================================================="
	@echo "Built: $(TARGET)"
	@echo "Configuration: Simple MULHU test with 100 iterations"
	@echo "==================================================================="
	@echo ""

# Generate disassembly
disasm: $(TARGET)
	$(RISCV_OBJDUMP) -d $(TARGET) > $(DUMP)
	@echo "Disassembly written to $(DUMP)"

# Clean
clean:
	rm -f *.elf *.dump *.o

# Help
help:
	@echo "MULHU Simple Test Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build simple test"
	@echo "  disasm           - Generate disassembly"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make             # Build mulhu_simple.elf"
	@echo "  make clean       # Clean up"
