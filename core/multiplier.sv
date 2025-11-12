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
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
//
// Description: Multiplication Unit with one pipeline register
//              Supports MUL and fused 32-bit microops for MULHU expansion.
//

module multiplier
  import ariane_pkg::*;
#(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty
) (
    // Subsystem Clock - SUBSYSTEM
    input  logic                             clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input  logic                             rst_ni,
    // Multiplier transaction ID - Mult
    input  logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_i,
    // Multiplier instruction is valid - Mult
    input  logic                             mult_valid_i,
    // Multiplier operation - Mult
    input  fu_op                             operation_i,
    // A operand - Mult
    input  logic [         CVA6Cfg.XLEN-1:0] operand_a_i,
    // B operand - Mult
    input  logic [         CVA6Cfg.XLEN-1:0] operand_b_i,
    // Multiplier result - Mult
    output logic [         CVA6Cfg.XLEN-1:0] result_o,
    // Mutliplier result is valid - Mult
    output logic                             mult_valid_o,
    // Multiplier transaction ID - Mult
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] mult_trans_id_o
);

  // Pipeline register signals
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_q;
  logic                             mult_valid_q;
  logic [CVA6Cfg.XLEN*2-1:0]        mult_result_d, mult_result_q;

  // Fused microop state: 32-bit carry register for MUL_LL32
  logic [31:0] carry32_q, carry32_d;

  // control signals
  logic mult_valid;
  fu_op operation_q;

  assign mult_valid_o    = mult_valid_q;
  assign mult_trans_id_o = trans_id_q;

  // Accept MUL and fused microops as valid
  assign mult_valid = mult_valid_i && (
    operation_i == MUL ||
    operation_i == MUL_LL32 ||
    operation_i == MUL_X0_32 ||
    operation_i == MUL_X1_32 ||
    operation_i == MUL_HH32 ||
    operation_i == FINISH_HI
  );

  // Operand extraction for 32-bit fused ops
  logic [31:0] a_lo, a_hi, b_lo, b_hi;
  assign a_lo = operand_a_i[31:0];
  assign a_hi = operand_a_i[63:32];
  assign b_lo = operand_b_i[31:0];
  assign b_hi = operand_b_i[63:32];

  // Core multiplier and result selection
  logic [63:0] mul32_result;  // Result of 32×32 multiply
  logic [CVA6Cfg.XLEN-1:0] finish_hi_result;

  always_comb begin
    mult_result_d = operand_a_i * operand_b_i;  // Default: full 64×64 multiply
    mul32_result = '0;
    carry32_d = carry32_q;  // Hold carry by default
    finish_hi_result = '0;

    case (operation_i)
      MUL_LL32: begin
        // Multiply low×low, latch upper 32 bits as carry
        mul32_result = a_lo * b_lo;
        carry32_d = mul32_result[63:32];
        mult_result_d = {32'b0, mul32_result[31:0]};  // Lower 32 bits to result
      end

      MUL_X0_32: begin
        // Cross multiply: rs1_hi × rs2_lo, result is lower 32 bits
        mul32_result = a_hi * b_lo;
        mult_result_d = {32'b0, mul32_result[31:0]};
      end

      MUL_X1_32: begin
        // Cross multiply: rs1_lo × rs2_hi, result is lower 32 bits
        mul32_result = a_lo * b_hi;
        mult_result_d = {32'b0, mul32_result[31:0]};
      end

      MUL_HH32: begin
        // Multiply high×high, full 64-bit result
        mul32_result = a_hi * b_hi;
        mult_result_d = mul32_result;
      end

      FINISH_HI: begin
        // rd = rs1 + ((rs2 + rs3 + carry32) >> 32)
        // rs1 = operand_a (tH), rs2 = operand_b (tX0), rs3 from result_q (tX1)
        logic [64:0] sum_temp;  // 65-bit to capture carry
        logic [31:0] tX1_lower;

        tX1_lower = mult_result_q[31:0];  // tX1 from previous stage

        // Sum the three 32-bit cross products plus carry
        sum_temp = {1'b0, operand_b_i[31:0]} + {1'b0, tX1_lower} + {1'b0, carry32_q};

        // Take upper 32 bits and add to tH (operand_a)
        finish_hi_result = operand_a_i + {32'b0, sum_temp[63:32]};
        mult_result_d = finish_hi_result;

        // Clear carry after use
        carry32_d = '0;
      end

      default: begin
        // MUL: standard 64×64 multiply, return lower 64 bits
        mult_result_d = operand_a_i * operand_b_i;
      end
    endcase
  end

  // Output selection based on operation type
  assign result_o = mult_result_q[CVA6Cfg.XLEN-1:0];

  // -----------------------
  // Output pipeline register
  // -----------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mult_valid_q  <= 1'b0;
      trans_id_q    <= '0;
      mult_result_q <= '0;
      carry32_q     <= '0;
    end else begin
      // Latch the inputs for the next cycle
      mult_valid_q  <= mult_valid;
      trans_id_q    <= trans_id_i;
      mult_result_q <= mult_result_d;
      carry32_q     <= carry32_d;
    end
  end

endmodule