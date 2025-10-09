################################################################################
# Fusion Compiler Place and Route Flow for CVA6 with ASAP7 - CORRECTED
# Complete RTL-to-GDSII Physical Implementation Flow
#
# IMPORTANT: This uses the CORRECT Fusion Compiler commands:
#   - create_lib (no -technology for LEF-based flow)
#   - read_tech_lef (NOT read_lef)
#   - read_verilog creates the block
################################################################################

# Source setup script
source fc_setup.tcl

puts "Starting Fusion Compiler PnR Flow (CORRECTED)..."

################################################################################
# Step 1: Setup Search Paths and Libraries
################################################################################
puts "\n=== Step 1: Setting Up Library Paths ==="

# Set search paths for library files
set_app_var search_path [concat ${LIB_PATH} ${LEF_PATH} ${TECHLEF_PATH} [get_app_var search_path]]

# Set link library (timing libraries)
set_app_var link_library "* ${TARGET_LIBRARY_FILES}"

puts "Search paths: [get_app_var search_path]"
puts "Link library: [get_app_var link_library]"

################################################################################
# Step 2: Create Design Library
################################################################################
puts "\n=== Step 2: Creating Design Library ==="

# Create library WITHOUT -technology (we use LEFs, not .tf files)
# The warning about "technology file not specified" is EXPECTED and OK
create_lib ${OUTPUT_DIR}/${DESIGN_NAME}.dlib

# Open the library
open_lib ${OUTPUT_DIR}/${DESIGN_NAME}.dlib
puts "Library created and opened: ${DESIGN_NAME}.dlib"

################################################################################
# Step 3: Read Design Netlist (this creates the block)
################################################################################
puts "\n=== Step 3: Reading Design Netlist ==="

# Read Verilog - this creates the block/design
read_verilog ${VERILOG_NETLIST}

# Set current design
current_design ${DESIGN_NAME}
puts "Current design: ${DESIGN_NAME}"

# Link the design
link_block
puts "Design linked"

################################################################################
# Step 4: Read Physical Data (LEF files) - AFTER block exists
################################################################################
puts "\n=== Step 4: Reading Physical Libraries (LEF files) ==="

# Now we can read LEFs (block exists from read_verilog)
# Use read_tech_lef (NOT read_lef)
read_tech_lef ${TECH_LEF}
puts "Technology LEF loaded"

# Read standard cell LEFs
foreach lef_file ${STD_CELL_LEFS} {
    read_tech_lef ${lef_file}
    puts "Loaded LEF: [file tail ${lef_file}]"
}

################################################################################
# Step 5: Read Constraints
################################################################################
puts "\n=== Step 5: Reading Design Constraints ==="

if {[file exists ${SDC_FILE}]} {
    read_sdc ${SDC_FILE}
    puts "Loaded SDC: ${SDC_FILE}"
} else {
    puts "WARNING: SDC file not found. Creating default constraints."
    create_clock -name clk_i -period 1.0 [get_ports -quiet clk_i]
    if {[sizeof_collection [get_ports -quiet clk_i]] > 0} {
        set_input_delay 0.2 -clock clk_i [remove_from_collection [all_inputs] [get_ports clk_i]]
        set_output_delay 0.2 -clock clk_i [all_outputs]
    }
}

# Save initial design
save_block -as ${DESIGN_NAME}_imported

################################################################################
# Step 6: Floorplanning
################################################################################
puts "\n=== Step 6: Floorplanning ==="

# Initialize floorplan
# Core offset: {left bottom right top} in microns (2um for 7nm is reasonable)
initialize_floorplan \
    -core_utilization 0.7 \
    -core_offset {2 2 2 2}

# Report floorplan
report_floorplan -file ${OUTPUT_DIR}/reports/floorplan_init.rpt

################################################################################
# Step 7: Power Planning
################################################################################
puts "\n=== Step 7: Power Planning ==="

# Create standard cell power connections
# Rail width for ASAP7 M1 layer (typically 0.054-0.072um)
create_pg_std_cell_conn_pattern std_cell_rail \
    -layers {M1} \
    -rail_width {0.072}

