module alu #(parameter WIDTH = 32) (
    input       [WIDTH-1:0] a, b,       // operands
    input       [3:0]       alu_ctrl,   // ALU control
    output reg  [WIDTH-1:0] alu_out,    // ALU output
    output                  zero,       // zero flag
    output                  err_flag_alu     // error flag (ADD/SUB/SLT/SLTU/logic)
);

    // Signed views
    reg signed [WIDTH-1:0] a_signed, b_signed;

    // Temporary ALU result (we don't drive alu_out directly from case)
    reg [WIDTH-1:0] alu_temp;

    // Common subtract path: a - b = a + ~b + 1 (WIDTH+1 to capture carry)
    wire [WIDTH:0]   sub_ext    = {1'b0, a} + {1'b0, ~b} + {{WIDTH{1'b0}}, 1'b1};
    wire [WIDTH-1:0] sub_res    = sub_ext[WIDTH-1:0];
    wire             carry_out  = sub_ext[WIDTH];   // for unsigned (borrow = ~carry_out)

    // Signed overflow for a - b
    wire sgn_a   = a[WIDTH-1];
    wire sgn_b   = b[WIDTH-1];
    wire sgn_res = sub_res[WIDTH-1];

    wire ov_sub        = (sgn_a ^ sgn_b) & (sgn_a ^ sgn_res);
    wire slt_expected  = sgn_res ^ ov_sub;   // correct signed < result bit
    wire sltu_expected = ~carry_out;         // unsigned < is "borrow"

    // Residue-related signals (mod 31 -> 5 bits)
    reg  [4:0] r_a, r_b;       // residues of a and b
    reg  [4:0] r_pred;         // predicted residue of result
    reg  [4:0] r_full;         // residue of actual result (alu_temp)
    reg        check_enable;   // only 1 for ADD/SUB

    // Wider intermediates so we don't overflow at 5 bits
    reg  [5:0] sum_add;        // for ADD: r_a + r_b   (0..60)
    reg  [5:0] sum_sub;        // for SUB: r_a + 31-r_b (0..62)

    // Extra error flags
    reg        slt_err;
    reg        sltu_err;
    reg        and_err;
    reg        or_err;
    reg        xor_err;

    // ----------------------------------------------------------------
    // Residue function: x mod 31
    // ----------------------------------------------------------------
    function [4:0] residue31;
        input [WIDTH-1:0] x;
        begin
            residue31 = x % 31;   // 31 = 2^5 - 1
        end
    endfunction

    // ----------------------------------------------------------------
    // Main combinational block: compute ALU result + all checks
    // ----------------------------------------------------------------
    always @* begin
        // Default assignments (to avoid inferred latches)
        a_signed     = a;
        b_signed     = b;
        alu_temp     = {WIDTH{1'b0}};

        r_a          = 5'd0;
        r_b          = 5'd0;
        r_pred       = 5'd0;
        r_full       = 5'd0;
        check_enable = 1'b0;

        sum_add      = 6'd0;
        sum_sub      = 6'd0;

        slt_err      = 1'b0;
        sltu_err     = 1'b0;
        and_err      = 1'b0;
        or_err       = 1'b0;
        xor_err      = 1'b0;

        case (alu_ctrl)
            // --------------------------------------------------------
            // ADD: alu_temp = a + b
            // Residue check: r_pred = (r(a) + r(b)) mod 31
            // --------------------------------------------------------
            4'b0000: begin  // ADD
                alu_temp     = a + b;
                check_enable = 1'b1;

                // Compute operand residues
                r_a    = residue31(a);
                r_b    = residue31(b);

                // 6-bit sum to avoid early wrap at 32
                sum_add = {1'b0, r_a} + {1'b0, r_b}; // 0..60

                // Predicted residue of result
                r_pred = sum_add % 31;
            end

            // --------------------------------------------------------
            // SUB: alu_temp = a - b
            // Residue check: r_pred = (r(a) - r(b)) mod 31
            // Implemented as r(a) + (31 - r(b)) mod 31
            // --------------------------------------------------------
            4'b0001: begin  // SUB
                alu_temp     = sub_res;   // use common subtract result
                check_enable = 1'b1;

                r_a    = residue31(a);
                r_b    = residue31(b);

                // 6-bit sum for r_a + (31 - r_b)
                sum_sub = {1'b0, r_a} + {1'b0, (5'd31 - r_b)}; // 0..62

                // r_pred = (r_a - r_b) mod 31
                r_pred = sum_sub % 31;
            end

            // --------------------------------------------------------
            // AND
            // Check: result must never have 1 where a or b has 0
            // (alu_temp & ~a) == 0 and (alu_temp & ~b) == 0
            // --------------------------------------------------------
            4'b0010: begin  // AND
                alu_temp = a & b;

                if ( ( (alu_temp & ~a) != {WIDTH{1'b0}} ) ||
                     ( (alu_temp & ~b) != {WIDTH{1'b0}} ) )
                    and_err = 1'b1;
            end

            // --------------------------------------------------------
            // OR
            // Check: every 1 in (a|b) must be 1 in alu_out
            // ((a | b) & ~alu_temp) == 0
            // --------------------------------------------------------
            4'b0011: begin  // OR
                alu_temp = a | b;

                if ( ((a | b) & ~alu_temp) != {WIDTH{1'b0}} )
                    or_err = 1'b1;
            end

            // --------------------------------------------------------
            // XOR
            // Check: parity(alu_out) == parity(a) ^ parity(b)
            // --------------------------------------------------------
            4'b0100: begin  // XOR
                alu_temp = a ^ b;

                // Reduction XOR gives parity
                if ( (^alu_temp) != ((^a) ^ (^b)) )
                    xor_err = 1'b1;
            end

            // --------------------------------------------------------
            // SLT (signed) - result is 0/1 in bit 0
            // Check: alu_temp[0] must equal slt_expected
            // --------------------------------------------------------
            4'b0101: begin  // SLT (signed)
                alu_temp = (a_signed < b_signed) ? {{WIDTH-1{1'b0}}, 1'b1}
                                                 : {WIDTH{1'b0}};

                if (alu_temp[0] != slt_expected)
                    slt_err = 1'b1;
            end

            // --------------------------------------------------------
            // Shifts: unchanged, no checking yet
            // --------------------------------------------------------
            4'b0110: begin  // SRL
                alu_temp = a >> b[4:0];
            end

            4'b0111: begin  // SLL
                alu_temp = a << b[4:0];
            end

            4'b1000: begin  // SRA
                alu_temp = a_signed >>> b[4:0];
            end

            // --------------------------------------------------------
            // SLTU (unsigned) - result is 0/1 in bit 0
            // Check: alu_temp[0] must equal sltu_expected = ~carry_out
            // --------------------------------------------------------
            4'b1001: begin  // SLTU (unsigned)
                alu_temp = (a < b) ? {{WIDTH-1{1'b0}}, 1'b1}
                                   : {WIDTH{1'b0}};

                if (alu_temp[0] != sltu_expected)
                    sltu_err = 1'b1;
            end

            default: begin
                alu_temp = {WIDTH{1'b0}};
            end
        endcase

        // Compute residue of the actual result, for whatever alu_temp is.
        // This is only *used* when check_enable = 1 (ADD/SUB).
        r_full  = residue31(alu_temp);

        // Drive final ALU output
        alu_out = alu_temp;
    end

    // Zero flag based on final alu_out
    assign zero = (alu_out == {WIDTH{1'b0}});

    // Residue error for ADD/SUB
    wire residue_err = check_enable && (r_pred != r_full);

    // Overall error flag: arithmetic residue OR compare errors OR logic errors
    assign err_flag = residue_err | slt_err | sltu_err | and_err | or_err | xor_err;

endmodule
