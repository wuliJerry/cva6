# Makefile for XXH3 MULHU Benchmarks on CVA6

RISCV_PREFIX ?= riscv64-unknown-elf-
RISCV_GCC = $(RISCV_PREFIX)gcc
RISCV_OBJDUMP = $(RISCV_PREFIX)objdump

ARCH = rv64imac_zicsr
ABI = lp64
LINK_DIR = ../Zcmp

ASFLAGS = -march=$(ARCH) -mabi=$(ABI) -static -mcmodel=medany -nostdlib -nostartfiles
LDFLAGS = -T$(LINK_DIR)/link.ld

ASM_SRC = xxh3_mulhu_benchmark.S
TARGET_ELF = xxh3_mulhu_benchmark.elf
TARGET_DUMP = $(TARGET_ELF:.elf=.dump)

.PHONY: all clean disasm check help

all: $(TARGET_ELF) disasm check

$(TARGET_ELF): $(ASM_SRC)
	$(RISCV_GCC) $(ASFLAGS) $(LDFLAGS) $< -o $@ -lgcc
	@echo ""
	@echo "==================================================================="
	@echo "Built: $(TARGET_ELF)"
	@echo "XXH3 MULHU Benchmark for CVA6"
	@echo "==================================================================="

disasm: $(TARGET_DUMP)

$(TARGET_DUMP): $(TARGET_ELF)
	$(RISCV_OBJDUMP) -d -S $< > $@
	@echo "Disassembly: $(TARGET_DUMP)"

check: $(TARGET_DUMP)
	@echo ""
	@echo "==================================================================="
	@echo "Checking for MULHU instructions..."
	@echo "==================================================================="
	@echo -n "MULHU count: "
	@grep -c "mulhu" $(TARGET_DUMP) || echo "0"
	@echo ""
	@echo "MULHU locations:"
	@grep -n "mulhu" $(TARGET_DUMP) || echo "None found"
	@echo ""

clean:
	rm -f *.elf *.dump *.o

help:
	@echo "XXH3 MULHU Benchmark Makefile"
	@echo ""
	@echo "This benchmark measures XXH3 functions that use MULHU instructions:"
	@echo "  - Raw mul128_fold64: Pure MUL+MULHU operation"
	@echo "  - XXH3 16-byte hash: Small input with 1 MULHU"
	@echo "  - XXH3 64-byte hash: Larger input with 4 MULHU"
	@echo ""
	@echo "Targets:"
	@echo "  all     - Build, disassemble, and check (default)"
	@echo "  disasm  - Generate disassembly"
	@echo "  check   - Count MULHU instructions"
	@echo "  clean   - Remove generated files"
	@echo "  help    - Show this message"
