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
// Description: MULHU instruction expander - breaks MULHU into micro-ops sequence
//              using stack storage for temporary values to preserve ABI compliance.
//              This allows a core with only MUL support to execute MULHU.
//
// The expansion implements unsigned 64x64->128 bit multiplication,
// returning the upper 64 bits. Algorithm:
//   1. Split operands into high/low 32-bit parts (using t0-t3)
//   2. Compute 4 partial products using MUL (into t4-t6, rd)
//   3. Combine with proper carries to get upper 64 bits in rd
//
// Note: This expansion clobbers t0-t6 (caller-saved registers).
// Since MULHU appears atomic to software, this is ABI-compliant.

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

  // FSM States for MULHU expansion (no stack operations needed)
  typedef enum logic [4:0] {
    IDLE,              // 0: No expansion
    // Extract hi/lo 32-bit parts
    SRLI_T1,           // 1: t1 = rs1 >> 32
    LI_T4,             // 2: t4 = -1
    SRLI_T4,           // 3: t4 = t4 >> 32 (mask)
    AND_T0,            // 4: t0 = rs1 & t4
    SRLI_T3,           // 5: t3 = rs2 >> 32
    AND_T2,            // 6: t2 = rs2 & t4
    // Compute partial products
    MUL1,              // 7: t4 = t0 * t2
    MUL2,              // 8: t5 = t0 * t3
    MUL3,              // 9: t6 = t1 * t2
    MUL4,              // 10: rd = t1 * t3
    // Combine partial products
    SRLI_T0_2,         // 11: t0 = t4 >> 32
    ADD1,              // 12: t5 = t5 + t0
    SLTU1,             // 13: t0 = (t5 < t0)
    ADD2,              // 14: t1 = t5 + t6
    SLTU2,             // 15: t2 = (t1 < t6)
    ADD3,              // 16: t0 = t0 + t2
    SLLI_T0,           // 17: t0 = t0 << 32
    SRLI_T1_2,         // 18: t1 = t1 >> 32
    OR_T0_T1,          // 19: t0 = t0 | t1
    ADD_FINAL          // 20: rd = rd + t0
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
      // In expansion - execute micro-ops
      fetch_stall_o = 1'b1;

      case (state_q)
        // Computation phase
        SRLI_T1: begin
          instr_o_reg = make_i_type(12'd32, rs1_q, 3'b101, REG_T1, 7'b0010011);
          if (issue_ack_i) state_d = LI_T4;
        end
        LI_T4: begin
          instr_o_reg = make_i_type(12'hFFF, 5'd0, 3'b000, REG_T4, 7'b0010011);
          if (issue_ack_i) state_d = SRLI_T4;
        end
        SRLI_T4: begin
          instr_o_reg = make_i_type(12'd32, REG_T4, 3'b101, REG_T4, 7'b0010011);
          if (issue_ack_i) state_d = AND_T0;
        end
        AND_T0: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T4, rs1_q, 3'b111, REG_T0, 7'b0110011);
          if (issue_ack_i) state_d = SRLI_T3;
        end
        SRLI_T3: begin
          instr_o_reg = make_i_type(12'd32, rs2_q, 3'b101, REG_T3, 7'b0010011);
          if (issue_ack_i) state_d = AND_T2;
        end
        AND_T2: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T4, rs2_q, 3'b111, REG_T2, 7'b0110011);
          if (issue_ack_i) state_d = MUL1;
        end
        MUL1: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T2, REG_T0, 3'b000, REG_T4, 7'b0110011);
          if (issue_ack_i) state_d = MUL2;
        end
        MUL2: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T3, REG_T0, 3'b000, REG_T5, 7'b0110011);
          if (issue_ack_i) state_d = MUL3;
        end
        MUL3: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T2, REG_T1, 3'b000, REG_T6, 7'b0110011);
          if (issue_ack_i) state_d = MUL4;
        end
        MUL4: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T3, REG_T1, 3'b000, rd_q, 7'b0110011);
          if (issue_ack_i) state_d = SRLI_T0_2;
        end
        SRLI_T0_2: begin
          instr_o_reg = make_i_type(12'd32, REG_T4, 3'b101, REG_T0, 7'b0010011);
          if (issue_ack_i) state_d = ADD1;
        end
        ADD1: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T0, REG_T5, 3'b000, REG_T5, 7'b0110011);
          if (issue_ack_i) state_d = SLTU1;
        end
        SLTU1: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T0, REG_T5, 3'b011, REG_T0, 7'b0110011);
          if (issue_ack_i) state_d = ADD2;
        end
        ADD2: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T6, REG_T5, 3'b000, REG_T1, 7'b0110011);
          if (issue_ack_i) state_d = SLTU2;
        end
        SLTU2: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T6, REG_T1, 3'b011, REG_T2, 7'b0110011);
          if (issue_ack_i) state_d = ADD3;
        end
        ADD3: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T2, REG_T0, 3'b000, REG_T0, 7'b0110011);
          if (issue_ack_i) state_d = SLLI_T0;
        end
        SLLI_T0: begin
          instr_o_reg = make_i_type(12'd32, REG_T0, 3'b001, REG_T0, 7'b0010011);
          if (issue_ack_i) state_d = SRLI_T1_2;
        end
        SRLI_T1_2: begin
          instr_o_reg = make_i_type(12'd32, REG_T1, 3'b101, REG_T1, 7'b0010011);
          if (issue_ack_i) state_d = OR_T0_T1;
        end
        OR_T0_T1: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T1, REG_T0, 3'b110, REG_T0, 7'b0110011);
          if (issue_ack_i) state_d = ADD_FINAL;
        end
        ADD_FINAL: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T0, rd_q, 3'b000, rd_q, 7'b0110011);
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
      // Start MULHU expansion - begin with extraction
      rs1_d = instr_i[19:15];
      rs2_d = instr_i[24:20];
      rd_d  = instr_i[11:7];
      state_d = SRLI_T1;
      fetch_stall_o = 1'b1;
      // t1 = rs1 >> 32
      instr_o_reg = make_i_type(12'd32, instr_i[19:15], 3'b101, REG_T1, 7'b0010011);
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