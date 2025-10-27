#!/bin/bash
# Run all 16 single-counter HPM tests
# Usage: cd verif/sim && bash ../tests/custom/mulhu_sweep/RUN_ALL_HPM_TESTS.sh

cd /home/ruijieg/cva6/verif/sim

echo "========================================="
echo "Running 16 Single-Counter HPM Tests"
echo "========================================="
echo ""

# N=10 Tests
echo "=== N=10 Tests (10% MULHU frequency) ==="
make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10_hpm_branch_mispredict.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10_branch.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10_hpm_branch.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10_hpm_icache_miss.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10_icache_miss.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10_hpm_icache_miss.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10_hpm_icache_access.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10_icache_access.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10_hpm_icache_access.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10_hpm_pipeline_stall.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10_pipeline_stall.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10_hpm_pipeline_stall.log"

echo ""

# N=100 Tests
echo "=== N=100 Tests (1% MULHU frequency) ==="
make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n100_hpm_branch_mispredict.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n100_branch.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n100_hpm_branch.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n100_hpm_icache_miss.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n100_icache_miss.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n100_hpm_icache_miss.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n100_hpm_icache_access.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n100_icache_access.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n100_hpm_icache_access.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n100_hpm_pipeline_stall.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n100_pipeline_stall.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n100_hpm_pipeline_stall.log"

echo ""

# N=1000 Tests
echo "=== N=1000 Tests (0.1% MULHU frequency) ==="
make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n1000_hpm_branch_mispredict.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n1000_branch.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n1000_hpm_branch.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n1000_hpm_icache_miss.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n1000_icache_miss.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n1000_hpm_icache_miss.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n1000_hpm_icache_access.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n1000_icache_access.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n1000_hpm_icache_access.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n1000_hpm_pipeline_stall.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n1000_pipeline_stall.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n1000_hpm_pipeline_stall.log"

echo ""

# N=10000 Tests
echo "=== N=10000 Tests (0.01% MULHU frequency) ==="
make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10000_hpm_branch_mispredict.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10000_branch.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10000_hpm_branch.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10000_hpm_icache_miss.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10000_icache_miss.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10000_hpm_icache_miss.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10000_hpm_icache_access.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10000_icache_access.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10000_hpm_icache_access.log"

make vcs-testharness path_var=../.. elf=/home/ruijieg/cva6/verif/tests/custom/mulhu_sweep/mulhu_sweep_n10000_hpm_pipeline_stall.elf target=cv64a6_imafdc_sv39 log=results/mulhu_n10000_pipeline_stall.log variant=rv64imac tool_path=/home/ruijieg/cva6/tools/spike/bin issrun_opts="+instr_trace_disable +perf_log_file=perf_n10000_hpm_pipeline_stall.log"

echo ""
echo "========================================="
echo "All 16 tests completed!"
echo "========================================="