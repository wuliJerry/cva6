# Makefile for Simple Software MULHU Test

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

ASM_SRC = mulhu_soft_simple.S
ASM_SRC_1K = mulhu_soft_simple_1k.S
TARGET = mulhu_soft_simple.elf
TARGET_1K = mulhu_soft_simple_1k.elf
DUMP = mulhu_soft_simple.dump
DUMP_1K = mulhu_soft_simple_1k.dump

.PHONY: all clean disasm check 1k

all: $(TARGET) $(TARGET_1K) disasm

$(TARGET): $(ASM_SRC)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $(ASM_SRC) -o $(TARGET) -lgcc
	@echo ""
	@echo "Built: $(TARGET)"
	@echo ""

$(TARGET_1K): $(ASM_SRC_1K)
	$(RISCV_GCC) $(CFLAGS) $(LDFLAGS) $(ASM_SRC_1K) -o $(TARGET_1K) -lgcc
	@echo ""
	@echo "Built: $(TARGET_1K)"
	@echo ""

1k: $(TARGET_1K)
	$(RISCV_OBJDUMP) -d $(TARGET_1K) > $(DUMP_1K)
	@echo "Disassembly written to $(DUMP_1K)"

disasm: $(TARGET) $(TARGET_1K)
	$(RISCV_OBJDUMP) -d $(TARGET) > $(DUMP)
	@echo "Disassembly written to $(DUMP)"
	$(RISCV_OBJDUMP) -d $(TARGET_1K) > $(DUMP_1K)
	@echo "Disassembly written to $(DUMP_1K)"

# Show expected results for verification
check:
	@echo "Expected Test Results for Software MULHU:"
	@echo ""
	@echo "Test 1: MULHU(7, 9)"
	@echo "  Input:  a0 = 7 (0x0000000000000007)"
	@echo "  Input:  a1 = 9 (0x0000000000000009)"
	@echo "  Output: s0 = 0 (0x0000000000000000) - product fits in lower 64 bits"
	@echo ""
	@echo "Test 2: MULHU(0x123456789ABCDEF0, 2)"
	@echo "  Input:  a0 = 0x123456789ABCDEF0"
	@echo "  Input:  a1 = 2"
	@echo "  Output: s1 = 0 (0x0000000000000000) - no overflow to upper bits"
	@echo ""
	@echo "Test 3: MULHU(0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF)"
	@echo "  Input:  a0 = 0xFFFFFFFFFFFFFFFF (max uint64)"
	@echo "  Input:  a1 = 0xFFFFFFFFFFFFFFFF (max uint64)"
	@echo "  Output: s2 = 0xFFFFFFFFFFFFFFFE (upper 64 bits of max*max)"
	@echo ""
	@echo "Hardware comparison:"
	@echo "  You can verify these results match hardware MULHU instruction"
	@echo ""
	@echo "To verify in simulation:"
	@echo "  Check s0, s1, s2 register values before 'sd t1, 0(t0)'"

clean:
	rm -f *.elf *.dump *.o