# Makefile for Simple MUL Test

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

ASM_SRC = mul_simple.S
TARGET = mul_simple.elf
DUMP = mul_simple.dump

.PHONY: all clean disasm check

all: $(TARGET) disasm

$(TARGET): $(ASM_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $(ASM_SRC) -o $(TARGET) -lgcc
	@echo ""
	@echo "Built: $(TARGET)"
	@echo ""

disasm: $(TARGET)
	$(RISCV_OBJDUMP) -d $(TARGET) > $(DUMP)
	@echo "Disassembly written to $(DUMP)"

# Show expected results for verification
check:
	@echo "Expected Test Results:"
	@echo "  x7  = 63          (0x000000000000003F) - 7 * 9"
	@echo "  x10 = 83810205    (0x0000000004FEF32D) - 12345 * 6789"
	@echo "  x13 = -15         (0xFFFFFFFFFFFFFFF1) - (-5) * 3"
	@echo "  x16 = 0x2468ACF13579BDE0           - 0x123456789ABCDEF0 * 2"
	@echo "  x19 = 0           (0x0000000000000000) - 42 * 0"
	@echo "  x22 = 3735928559  (0x00000000DEADBEEF) - 0xDEADBEEF * 1"
	@echo "  x25 = 1600        (0x0000000000000640) - 100 * 16"
	@echo "  x27 = 169         (0x00000000000000A9) - 13 * 13"
	@echo ""
	@echo "To verify in simulation, check register values before 'sd x29, 0(x28)'"

clean:
	rm -f *.elf *.dump *.o