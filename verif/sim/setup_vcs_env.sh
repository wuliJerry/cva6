#!/bin/bash
# CVA6 VCS Simulation Environment Setup Script

# Set CVA6 paths
export CVA6_REPO_DIR=/home/ruijieg/cva6
export CVA6_TB_DIR=/home/ruijieg/cva6/verif/tb/core
export CORE_V_VERIF=/home/ruijieg/cva6/verif/core-v-verif

# RISC-V toolchain (already set in your environment, but including for completeness)
export RISCV=/home/ruijieg/riscv
export CV_SW_PREFIX=riscv64-unknown-elf-


# Spike ISS paths
export SPIKE_INSTALL_DIR=/home/ruijieg/cva6/tools/spike

# Load VCS (if not already loaded)
module load veridi vcs 2>/dev/null || true

export 

echo "CVA6 VCS environment configured:"
echo "  CVA6_REPO_DIR     = $CVA6_REPO_DIR"
echo "  CVA6_TB_DIR       = $CVA6_TB_DIR"
echo "  CORE_V_VERIF      = $CORE_V_VERIF"
echo "  RISCV             = $RISCV"
echo "  SPIKE_INSTALL_DIR = $SPIKE_INSTALL_DIR"
echo ""
echo "Ready to run simulations!"