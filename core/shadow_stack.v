
module shadow_stack #(
    parameter integer DEPTH = 256
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        push_en,
    input  wire        popchk_en,
    input  wire [31:0] ra_value,
    output reg         fault
);

    localparam integer ADDR_W = $clog2(DEPTH);

    reg [31:0] mem [0:DEPTH-1];
    reg [ADDR_W:0] sp;

    wire [ADDR_W:0] sp_minus1 = sp - 1'b1;
    wire [ADDR_W-1:0] sp_idx      = sp[ADDR_W-1:0];
    wire [ADDR_W-1:0] sp_minus1_idx = sp_minus1[ADDR_W-1:0];

    always @(posedge clk) begin
        if (reset) begin
            sp    <= { (ADDR_W+1){1'b0} };
            fault <= 1'b0;
        end else if (!fault) begin
            if (push_en && popchk_en) begin
                fault <= 1'b1;
            end else if (push_en) begin
                if (sp >= DEPTH) begin
                    fault <= 1'b1;
                end else begin
                    mem[sp_idx] <= ra_value;
                    sp <= sp + 1'b1;
                end
            end else if (popchk_en) begin
                if (sp == 0) begin
                    fault <= 1'b1;
                end else begin
                    sp <= sp_minus1;
                    if (mem[sp_minus1_idx] != ra_value)
                        fault <= 1'b1;
                end
            end
        end
    end

endmodule