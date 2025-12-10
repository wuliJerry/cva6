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
    output logic [CVA6Cfg.TRANS_ID_BITS-1:0] mult_trans_id_o,
    // Karatsuba high bits (upper 2 bits of 66-bit result) - CSR
    output logic [                      1:0] khi_o,
    // Write enable for khi CSR - CSR
    output logic                             khi_we_o
);

  // Pipeline register signals
  logic [CVA6Cfg.TRANS_ID_BITS-1:0] trans_id_q;
  logic                             mult_valid_q;
  logic [CVA6Cfg.XLEN*2-1:0]        mult_result_d, mult_result_q;
  logic [                      1:0] khi_d, khi_q;
  logic                             khi_we_d, khi_we_q;

  // Fused microop state: 34-bit carry registers for Karatsuba partial products
  // Stores upper 34 bits [65:32] from 32x32 = 66-bit multiplies
  logic [                     33:0] carry_z0_q, carry_z0_d;
  logic [                     33:0] carry_z1_q, carry_z1_d;
  logic [                     33:0] carry_z2_q, carry_z2_d;

  // Storage for b0+b1 from PREP_ADDS (so we can compute both sums in parallel)
  logic [                     32:0] sum_b_q, sum_b_d;  // 33-bit to hold carry

  // control signals
  logic mult_valid;
  fu_op operation_q;

  assign mult_valid_o    = mult_valid_q;
  assign mult_trans_id_o = trans_id_q;

  // Accept MUL and fused microops as valid
  assign mult_valid = mult_valid_i && (
    operation_i == MUL ||
    operation_i == PREP_ADDS ||
    operation_i == MUL_Z0_32 ||
    operation_i == MUL_Z1_32 ||
    operation_i == MUL_Z2_32 ||
    operation_i == FINISH_K
  );

  // Operand extraction for 32-bit fused ops
  logic [31:0] a_lo, a_hi, b_lo, b_hi;
  assign a_lo = operand_a_i[31:0];
  assign a_hi = operand_a_i[63:32];
  assign b_lo = operand_b_i[31:0];
  assign b_hi = operand_b_i[63:32];

  // Single physical multiplier with operand selection
  logic [63:0] operand_a_selected, operand_b_selected;
  logic [65:0] product;  // Single 66-bit product (33×33 → 66 bits)
  logic [CVA6Cfg.XLEN-1:0] finish_k_result;

  // Operand selection mux - routes all operations through single 33×33 multiplier
  always_comb begin
    // Default: use lower 33 bits of operands
    operand_a_selected = {1'b0, operand_a_i[31:0]};
    operand_b_selected = {1'b0, operand_b_i[31:0]};

    case (operation_i)
      MUL: begin
        // Standard 64×64 MUL: use lower 33 bits (sign-extended or zero-extended based on upper bits)
        operand_a_selected = operand_a_i;
        operand_b_selected = operand_b_i;
      end

      MUL_Z0_32: begin
        // z0 = a_lo × b_lo (32×32)
        operand_a_selected = {32'b0, a_lo};
        operand_b_selected = {32'b0, b_lo};
      end

      MUL_Z1_32: begin
        // z1 = (a0+a1) × (b0+b1) (33×33)
        // Use stored sum_b from PREP_ADDS
        operand_a_selected = {31'b0, operand_a_i[32:0]};  // 33-bit sum from rs1
        operand_b_selected = {31'b0, sum_b_q};            // 33-bit stored sum
      end

      MUL_Z2_32: begin
        // z2 = a_hi × b_hi (32×32)
        operand_a_selected = {32'b0, a_hi};
        operand_b_selected = {32'b0, b_hi};
      end

      default: begin
        // PREP_ADDS, FINISH_K: use lower 33 bits
        operand_a_selected = {31'b0, operand_a_i[31:0]};
        operand_b_selected = {31'b0, operand_b_i[31:0]};
      end
    endcase
  end

  // SINGLE PHYSICAL MULTIPLIER - 33×33 → 66 bits
  // All operations routed through this one multiplier
  assign product = 66'(operand_a_selected * operand_b_selected);

  // Result selection and state management
  always_comb begin
    carry_z0_d = carry_z0_q;  // Hold carries by default
    carry_z1_d = carry_z1_q;
    carry_z2_d = carry_z2_q;
    sum_b_d = sum_b_q;  // Hold b sum by default
    khi_d = 2'b00;
    khi_we_d = 1'b0;
    finish_k_result = '0;
    mult_result_d = {{(CVA6Cfg.XLEN-32){1'b0}}, product[31:0]};  // Default: lower 32 bits

    case (operation_i)
      // Standard MUL: 64×64 multiply with khi overflow tracking
      MUL: begin
        mult_result_d = {product[63:0]};  // Lower 64 bits
        // Extract upper 2 bits from 66-bit product for khi CSR
        khi_d = product[65:64];
        khi_we_d = 1'b1;
      end

      // PREP_ADDS: Compute (a0+a1) and (b0+b1) in parallel
      // rd = a_lo + a_hi (returned to register file)
      // sum_b = b_lo + b_hi (stored internally for MUL_Z1_32)
      PREP_ADDS: begin
        mult_result_d = {{31'b0}, a_lo + a_hi};  // rd = a0 + a1 (33-bit with carry)
        sum_b_d = {1'b0, b_lo} + {1'b0, b_hi};   // Store b0 + b1 internally
      end

      // MUL_Z0_32: z0 = rs1_lo × rs2_lo, latch upper 34 bits [65:32] as carry_z0
      MUL_Z0_32: begin
        carry_z0_d = product[65:32];             // Store upper 34 bits
        mult_result_d = {32'b0, product[31:0]};  // Return lower 32 bits in result
      end

      // MUL_Z1_32: z1 = (a0+a1) × (b0+b1), latch upper 34 bits [65:32] as carry_z1
      MUL_Z1_32: begin
        carry_z1_d = product[65:32];             // Store upper 34 bits
        mult_result_d = {32'b0, product[31:0]};  // Return lower 32 bits
      end

      // MUL_Z2_32: z2 = rs1_hi × rs2_hi, latch upper 34 bits [65:32] as carry_z2
      MUL_Z2_32: begin
        carry_z2_d = product[65:32];             // Store upper 34 bits
        mult_result_d = {32'b0, product[31:0]};  // Return lower 32 bits
      end

      // FINISH_K: Karatsuba final combination
      // rd = tZ2 + (((tZ1 - tZ0 - tZ2) + carry_z0[32]) >> 32)
      // rs1 = tZ2, rs2 = tZ0, rs3 (from result_q) = tZ1
      FINISH_K: begin
        logic [65:0] temp_diff;  // 66-bit temporary for subtraction
        logic [65:0] temp_sum;   // 66-bit temporary for addition
        logic [31:0] tZ0_lower, tZ1_lower, tZ2_lower;
        logic [33:0] cross_product_sum;

        // Get lower 32 bits of the three partial products from previous results
        tZ0_lower = operand_b_i[31:0];  // rs2 = tZ0
        tZ1_lower = mult_result_q[31:0];  // rs3 = tZ1 from previous cycle
        tZ2_lower = operand_a_i[31:0];  // rs1 = tZ2

        // Karatsuba formula: z1 - z0 - z2 gives the cross terms
        // This is a 34-bit value potentially
        temp_diff = {2'b0, carry_z1_q} - {2'b0, carry_z0_q} - {2'b0, carry_z2_q};

        // Add the lower cross product contributions
        temp_sum = temp_diff + {{34'b0}, carry_z0_q[32]};  // Add carry bit from z0

        // Extract upper 32 bits of the cross product sum
        cross_product_sum = temp_sum[65:32];

        // Final result: tZ2 (high part) + cross product contribution
        finish_k_result = {carry_z2_q[31:0], 32'b0} + {{30'b0}, cross_product_sum};

        mult_result_d = finish_k_result;

        // Clear carries after use
        carry_z0_d = '0;
        carry_z1_d = '0;
        carry_z2_d = '0;
      end

      default: begin
        // Default case: lower 32 bits of product
        mult_result_d = {{(CVA6Cfg.XLEN-32){1'b0}}, product[31:0]};
      end
    endcase
  end

  // The output selection
  assign result_o = mult_result_q[CVA6Cfg.XLEN-1:0];

  // Output khi values (pipelined)
  assign khi_o = khi_q;
  assign khi_we_o = khi_we_q;

  // -----------------------
  // Output pipeline register
  // -----------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mult_valid_q  <= 1'b0;
      trans_id_q    <= '0;
      mult_result_q <= '0;
      khi_q         <= 2'b00;
      khi_we_q      <= 1'b0;
      carry_z0_q    <= '0;
      carry_z1_q    <= '0;
      carry_z2_q    <= '0;
      sum_b_q       <= '0;
    end else begin
      // Latch the inputs for the next cycle
      mult_valid_q  <= mult_valid;
      trans_id_q    <= trans_id_i;
      mult_result_q <= mult_result_d;
      khi_q         <= khi_d;
      khi_we_q      <= khi_we_d;
      carry_z0_q    <= carry_z0_d;
      carry_z1_q    <= carry_z1_d;
      carry_z2_q    <= carry_z2_d;
      sum_b_q       <= sum_b_d;
    end
  end

endmodule