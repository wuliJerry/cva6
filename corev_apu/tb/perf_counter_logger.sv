// Copyright 2025 OpenHW Group
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Description: Performance counter logger module for CVA6
//              Logs mcycle and minstret CSR values to calculate runtime and IPC

module perf_counter_logger #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter type rvfi_csr_t = logic,
  parameter logic [7:0] HART_ID = '0
)(
  input logic        clk_i,
  input logic        rst_ni,
  input rvfi_csr_t   rvfi_csr_i,
  input logic [31:0] end_of_test_i
);

  int perf_file;
  logic [63:0] mcycle, minstret;
  logic [63:0] mcycle_start, minstret_start;
  logic [63:0] mcycle_prev, minstret_prev;
  logic initialized;
  logic log_enabled;
  string perf_log_file;

  initial begin
    // Open performance counter log file
    // Allow custom filename via +perf_log_file=<name>
    if (!$value$plusargs("perf_log_file=%s", perf_log_file)) begin
      perf_log_file = $sformatf("perf_counters_hart_%h.log", HART_ID);
    end
    perf_file = $fopen(perf_log_file, "w");
    log_enabled = 1'b1;

    // Check if performance logging should be disabled
    if ($test$plusargs("perf_log_disable")) begin
      log_enabled = 1'b0;
      $display("[perf_counter_logger] Performance logging disabled");
    end else begin
      $display("[perf_counter_logger] Logging to: %s", perf_log_file);
    end

    if (log_enabled) begin
      $fwrite(perf_file, "================================================================================\n");
      $fwrite(perf_file, " CVA6 Performance Counter Log\n");
      $fwrite(perf_file, " Hart ID: 0x%h\n", HART_ID);
      $fwrite(perf_file, " XLEN: %0d\n", CVA6Cfg.XLEN);
      $fwrite(perf_file, "================================================================================\n");
      $fwrite(perf_file, "\n");
    end
  end

  final begin
    if (log_enabled && initialized) begin
      automatic longint unsigned total_cycles;
      automatic longint unsigned total_instrs;
      automatic real ipc;

      total_cycles = mcycle - mcycle_start;
      total_instrs = minstret - minstret_start;

      // Calculate IPC, avoiding division by zero
      if (total_cycles > 0) begin
        ipc = real'(total_instrs) / real'(total_cycles);
      end else begin
        ipc = 0.0;
      end

      $fwrite(perf_file, "================================================================================\n");
      $fwrite(perf_file, " FINAL PERFORMANCE METRICS\n");
      $fwrite(perf_file, "================================================================================\n");
      $fwrite(perf_file, "Start mcycle:      %0d (0x%h)\n", mcycle_start, mcycle_start);
      $fwrite(perf_file, "End mcycle:        %0d (0x%h)\n", mcycle, mcycle);
      $fwrite(perf_file, "Total cycles:      %0d\n", total_cycles);
      $fwrite(perf_file, "--------------------------------------------------------------------------------\n");
      $fwrite(perf_file, "Start minstret:    %0d (0x%h)\n", minstret_start, minstret_start);
      $fwrite(perf_file, "End minstret:      %0d (0x%h)\n", minstret, minstret);
      $fwrite(perf_file, "Total instrs:      %0d\n", total_instrs);
      $fwrite(perf_file, "--------------------------------------------------------------------------------\n");
      $fwrite(perf_file, "IPC:               %0.6f\n", ipc);
      $fwrite(perf_file, "CPI:               %0.6f\n", (ipc > 0) ? (1.0 / ipc) : 0.0);
      $fwrite(perf_file, "================================================================================\n");

      // Also print to console for convenience
      $display("\n================================================================================");
      $display(" CVA6 Performance Summary (Hart 0x%h)", HART_ID);
      $display("================================================================================");
      $display(" Total Cycles:       %0d", total_cycles);
      $display(" Total Instructions: %0d", total_instrs);
      $display(" IPC:                %0.6f", ipc);
      $display(" CPI:                %0.6f", (ipc > 0) ? (1.0 / ipc) : 0.0);
      $display("================================================================================\n");

      $fclose(perf_file);
    end else if (log_enabled) begin
      $fclose(perf_file);
    end
  end

  // Extract mcycle and minstret based on XLEN
  always_comb begin
    if (CVA6Cfg.XLEN == 32) begin
      // RV32: Combine high and low parts
      mcycle = {rvfi_csr_i.mcycleh.rdata, rvfi_csr_i.mcycle.rdata};
      minstret = {rvfi_csr_i.minstreth.rdata, rvfi_csr_i.minstret.rdata};
    end else begin
      // RV64: Use full 64-bit values
      mcycle = rvfi_csr_i.mcycle.rdata;
      minstret = rvfi_csr_i.minstret.rdata;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      initialized <= 1'b0;
      mcycle_start <= '0;
      minstret_start <= '0;
      mcycle_prev <= '0;
      minstret_prev <= '0;
    end else begin
      if (log_enabled) begin
        // Initialize start values on first cycle after reset
        if (!initialized) begin
          mcycle_start <= mcycle;
          minstret_start <= minstret;
          mcycle_prev <= mcycle;
          minstret_prev <= minstret;
          initialized <= 1'b1;

          $fwrite(perf_file, "Performance counter logging started\n");
          $fwrite(perf_file, "Initial mcycle:   %0d (0x%h)\n", mcycle, mcycle);
          $fwrite(perf_file, "Initial minstret: %0d (0x%h)\n", minstret, minstret);
          $fwrite(perf_file, "\n");
        end else begin
          // Update previous values
          mcycle_prev <= mcycle;
          minstret_prev <= minstret;
        end

        // Debug: log when end_of_test_i changes
        if (end_of_test_i != 0) begin
          $display("[perf_counter_logger] DEBUG: end_of_test_i = 0x%h at cycle %0d", end_of_test_i, mcycle);
        end

        // Log on end of test
        if (end_of_test_i != 0) begin
          automatic longint unsigned total_cycles;
          automatic longint unsigned total_instrs;
          automatic real ipc;

          total_cycles = mcycle - mcycle_start;
          total_instrs = minstret - minstret_start;

          // Calculate IPC, avoiding division by zero
          if (total_cycles > 0) begin
            ipc = real'(total_instrs) / real'(total_cycles);
          end else begin
            ipc = 0.0;
          end

          $fwrite(perf_file, "================================================================================\n");
          $fwrite(perf_file, " FINAL PERFORMANCE METRICS\n");
          $fwrite(perf_file, "================================================================================\n");
          $fwrite(perf_file, "Start mcycle:      %0d (0x%h)\n", mcycle_start, mcycle_start);
          $fwrite(perf_file, "End mcycle:        %0d (0x%h)\n", mcycle, mcycle);
          $fwrite(perf_file, "Total cycles:      %0d\n", total_cycles);
          $fwrite(perf_file, "--------------------------------------------------------------------------------\n");
          $fwrite(perf_file, "Start minstret:    %0d (0x%h)\n", minstret_start, minstret_start);
          $fwrite(perf_file, "End minstret:      %0d (0x%h)\n", minstret, minstret);
          $fwrite(perf_file, "Total instrs:      %0d\n", total_instrs);
          $fwrite(perf_file, "--------------------------------------------------------------------------------\n");
          $fwrite(perf_file, "IPC:               %0.6f\n", ipc);
          $fwrite(perf_file, "CPI:               %0.6f\n", (ipc > 0) ? (1.0 / ipc) : 0.0);
          $fwrite(perf_file, "================================================================================\n");

          // Also print to console for convenience
          $display("\n================================================================================");
          $display(" CVA6 Performance Summary (Hart 0x%h)", HART_ID);
          $display("================================================================================");
          $display(" Total Cycles:      %0d", total_cycles);
          $display(" Total Instructions: %0d", total_instrs);
          $display(" IPC:               %0.6f", ipc);
          $display(" CPI:               %0.6f", (ipc > 0) ? (1.0 / ipc) : 0.0);
          $display("================================================================================\n");
        end
      end
    end
  end

endmodule // perf_counter_logger