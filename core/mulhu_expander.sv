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
// Description: MULHU instruction expander - breaks MULHU into Karatsuba algorithm
//              micro-ops sequence. This allows a core with only MUL support (which
//              produces 66-bit results with upper 2 bits in khi CSR) to execute MULHU.
//
// The expansion implements unsigned 64x64->128 bit multiplication using Karatsuba,
// returning the upper 64 bits. Algorithm:
//   1. Split operands into high/low 32-bit parts
//   2. Compute 4 partial products using MUL (66-bit with khi CSR)
//   3. Combine with proper carries to get upper 64 bits in rd
//
// Note: This expansion clobbers t0-t11 (caller-saved registers).
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

  // FSM States for MULHU Karatsuba expansion
  typedef enum logic [4:0] {
    IDLE,              // 0: No expansion
    // Extract hi/lo 32-bit parts
    SRLI_T6,           // 1: t6 = rs1 >> 32 (rs1_hi)
    SRLI_T8,           // 2: t8 = rs2 >> 32 (rs2_hi)
    LI_T9,             // 3: t9 = 0xFFFFFFFF
    SRLI_T9,           // 4: t9 = t9 >> 32 (mask = 0x00000000FFFFFFFF)
    AND_T5,            // 5: t5 = rs1 & t9 (rs1_lo)
    AND_T7,            // 6: t7 = rs2 & t9 (rs2_lo)
    // Compute partial products with khi CSR reads
    MUL1,              // 7: t10 = t5 * t7 (lo*lo), khi gets overflow
    CSRR1,             // 8: t11 = khi
    MUL2,              // 9: t10 = t5 * t8 (lo*hi), khi gets overflow
    CSRR2,             // 10: t9 = khi
    MUL3,              // 11: t10 = t6 * t7 (hi*lo), khi gets overflow
    CSRR3,             // 12: t7 = khi
    MUL4,              // 13: t10 = t6 * t8 (hi*hi), khi gets overflow
    CSRR4,             // 14: rd = khi
    // Combine partial products - implement Karatsuba carries
    SRLI_T11,          // 15: t11 = t11 >> 32
    ADD1,              // 16: t10 = t10 + t11
    SLTU1,             // 17: t11 = (t10 < t11) ? 1 : 0
    SLLI_T9,           // 18: t9 = t9 << 32
    ADD2,              // 19: t10 = t10 + t9
    SLTU2,             // 20: t9 = (t10 < t9) ? 1 : 0
    SLLI_T7,           // 21: t7 = t7 << 32
    ADD3,              // 22: t10 = t10 + t7
    SLTU3,             // 23: t7 = (t10 < t7) ? 1 : 0
    ADD4,              // 24: t11 = t11 + t9
    ADD5,              // 25: t11 = t11 + t7
    SLLI_RD,           // 26: rd = rd << 32
    SRLI_T10,          // 27: t10 = t10 >> 32
    ADD6,              // 28: rd = rd + t10
    ADD_FINAL          // 29: rd = rd + t11
  } state_t;

  state_t state_d, state_q;

  // Saved instruction fields
  logic [4:0] rs1_q, rs1_d;
  logic [4:0] rs2_q, rs2_d;
  logic [4:0] rd_q, rd_d;

  logic [31:0] instr_o_reg;
  assign instr_o = instr_o_reg;

  // Register encoding constants (RISC-V ABI)
  localparam logic [4:0] REG_T5 = 5'd30;  // x30 = t5
  localparam logic [4:0] REG_T6 = 5'd31;  // x31 = t6
  localparam logic [4:0] REG_T7 = 5'd7;   // x7 = t2/t7
  localparam logic [4:0] REG_T8 = 5'd28;  // x28 = t3/t8
  localparam logic [4:0] REG_T9 = 5'd29;  // x29 = t4/t9
  localparam logic [4:0] REG_T10 = 5'd5;  // x5 = t0/t10
  localparam logic [4:0] REG_T11 = 5'd6;  // x6 = t1/t11

  // CSR address for khi
  localparam logic [11:0] CSR_KHI = 12'h7C3;

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
        // Extract parts
        SRLI_T6: begin
          instr_o_reg = make_i_type(12'd32, rs1_q, 3'b101, REG_T6, 7'b0010011);
          if (issue_ack_i) state_d = SRLI_T8;
        end
        SRLI_T8: begin
          instr_o_reg = make_i_type(12'd32, rs2_q, 3'b101, REG_T8, 7'b0010011);
          if (issue_ack_i) state_d = LI_T9;
        end
        LI_T9: begin
          instr_o_reg = make_i_type(12'hFFF, 5'd0, 3'b000, REG_T9, 7'b0010011);
          if (issue_ack_i) state_d = SRLI_T9;
        end
        SRLI_T9: begin
          instr_o_reg = make_i_type(12'd32, REG_T9, 3'b101, REG_T9, 7'b0010011);
          if (issue_ack_i) state_d = AND_T5;
        end
        AND_T5: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T9, rs1_q, 3'b111, REG_T5, 7'b0110011);
          if (issue_ack_i) state_d = AND_T7;
        end
        AND_T7: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T9, rs2_q, 3'b111, REG_T7, 7'b0110011);
          if (issue_ack_i) state_d = MUL1;
        end

        // Compute partial products with CSR reads
        MUL1: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T7, REG_T5, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = CSRR1;
        end
        CSRR1: begin
          instr_o_reg = make_i_type(CSR_KHI, 5'd0, 3'b010, REG_T11, 7'b1110011);
          if (issue_ack_i) state_d = MUL2;
        end
        MUL2: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T8, REG_T5, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = CSRR2;
        end
        CSRR2: begin
          instr_o_reg = make_i_type(CSR_KHI, 5'd0, 3'b010, REG_T9, 7'b1110011);
          if (issue_ack_i) state_d = MUL3;
        end
        MUL3: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T7, REG_T6, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = CSRR3;
        end
        CSRR3: begin
          instr_o_reg = make_i_type(CSR_KHI, 5'd0, 3'b010, REG_T7, 7'b1110011);
          if (issue_ack_i) state_d = MUL4;
        end
        MUL4: begin
          instr_o_reg = make_r_type(7'b0000001, REG_T8, REG_T6, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = CSRR4;
        end
        CSRR4: begin
          instr_o_reg = make_i_type(CSR_KHI, 5'd0, 3'b010, rd_q, 7'b1110011);
          if (issue_ack_i) state_d = SRLI_T11;
        end

        // Combine partial products
        SRLI_T11: begin
          instr_o_reg = make_i_type(12'd32, REG_T11, 3'b101, REG_T11, 7'b0010011);
          if (issue_ack_i) state_d = ADD1;
        end
        ADD1: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T11, REG_T10, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = SLTU1;
        end
        SLTU1: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T11, REG_T10, 3'b011, REG_T11, 7'b0110011);
          if (issue_ack_i) state_d = SLLI_T9;
        end
        SLLI_T9: begin
          instr_o_reg = make_i_type(12'd32, REG_T9, 3'b001, REG_T9, 7'b0010011);
          if (issue_ack_i) state_d = ADD2;
        end
        ADD2: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T9, REG_T10, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = SLTU2;
        end
        SLTU2: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T9, REG_T10, 3'b011, REG_T9, 7'b0110011);
          if (issue_ack_i) state_d = SLLI_T7;
        end
        SLLI_T7: begin
          instr_o_reg = make_i_type(12'd32, REG_T7, 3'b001, REG_T7, 7'b0010011);
          if (issue_ack_i) state_d = ADD3;
        end
        ADD3: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T7, REG_T10, 3'b000, REG_T10, 7'b0110011);
          if (issue_ack_i) state_d = SLTU3;
        end
        SLTU3: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T7, REG_T10, 3'b011, REG_T7, 7'b0110011);
          if (issue_ack_i) state_d = ADD4;
        end
        ADD4: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T9, REG_T11, 3'b000, REG_T11, 7'b0110011);
          if (issue_ack_i) state_d = ADD5;
        end
        ADD5: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T7, REG_T11, 3'b000, REG_T11, 7'b0110011);
          if (issue_ack_i) state_d = SLLI_RD;
        end
        SLLI_RD: begin
          instr_o_reg = make_i_type(12'd32, rd_q, 3'b001, rd_q, 7'b0010011);
          if (issue_ack_i) state_d = SRLI_T10;
        end
        SRLI_T10: begin
          instr_o_reg = make_i_type(12'd32, REG_T10, 3'b101, REG_T10, 7'b0010011);
          if (issue_ack_i) state_d = ADD6;
        end
        ADD6: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T10, rd_q, 3'b000, rd_q, 7'b0110011);
          if (issue_ack_i) state_d = ADD_FINAL;
        end
        ADD_FINAL: begin
          instr_o_reg = make_r_type(7'b0000000, REG_T11, rd_q, 3'b000, rd_q, 7'b0110011);
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
      // Start MULHU expansion
      rs1_d = instr_i[19:15];
      rs2_d = instr_i[24:20];
      rd_d  = instr_i[11:7];
      state_d = SRLI_T6;
      fetch_stall_o = 1'b1;
      // t6 = rs1 >> 32
      instr_o_reg = make_i_type(12'd32, instr_i[19:15], 3'b101, REG_T6, 7'b0010011);
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