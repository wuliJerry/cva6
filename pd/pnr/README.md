# CVA6 Place and Route Flow with Fusion Compiler

This directory contains scripts for performing Place and Route (PnR) of the CVA6 RISC-V core using Synopsys Fusion Compiler and ASAP7 PDK.

## Directory Structure

```
pd/pnr/
├── Makefile              # Build automation
├── README.md             # This file
├── fc_setup.tcl          # Environment and library setup
├── fc_pnr_flow.tcl       # Main PnR flow script
├── test_fc_commands.tcl  # Test script for verification
└── output_*/             # Output directory (created during run)
```

## Prerequisites

### 1. Synthesis Completion
You must run synthesis first to generate the gate-level netlist:
```bash
cd ../synth
make cva6_synth TARGET=cv64a6_imac_sv39 [other options...]
```

### 2. ASAP7 Library Setup
Extract the compressed library files:
```bash
cd /home/ruijieg/asap7/asap7sc7p5t_27/LIB/NLDM
7z x asap7sc7p5t_AO_RVT_TT_nldm_201020.lib.7z
7z x asap7sc7p5t_INVBUF_RVT_TT_nldm_201020.lib.7z
7z x asap7sc7p5t_OA_RVT_TT_nldm_201020.lib.7z
7z x asap7sc7p5t_SEQ_RVT_TT_nldm_201020.lib.7z
7z x asap7sc7p5t_SIMPLE_RVT_TT_nldm_201020.lib.7z
```

### 3. Load Fusion Compiler
```bash
module load fusioncompiler
```

## Quick Start

### Test the Setup
```bash
make test
```

### Run Complete PnR Flow
```bash
make pnr
```

## Manual Execution

If you prefer to run Fusion Compiler interactively:

```bash
module load fusioncompiler
fc_shell
```

Then in the fc_shell:
```tcl
source fc_pnr_flow.tcl
```

## PnR Flow Steps

The `fc_pnr_flow.tcl` script performs the following steps:

1. **Library Creation** - Create technology library with ASAP7 PDK
2. **Design Read** - Read synthesized netlist
3. **Physical Libraries** - Read LEF files
4. **Constraints** - Read timing constraints (SDC)
5. **Floorplanning** - Initialize floorplan with 70% utilization
6. **Placement** - Standard cell placement with optimization
7. **Clock Tree Synthesis** - Build clock distribution network
8. **Routing** - Global and detailed routing
9. **Post-Route Optimization** - Final timing/power optimization
10. **Finishing** - Add filler cells, check design rules
11. **Output Generation** - Generate GDS, DEF, Verilog, SDF

## Output Files

After successful PnR, you'll find these files in `output_cv64a6_imac_sv39/`:

### Physical Design
- `cva6_final.gds` - Final layout in GDSII format
- `cva6_final.def` - Design Exchange Format
- `cva6_final.v` - Post-route netlist
- `cva6_final.sdf` - Standard Delay Format (for timing simulation)
- `cva6_final.sdc` - Updated timing constraints

### Reports
- `reports/qor_final.rpt` - Quality of Results summary
- `reports/timing_final.rpt` - Timing analysis
- `reports/power_final.rpt` - Power analysis
- `reports/area_final.rpt` - Area breakdown
- `reports/floorplan.rpt` - Floorplan statistics
- `reports/placement.rpt` - Placement statistics
- `reports/clock_qor.rpt` - Clock tree quality
- `reports/check_design.rpt` - Design rule checks

## Configuration

### Design Parameters (fc_setup.tcl)

- **Core Utilization**: 70% (can be adjusted in `initialize_floorplan`)
- **Target Libraries**: RVT (Regular Vt) Typical corner
- **Clock Period**: 1.0ns (1GHz) - defined in SDC or defaults
- **Power Grid**: M1 rails, M3/M4 rings and mesh

### Technology Files Used

- **Tech LEF**: `asap7_tech_4x_201209.lef`
- **Std Cell LEF**: `asap7sc7p5t_27_R_1x_201211.lef`
- **Liberty**: All RVT TT corner libraries (AO, INVBUF, OA, SEQ, SIMPLE)

## Customization

### Adjust Core Utilization
Edit `fc_pnr_flow.tcl`, find the `initialize_floorplan` command:
```tcl
initialize_floorplan \
    -core_utilization 0.7 \    # Change this value (0.5-0.9)
```

### Change Target Clock Frequency
If no SDC file exists, edit the default clock constraint:
```tcl
create_clock -name clk_i -period 1.0 [get_ports clk_i]  # Change period
```

### Use Different Process Corner
Edit `fc_setup.tcl` to use different library corners:
- FF (Fast-Fast): Best case
- TT (Typical-Typical): Nominal
- SS (Slow-Slow): Worst case

Example for SS corner:
```tcl
set TARGET_LIBRARY_FILES [list \
    asap7sc7p5t_AO_RVT_SS_nldm_201020.lib \
    asap7sc7p5t_INVBUF_RVT_SS_nldm_201020.lib \
    ...
]
```

## Troubleshooting

### Error: Library files not found
**Solution**: Extract the .7z files (see Prerequisites #2)

### Error: Netlist not found
**Solution**: Run synthesis first (see Prerequisites #1)

### DRC violations
**Solution**: Check `reports/check_design.rpt` and adjust floorplan or routing options

### Timing violations
**Solution**:
1. Reduce core utilization for better routing
2. Relax clock period
3. Check synthesis constraints match PnR constraints

## Performance Tips

1. **Faster Runtime**: Reduce core utilization (e.g., 0.6)
2. **Better QoR**: Increase core utilization (e.g., 0.8), but expect longer runtime
3. **Parallel Processing**: FC automatically uses multiple threads
4. **Hierarchical Flow**: For very large designs, consider hierarchical P&R

## Additional Resources

- **Fusion Compiler Documentation**: Available via SolvNetPlus
- **ASAP7 PDK**: https://github.com/The-OpenROAD-Project/asap7
- **ASAP7 Synopsys Support**: https://github.com/snishizawa/asap7_snps
- **CVA6 Documentation**: https://docs.openhwgroup.org/projects/cva6-user-manual/

## Support

For issues related to:
- **CVA6 design**: https://github.com/openhwgroup/cva6
- **ASAP7 PDK**: https://github.com/The-OpenROAD-Project/asap7
- **Fusion Compiler**: Synopsys SolvNetPlus (requires license)