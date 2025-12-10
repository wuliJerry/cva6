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
// Description: MULHU instruction expander - breaks MULHU into fused 32-bit Karatsuba microops.
//              Uses custom bespoke operations to eliminate unnecessary shifts/masks.
//
// The expansion implements unsigned 64x64->128 bit multiplication using Karatsuba,
// returning the upper 64 bits using 5 fused microops (vs 29 standard RISC-V ops):
//   1. PREP_ADDS:  Compute (a0+a1) → tA, store (b0+b1) internally
//   2. MUL_Z0_32:  Multiply rs1[31:0] × rs2[31:0], latch upper 34 bits as carry_z0
//   3. MUL_Z1_32:  Multiply tA × (b0+b1), latch upper 34 bits as carry_z1
//   4. MUL_Z2_32:  Multiply rs1[63:32] × rs2[63:32], latch upper 34 bits as carry_z2
//   5. FINISH_K:   rd = z2 + (((z1 - z0 - z2) + carry_z0[32]) >> 32)
//
// Benefits: 83% fewer microops, no shifter overhead, direct 32-bit extraction.
// Note: This expansion uses t5 (caller-saved register).

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
    PREP_ADDS_OP,      // 1: Compute (a0+a1) and store (b0+b1)
    MUL_Z0_32_OP,      // 2: Multiply low×low, latch carry_z0
    MUL_Z1_32_OP,      // 3: Multiply (a0+a1)×(b0+b1), latch carry_z1
    MUL_Z2_32_OP,      // 4: Multiply high×high, latch carry_z2
    FINISH_K_OP        // 5: Final Karatsuba combination
  } state_t;

  state_t state_d, state_q;

  // Saved instruction fields
  logic [4:0] rs1_q, rs1_d;
  logic [4:0] rs2_q, rs2_d;
  logic [4:0] rd_q, rd_d;

  logic [31:0] instr_o_reg;
  assign instr_o = instr_o_reg;

  // Register encoding constants (RISC-V ABI)
  localparam logic [4:0] REG_T5 = 5'd30;  // x30 = t5 (temp for tA)

  // Custom-1 opcode for fused microops
  localparam logic [6:0] OPCODE_CUSTOM1 = 7'b0101011;

  // Helper function for R-type instructions
  function automatic logic [31:0] make_r_type(
    input logic [6:0] funct7, input logic [4:0] rs2, input logic [4:0] rs1,
    input logic [2:0] funct3, input logic [4:0] rd, input logic [6:0] opcode
  );
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  // Helper function for R4-type instructions (for FINISH_K)
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
        // Fused microop sequence (5 operations vs 29 in original)
        PREP_ADDS_OP: begin
          // prep_adds t5, rs1, rs2: Computes tA = rs1[31:0] + rs1[63:32]
          // Also stores b0+b1 internally in multiplier
          // Encoding: custom-1 opcode, funct7=0000001, funct3=000
          instr_o_reg = make_r_type(7'b0000001, rs2_q, rs1_q, 3'b000, REG_T5, OPCODE_CUSTOM1);
          if (issue_ack_i) state_d = MUL_Z0_32_OP;
        end

        MUL_Z0_32_OP: begin
          // mul_z0_32: Multiply rs1[31:0] × rs2[31:0], latch upper 34 bits
          // Don't need result (it's discarded), but carry_z0 is stored in multiplier
          // Encoding: custom-1 opcode, funct7=0000010, funct3=000
          // We use REG_T5 as dummy dest
          instr_o_reg = make_r_type(7'b0000010, rs2_q, rs1_q, 3'b000, REG_T5, OPCODE_CUSTOM1);
          if (issue_ack_i) state_d = MUL_Z1_32_OP;
        end

        MUL_Z1_32_OP: begin
          // mul_z1_32 t5, t5, (internal b0+b1): Cross multiply (a0+a1) × (b0+b1)
          // rs1 = t5 (contains a0+a1), multiplier uses stored b0+b1
          // Encoding: custom-1 opcode, funct7=0000011, funct3=000
          instr_o_reg = make_r_type(7'b0000011, rs2_q, REG_T5, 3'b000, REG_T5, OPCODE_CUSTOM1);
          if (issue_ack_i) state_d = MUL_Z2_32_OP;
        end

        MUL_Z2_32_OP: begin
          // mul_z2_32: Multiply rs1[63:32] × rs2[63:32], latch upper 34 bits
          // Encoding: custom-1 opcode, funct7=0000100, funct3=000
          instr_o_reg = make_r_type(7'b0000100, rs2_q, rs1_q, 3'b000, REG_T5, OPCODE_CUSTOM1);
          if (issue_ack_i) state_d = FINISH_K_OP;
        end

        FINISH_K_OP: begin
          // finish_k rd, t5(z2), t5(z0), t5(z1): Final Karatsuba combination
          // Uses R4-type format: rd, rs1(dummy), rs2(dummy), rs3(z1 from t5)
          // All carries are accessed from internal multiplier state
          // Encoding: custom-1 opcode, funct2=00, funct3=001
          instr_o_reg = make_r4_type(2'b00, REG_T5, REG_T5, REG_T5, 3'b001, rd_q, OPCODE_CUSTOM1);
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
      state_d = PREP_ADDS_OP;
      fetch_stall_o = 1'b1;
      // First microop: prep_adds to compute and store both sums
      instr_o_reg = make_r_type(7'b0000001, instr_i[24:20], instr_i[19:15], 3'b000, REG_T5, OPCODE_CUSTOM1);
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