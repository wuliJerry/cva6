# Makefile for Levenshtein Profiled Benchmark
# CVA6-compatible version with function profiling

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
CFLAGS += -Wall

# Linker flags
LDFLAGS = -T$(LINK_DIR)/link.ld

# You can override iterations with: make NUM_ITERATIONS=1000
NUM_ITERATIONS ?= 100

# Source files - Simple Assembly Version (based on working mulhu_sweep)
ASM_SRC = levenshtein_simple.S

# Output
TARGET = levenshtein_simple.elf
DUMP = $(TARGET:.elf=.dump)

# Phony targets
.PHONY: all clean disasm run

# Default target
all: $(TARGET) disasm

# Assemble and link (pure assembly - no crt.S or syscalls needed)
$(TARGET): $(ASM_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) \
		$(ASM_SRC) \
		-o $(TARGET)
	@echo ""
	@echo "==================================================================="
	@echo "Built: $(TARGET)"
	@echo "Configuration: NUM_ITERATIONS=100 (hardcoded in assembly)"
	@echo "Total levenshtein_distance calls: 2500"
	@echo "==================================================================="
	@echo ""

# Generate disassembly
disasm: $(TARGET)
	$(RISCV_OBJDUMP) -d -S $(TARGET) > $(DUMP)
	@echo "Disassembly written to $(DUMP)"

# Run simulation (requires VCS testharness)
run: $(TARGET)
	@echo "Running CVA6 simulation..."
	cd ../../../.. && make vcs-testharness \
		path_var=../.. \
		elf=$(shell pwd)/$(TARGET) \
		target=cv64a6_imafdc_sv39 \
		log=results/levenshtein_profiled.log \
		variant=rv64imac \
		tool_path=$(HOME)/cva6/tools/spike/bin \
		issrun_opts="+instr_trace_disable +perf_log_file=perf_levenshtein.log"

# Clean
clean:
	rm -f *.elf *.dump *.o

# Help
help:
	@echo "Levenshtein Profiled Benchmark Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  all              - Build benchmark (default)"
	@echo "  disasm           - Generate disassembly"
	@echo "  run              - Run CVA6 simulation"
	@echo "  clean            - Remove generated files"
	@echo ""
	@echo "Variables:"
	@echo "  NUM_ITERATIONS   - Number of benchmark runs (default: 100)"
	@echo ""
	@echo "Examples:"
	@echo "  make                        # Build with 100 iterations"
	@echo "  make NUM_ITERATIONS=1000    # Build with 1000 iterations"
	@echo "  make run                    # Build and simulate on CVA6"