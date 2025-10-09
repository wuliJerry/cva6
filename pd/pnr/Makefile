# Makefile for Fusion Compiler Place and Route Flow
# CVA6 with ASAP7 PDK

DESIGN_NAME  ?= cva6
TARGET       ?= cv64a6_imac_sv39
FC_SHELL     ?= fc_shell

# Directories
OUTPUT_DIR   = output_$(TARGET)
REPORT_DIR   = $(OUTPUT_DIR)/reports

.PHONY: all test clean help pnr

all: help

help:
	@echo "==========================================="
	@echo "CVA6 Fusion Compiler PnR Makefile"
	@echo "==========================================="
	@echo ""
	@echo "Targets:"
	@echo "  test    - Test Fusion Compiler setup"
	@echo "  pnr     - Run complete Place and Route flow"
	@echo "  clean   - Remove output files"
	@echo "  help    - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  TARGET  - Configuration target (default: $(TARGET))"
	@echo "  DESIGN  - Design name (default: $(DESIGN_NAME))"
	@echo ""
	@echo "Prerequisites:"
	@echo "  1. Run synthesis first (make -C ../synth)"
	@echo "  2. Extract ASAP7 .lib files from .7z"
	@echo "  3. Load fusioncompiler module"
	@echo ""

test:
	@echo "Testing Fusion Compiler setup..."
	@module load fusioncompiler && $(FC_SHELL) -f test_fc_commands.tcl

pnr:
	@echo "Starting Place and Route flow..."
	@echo "Design: $(DESIGN_NAME)"
	@echo "Target: $(TARGET)"
	@mkdir -p $(REPORT_DIR)
	@module load fusioncompiler && $(FC_SHELL) -f fc_pnr_flow.tcl | tee $(OUTPUT_DIR)/pnr_flow.log
	@echo ""
	@echo "PnR flow complete! Check outputs in $(OUTPUT_DIR)/"

clean:
	@echo "Cleaning output files..."
	@rm -rf output_* *.log* command.log

distclean: clean
	@rm -rf *.dlib AN.DB