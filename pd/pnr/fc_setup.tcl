################################################################################
# Fusion Compiler Setup Script for CVA6 with ASAP7 PDK
# This script sets up the design environment and library paths
################################################################################

# Design and Library Setup
set DESIGN_NAME "cva6"
set TARGET "cv64a6_imac_sv39"

# ASAP7 PDK Path
set ASAP7_PATH "/home/ruijieg/asap7"

# Technology Library Files (extracted .lib files)
set LIB_PATH "${ASAP7_PATH}/asap7sc7p5t_27/LIB/NLDM"

# LEF Files
set LEF_PATH "${ASAP7_PATH}/asap7sc7p5t_27/LEF"
set TECHLEF_PATH "${ASAP7_PATH}/asap7sc7p5t_27/techlef_misc"

# Set library names for RVT (Regular Vt) Typical corner
set TARGET_LIBRARY_FILES [list \
    asap7sc7p5t_AO_RVT_TT_nldm_201020.lib \
    asap7sc7p5t_INVBUF_RVT_TT_nldm_201020.lib \
    asap7sc7p5t_OA_RVT_TT_nldm_201020.lib \
    asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib \
    asap7sc7p5t_SIMPLE_RVT_TT_nldm_201020.lib \
]

# Physical LEF files
set TECH_LEF "${TECHLEF_PATH}/asap7_tech_4x_201209.lef"
set STD_CELL_LEFS [list \
    ${LEF_PATH}/asap7sc7p5t_27_R_1x_201211.lef \
]

# Design Data
set SYNTH_NETLIST_DIR "../../pd/synth"
set VERILOG_NETLIST "${SYNTH_NETLIST_DIR}/${DESIGN_NAME}_${TARGET}_synth.v"
set SDC_FILE "${SYNTH_NETLIST_DIR}/${DESIGN_NAME}_${TARGET}.sdc"

# Output directory
set OUTPUT_DIR "./output_${TARGET}"
file mkdir ${OUTPUT_DIR}

puts "========================================="
puts "Fusion Compiler Setup Complete"
puts "Design: ${DESIGN_NAME}"
puts "Target: ${TARGET}"
puts "ASAP7 Path: ${ASAP7_PATH}"
puts "Output: ${OUTPUT_DIR}"
puts "========================================="
