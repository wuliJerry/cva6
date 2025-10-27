// Function Profiler Module
// Monitors memory writes to profiling_data region and logs the results
// when program completes.
//
// This module captures function profiling data written to memory and appends
// the results to the performance counter log file.

module function_profiler #(
    parameter PROFILING_ADDR = 64'h80002000  // Base address of profiling_data
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] end_of_test_i,       // Test completion signal
    // Memory interface - connect to RVFI or memory subsystem
    input  logic        mem_valid_i,
    input  logic        mem_we_i,
    input  logic [63:0] mem_addr_i,
    input  logic [63:0] mem_wdata_i
);

    // Profiling data storage - Basic fields
    logic [63:0] call_count;
    logic [63:0] total_cycles;
    logic [63:0] total_program_cycles;
    logic [63:0] avg_cycles_per_call;
    logic [63:0] percentage_of_total;

    // HPM fields (optional - only for HPM-enabled benchmarks)
    logic [63:0] icache_misses;
    logic [63:0] branch_mispredicts;
    logic [63:0] call_count_hpm;
    logic [63:0] icache_accesses;
    logic [63:0] icache_miss_rate;
    logic [63:0] mispredicts_per_call;

    logic profiling_captured;
    logic hpm_enabled;
    logic prof_log_enabled;
    string perf_log_file;
    integer log_file;

    initial begin
        // Get the same log file name as perf_counter_logger
        if (!$value$plusargs("perf_log_file=%s", perf_log_file)) begin
            perf_log_file = "perf_counters_hart_00.log";
        end

        // Check if profiling should be disabled
        if ($test$plusargs("func_profile_disable")) begin
            prof_log_enabled = 1'b0;
            $display("[function_profiler] Function profiling disabled");
        end else begin
            prof_log_enabled = 1'b1;
            $display("[function_profiler] Monitoring memory writes to 0x%h", PROFILING_ADDR);
        end
    end

    // Capture writes to profiling_data region
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            call_count <= 0;
            total_cycles <= 0;
            total_program_cycles <= 0;
            avg_cycles_per_call <= 0;
            percentage_of_total <= 0;
            icache_misses <= 0;
            branch_mispredicts <= 0;
            call_count_hpm <= 0;
            icache_accesses <= 0;
            icache_miss_rate <= 0;
            mispredicts_per_call <= 0;
            profiling_captured <= 1'b0;
            hpm_enabled <= 1'b0;
        end else begin
            if (mem_valid_i && mem_we_i) begin
                case (mem_addr_i)
                    PROFILING_ADDR + 64'h00: begin
                        call_count <= mem_wdata_i;
                        $display("[PROFILER] Captured call_count = %0d", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h08: begin
                        total_cycles <= mem_wdata_i;
                        $display("[PROFILER] Captured total_cycles = %0d", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h10: begin
                        total_program_cycles <= mem_wdata_i;
                        $display("[PROFILER] Captured total_program_cycles = %0d", mem_wdata_i);
                        // Calculate percentage automatically to avoid memory layout issues
                        if (total_program_cycles > 0 && total_cycles > 0) begin
                            percentage_of_total <= (total_cycles * 100) / total_program_cycles;
                        end
                    end
                    PROFILING_ADDR + 64'h18: begin
                        avg_cycles_per_call <= mem_wdata_i;
                        $display("[PROFILER] Captured avg_cycles_per_call = %0d", mem_wdata_i);
                        // If no HPM fields follow, mark as captured here
                        if (!hpm_enabled) begin
                            profiling_captured <= 1'b1;
                        end
                    end
                    PROFILING_ADDR + 64'h20: begin
                        icache_misses <= mem_wdata_i;
                        $display("[PROFILER] Captured icache_misses = %0d", mem_wdata_i);
                        hpm_enabled <= 1'b1;
                    end
                    PROFILING_ADDR + 64'h28: begin
                        branch_mispredicts <= mem_wdata_i;
                        $display("[PROFILER] Captured branch_mispredicts = %0d", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h30: begin
                        call_count_hpm <= mem_wdata_i;
                        $display("[PROFILER] Captured call_count_hpm = %0d", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h38: begin
                        icache_accesses <= mem_wdata_i;
                        $display("[PROFILER] Captured icache_accesses = %0d", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h40: begin
                        icache_miss_rate <= mem_wdata_i;
                        $display("[PROFILER] Captured icache_miss_rate = %0d%%", mem_wdata_i);
                    end
                    PROFILING_ADDR + 64'h48: begin
                        mispredicts_per_call <= mem_wdata_i;
                        $display("[PROFILER] Captured mispredicts_per_call = %0d", mem_wdata_i);
                        profiling_captured <= 1'b1;
                    end
                endcase
            end
        end
    end

    // Log results when test completes
    final begin
        if (prof_log_enabled && profiling_captured && end_of_test_i[0] == 1'b1) begin
            // Append to the same file as perf_counter_logger
            log_file = $fopen(perf_log_file, "a");
            if (log_file != 0) begin
                $fwrite(log_file, "\n");
                $fwrite(log_file, "================================================================================\n");
                $fwrite(log_file, " __mulhu64_soft FUNCTION PROFILING RESULTS\n");
                $fwrite(log_file, "================================================================================\n");
                $fwrite(log_file, "\n");
                $fwrite(log_file, "Call Count:             %0d\n", call_count);
                $fwrite(log_file, "Total Cycles in Func:   %0d\n", total_cycles);
                $fwrite(log_file, "Total Program Cycles:   %0d\n", total_program_cycles);
                $fwrite(log_file, "Avg Cycles per Call:    %0d\n", avg_cycles_per_call);
                $fwrite(log_file, "Percentage of Total:    %0d%%\n", percentage_of_total);

                // If HPM profiling is enabled, log additional metrics
                if (hpm_enabled) begin
                    $fwrite(log_file, "\n");
                    $fwrite(log_file, "--------------------------------------------------------------------------------\n");
                    $fwrite(log_file, " HPM MICROARCHITECTURAL METRICS\n");
                    $fwrite(log_file, "--------------------------------------------------------------------------------\n");
                    $fwrite(log_file, "\n");
                    $fwrite(log_file, "I-cache Misses:         %0d\n", icache_misses);
                    $fwrite(log_file, "I-cache Accesses:       %0d\n", icache_accesses);
                    $fwrite(log_file, "I-cache Miss Rate:      %0d%%\n", icache_miss_rate);
                    $fwrite(log_file, "Branch Mispredicts:     %0d\n", branch_mispredicts);
                    $fwrite(log_file, "Function Calls (HPM):   %0d\n", call_count_hpm);
                    $fwrite(log_file, "Mispredicts per Call:   %0d\n", mispredicts_per_call);
                end

                $fwrite(log_file, "\n");
                $fwrite(log_file, "================================================================================\n");
                $fclose(log_file);

                $display("\n");
                $display("================================================================================");
                $display(" __mulhu64_soft Function Profiling Results");
                $display("================================================================================");
                $display("");
                $display("Call Count:             %0d", call_count);
                $display("Total Cycles in Func:   %0d", total_cycles);
                $display("Total Program Cycles:   %0d", total_program_cycles);
                $display("Avg Cycles per Call:    %0d", avg_cycles_per_call);
                $display("Percentage of Total:    %0d%%", percentage_of_total);

                // If HPM profiling is enabled, display additional metrics
                if (hpm_enabled) begin
                    $display("");
                    $display("--------------------------------------------------------------------------------");
                    $display(" HPM Microarchitectural Metrics");
                    $display("--------------------------------------------------------------------------------");
                    $display("");
                    $display("I-cache Misses:         %0d", icache_misses);
                    $display("I-cache Accesses:       %0d", icache_accesses);
                    $display("I-cache Miss Rate:      %0d%%", icache_miss_rate);
                    $display("Branch Mispredicts:     %0d", branch_mispredicts);
                    $display("Function Calls (HPM):   %0d", call_count_hpm);
                    $display("Mispredicts per Call:   %0d", mispredicts_per_call);
                end

                $display("");
                $display("================================================================================");
                $display("");
            end
        end
    end

endmodule