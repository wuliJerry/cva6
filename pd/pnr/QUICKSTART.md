# Quick Start Guide: CVA6 Place and Route

## 1-Minute Setup

### Extract Libraries (One-time)
```bash
cd /home/ruijieg/asap7/asap7sc7p5t_27/LIB/NLDM
for f in *.7z; do 7z x "$f"; done
```

### Run PnR
```bash
cd /home/ruijieg/cva6/pd/pnr
module load fusioncompiler
make pnr
```

## Expected Runtime
- **Floorplan**: ~1-2 minutes
- **Placement**: ~5-10 minutes
- **CTS**: ~3-5 minutes
- **Routing**: ~10-20 minutes
- **Total**: ~20-40 minutes (depends on design size)

## Key Commands

### Test Setup
```bash
make test
```

### Run Full Flow
```bash
make pnr TARGET=cv64a6_imac_sv39
```

### Clean Outputs
```bash
make clean
```

### Interactive Mode
```bash
module load fusioncompiler
fc_shell
fc_shell> source fc_pnr_flow.tcl
```

## Check Results

### View Summary
```bash
cat output_cv64a6_imac_sv39/reports/qor_final.rpt
```

### Check Timing
```bash
cat output_cv64a6_imac_sv39/reports/timing_final.rpt
```

### View Layout (requires viewer)
```bash
# Use Synopsys IC WorkBench or similar tool
icc2_shell -gui
```

## Common Issues

| Issue | Solution |
|-------|----------|
| "lib files not found" | Extract .7z files first |
| "netlist not found" | Run synthesis first |
| Timing violations | Increase clock period in SDC |
| DRC violations | Reduce core utilization |

## Next Steps

After successful PnR:
1. Review timing reports
2. Verify power consumption
3. Check area utilization
4. Run signoff verification (LVS, DRC)
5. Generate final GDSII for tapeout

## File Locations

```
Input:  ../synth/cva6_cv64a6_imac_sv39_synth.v
Output: output_cv64a6_imac_sv39/cva6_final.gds
```