# Power ring
set_pg_strategy core_ring -core \
    -pattern {{name: ring} {nets: {VDD VSS}} {layers: {M3 M4}} {width: 0.2} {spacing: 0.2}} \
    -extension {{stop: outermost_ring}}

# Power mesh
set_pg_strategy core_mesh -core \
    -pattern {{name: mesh} {nets: {VDD VSS}} {layers: {M3 M4}} {width: 0.2} {spacing: 2.0} {pitch: 5.0}}

# Apply power planning
compile_pg

save_block -as ${DESIGN_NAME}_floorplanned

################################################################################
# Step 8: Placement
################################################################################
puts "\n=== Step 8: Placement ==="

place_opt

# Reports
report_placement -file ${OUTPUT_DIR}/reports/placement.rpt
report_qor -summary -file ${OUTPUT_DIR}/reports/qor_post_placement.rpt
report_timing -nosplit -file ${OUTPUT_DIR}/reports/timing_post_placement.rpt

save_block -as ${DESIGN_NAME}_placed

################################################################################
# Step 9: Clock Tree Synthesis
################################################################################
puts "\n=== Step 9: Clock Tree Synthesis ==="

set_app_options -name cts.common.max_fanout -value 16
set_app_options -name cts.compile.enable_global_route -value true

clock_opt

report_clock_qor -file ${OUTPUT_DIR}/reports/clock_qor.rpt
report_qor -summary -file ${OUTPUT_DIR}/reports/qor_post_cts.rpt
report_timing -nosplit -file ${OUTPUT_DIR}/reports/timing_post_cts.rpt

save_block -as ${DESIGN_NAME}_cts

################################################################################
# Step 10: Routing
################################################################################
puts "\n=== Step 10: Routing ==="

set_app_options -name route.global.timing_driven -value true
set_app_options -name route.track.timing_driven -value true

route_auto

report_qor -summary -file ${OUTPUT_DIR}/reports/qor_post_route.rpt
report_timing -nosplit -max_paths 100 -file ${OUTPUT_DIR}/reports/timing_post_route.rpt

save_block -as ${DESIGN_NAME}_routed

################################################################################
# Step 11: Post-Route Optimization
################################################################################
puts "\n=== Step 11: Post-Route Optimization ==="

route_opt

# Final reports
report_qor -summary -file ${OUTPUT_DIR}/reports/qor_final.rpt
report_timing -nosplit -max_paths 100 -file ${OUTPUT_DIR}/reports/timing_final.rpt
report_power -file ${OUTPUT_DIR}/reports/power_final.rpt
report_area -hierarchy -file ${OUTPUT_DIR}/reports/area_final.rpt

################################################################################
# Step 12: Chip Finishing
################################################################################
puts "\n=== Step 12: Chip Finishing ==="

# Add filler cells
set filler_cells [get_lib_cells -quiet */FILLER*]
if {[sizeof_collection $filler_cells] > 0} {
    create_stdcell_fillers -lib_cells $filler_cells
}

# Check design
check_design -checks all -file ${OUTPUT_DIR}/reports/check_design.rpt

save_block -as ${DESIGN_NAME}_final

################################################################################
# Step 13: Output Generation
################################################################################
puts "\n=== Step 13: Generating Output Files ==="

write_verilog ${OUTPUT_DIR}/${DESIGN_NAME}_final.v
write_sdf ${OUTPUT_DIR}/${DESIGN_NAME}_final.sdf
write_sdc ${OUTPUT_DIR}/${DESIGN_NAME}_final.sdc
write_def ${OUTPUT_DIR}/${DESIGN_NAME}_final.def

# Write GDS
set gds_files [glob -nocomplain ${ASAP7_PATH}/asap7sc7p5t_27/GDS/*.gds]
if {[llength $gds_files] > 0} {
    write_gds -hierarchy -merge_files $gds_files ${OUTPUT_DIR}/${DESIGN_NAME}_final.gds
} else {
    write_gds -hierarchy ${OUTPUT_DIR}/${DESIGN_NAME}_final.gds
}

puts "\n========================================="
puts "Fusion Compiler PnR Flow Complete!"
puts "Output: ${OUTPUT_DIR}/${DESIGN_NAME}_final.gds"
puts "========================================="

# Final summary
report_qor -summary
report_timing -nosplit -max_paths 10

exit