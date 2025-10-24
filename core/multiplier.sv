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
//              This version is pruned to support ONLY the MUL instruction.
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

  // control signals
  logic mult_valid;

  assign mult_valid_o    = mult_valid_q;
  assign mult_trans_id_o = trans_id_q;

  // Only accept the MUL instruction as valid.
  assign mult_valid = mult_valid_i && (operation_i == MUL);

  // The core multiplier. For the lower XLEN bits (as required by MUL),
  // the result of a signed vs. unsigned multiply is identical.
  // We can therefore use a simple unsigned multiplication.
  assign mult_result_d = operand_a_i * operand_b_i;

  // The output selection is now fixed since we only support MUL.
  // MUL returns the lower XLEN bits of the full product.
  assign result_o = mult_result_q[CVA6Cfg.XLEN-1:0];

  // -----------------------
  // Output pipeline register
  // -----------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mult_valid_q  <= 1'b0;
      trans_id_q    <= '0;
      mult_result_q <= '0;
    end else begin
      // Latch the inputs for the next cycle
      mult_valid_q  <= mult_valid;
      trans_id_q    <= trans_id_i;
      mult_result_q <= mult_result_d;
    end
  end

endmodule