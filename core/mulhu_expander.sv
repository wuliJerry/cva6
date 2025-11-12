// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: CVA6 Team
// Date: 2025
// Description: MULHU instruction expander - breaks MULHU into fused 32-bit micro-ops.
//              Uses custom bespoke operations to eliminate unnecessary shifts/masks.
//
// The expansion implements unsigned 64x64->128 bit multiplication,
// returning the upper 64 bits using 5 fused microops (vs 20 standard RISC-V ops):
//   1. MUL_LL32:   Multiply rs1[31:0] × rs2[31:0], latch upper 32 bits as carry
//   2. MUL_X0_32:  Multiply rs1[63:32] × rs2[31:0] → tX0
//   3. MUL_X1_32:  Multiply rs1[31:0] × rs2[63:32] → tX1 (can be parallel with #2)
//   4. MUL_HH32:   Multiply rs1[63:32] × rs2[63:32] → tH
//   5. FINISH_HI:  rd = tH + ((tX0 + tX1 + carry32) >> 32) - no shifter needed!
//
// Benefits: 75% fewer microops, no shifter overhead, direct 32-bit extraction.
// Note: This expansion uses t0, t4-t6 (caller-saved registers).

module mulhu_expander #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    input  logic        clk_i,              // Clock
    input  logic        rst_ni,             // Synchronous reset
    input  logic [31:0] instr_i,            // Input instruction
    input  logic        is_mulhu_i,         // Instruction is MULHU
    input  logic        illegal_instr_i,    // From decoder
    input  logic        is_compressed_i,
    input  logic        issue_ack_i,        // Instruction acknowledged
    output logic [31:0] instr_o,            // Expanded instruction
    output logic        illegal_instr_o,
    output logic        is_compressed_o,
    output logic        fetch_stall_o,      // Stall while expanding
    output logic        is_last_micro_op_o  // Last micro-op in sequence
);

  // FSM States for MULHU expansion using fused 32-bit microops
  typedef enum logic [2:0] {
    IDLE,              // 0: No expansion
    MUL_LL32_OP,       // 1: Multiply low×low, latch carry
    MUL_X0_32_OP,      // 2: Cross multiply rs1_hi × rs2_lo
    MUL_X1_32_OP,      // 3: Cross multiply rs1_lo × rs2_hi
    MUL_HH32_OP,       // 4: Multiply high×high
    FINISH_HI_OP       // 5: Final combination without shifts
  } state_t;

  state_t state_d, state_q;

  // Saved instruction fields
  logic [4:0] rs1_q, rs1_d;
  logic [4:0] rs2_q, rs2_d;
  logic [4:0] rd_q, rd_d;

  logic [31:0] instr_o_reg;
  assign instr_o = instr_o_reg;

  // Register encoding constants (RISC-V ABI)
  localparam logic [4:0] REG_SP = 5'd2;   // x2 = sp
  localparam logic [4:0] REG_T0 = 5'd5;   // x5 = t0
  localparam logic [4:0] REG_T1 = 5'd6;   // x6 = t1
  localparam logic [4:0] REG_T2 = 5'd7;   // x7 = t2
  localparam logic [4:0] REG_T3 = 5'd28;  // x28 = t3
  localparam logic [4:0] REG_T4 = 5'd29;  // x29 = t4
  localparam logic [4:0] REG_T5 = 5'd30;  // x30 = t5
  localparam logic [4:0] REG_T6 = 5'd31;  // x31 = t6

  // Helper functions
  function automatic logic [31:0] make_r_type(
    input logic [6:0] funct7, input logic [4:0] rs2, input logic [4:0] rs1,
    input logic [2:0] funct3, input logic [4:0] rd, input logic [6:0] opcode
  );
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] make_i_type(
    input logic [11:0] imm, input logic [4:0] rs1,
    input logic [2:0] funct3, input logic [4:0] rd, input logic [6:0] opcode
  );
    return {imm, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] make_s_type(
    input logic [11:0] imm, input logic [4:0] rs2, input logic [4:0] rs1,
    input logic [2:0] funct3, input logic [6:0] opcode
  );
    return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
  endfunction

  // Helper function for R4-type instructions (for FINISH_HI)
  // Format: funct2(2) | rs3(5) | rs2(5) | rs1(5) | funct3(3) | rd(5) | opcode(7)
  function automatic logic [31:0] make_r4_type(
    input logic [1:0] funct2, input logic [4:0] rs3, input logic [4:0] rs2,
    input logic [4:0] rs1, input logic [2:0] funct3, input logic [4:0] rd,
    input logic [6:0] opcode
  );
    return {funct2, rs3, rs2, rs1, funct3, rd, opcode};
  endfunction

  // Main combinational logic
  always_comb begin
    illegal_instr_o    = illegal_instr_i;
    fetch_stall_o      = 1'b0;
    is_last_micro_op_o = 1'b0;
    is_compressed_o    = is_compressed_i;
    state_d            = state_q;
    rs1_d              = rs1_q;
    rs2_d              = rs2_q;
    rd_d               = rd_q;
    instr_o_reg        = instr_i;

    if (is_mulhu_i && state_q != IDLE) begin
      // In expansion - execute fused micro-ops
      fetch_stall_o = 1'b1;

      case (state_q)
        // Fused microop sequence (5 operations vs 20 in original)
        MUL_LL32_OP: begin
          // mul_ll32 (no dest reg - stores carry internally): MUL rs1_lo × rs2_lo
          // We use REG_T0 as dummy dest, but multiplier will latch upper 32 bits as carry
          // Encoding: custom-1 opcode (0101011), funct7=0000010, funct3=000
          instr_o_reg = make_r_type(7'b0000010, rs2_q, rs1_q, 3'b000, REG_T0, 7'b0101011);
          if (issue_ack_i) state_d = MUL_X0_32_OP;
        end

        MUL_X0_32_OP: begin
          // mul_x0_32 tX0, rs1_hi, rs2_lo: cross multiply (to multiplier0)
          // Encoding: custom-1 opcode (0101011), funct7=0000011, funct3=000
          instr_o_reg = make_r_type(7'b0000011, rs2_q, rs1_q, 3'b000, REG_T5, 7'b0101011);
          if (issue_ack_i) state_d = MUL_X1_32_OP;
        end

        MUL_X1_32_OP: begin
          // mul_x1_32 tX1, rs1_lo, rs2_hi: cross multiply (to multiplier1, can be parallel)
          // Encoding: custom-1 opcode (0101011), funct7=0000100, funct3=000
          instr_o_reg = make_r_type(7'b0000100, rs2_q, rs1_q, 3'b000, REG_T6, 7'b0101011);
          if (issue_ack_i) state_d = MUL_HH32_OP;
        end

        MUL_HH32_OP: begin
          // mul_hh32 tH, rs1_hi, rs2_hi: multiply high parts
          // Encoding: custom-1 opcode (0101011), funct7=0000101, funct3=000
          instr_o_reg = make_r_type(7'b0000101, rs2_q, rs1_q, 3'b000, REG_T4, 7'b0101011);
          if (issue_ack_i) state_d = FINISH_HI_OP;
        end

        FINISH_HI_OP: begin
          // finish_hi rd, tH, tX0, tX1, {carry32}: rd = tH + ((tX0 + tX1 + carry32) >> 32)
          // Uses R4-type format: funct2=00, rs3=REG_T6 (tX1), rs2=REG_T5 (tX0), rs1=REG_T4 (tH)
          // Encoding: custom-1 opcode (0101011), funct3=001
          // The carry32 is accessed from internal multiplier state
          instr_o_reg = make_r4_type(2'b00, REG_T6, REG_T5, REG_T4, 3'b001, rd_q, 7'b0101011);
          if (issue_ack_i) begin
            state_d = IDLE;
            fetch_stall_o = 1'b0;
            is_last_micro_op_o = 1'b1;
          end else begin
            is_last_micro_op_o = 1'b1;
          end
        end

        default: begin
          state_d = IDLE;
          fetch_stall_o = 1'b0;
        end
      endcase
    end else if (is_mulhu_i && state_q == IDLE) begin
      // Start MULHU expansion with fused microops
      rs1_d = instr_i[19:15];
      rs2_d = instr_i[24:20];
      rd_d  = instr_i[11:7];
      state_d = MUL_LL32_OP;
      fetch_stall_o = 1'b1;
      // First microop: mul_ll32 to latch carry
      instr_o_reg = make_r_type(7'b0000010, instr_i[24:20], instr_i[19:15], 3'b000, REG_T0, 7'b0101011);
    end else begin
      // Not MULHU - pass through
      state_d = IDLE;
    end
  end

  // State register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      state_q <= IDLE;
      rs1_q   <= '0;
      rs2_q   <= '0;
      rd_q    <= '0;
    end else begin
      state_q <= state_d;
      rs1_q   <= rs1_d;
      rs2_q   <= rs2_d;
      rd_q    <= rd_d;
    end
  end

endmodule