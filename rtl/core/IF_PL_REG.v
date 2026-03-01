module IF_PL_REG #(parameter WIDTH = 32)(
    input clk, reset,
    input [WIDTH-1:0] Instr,
    input [WIDTH-1:0] PC_in,
    input [WIDTH-1:0] PC4_in,
    input Stall,Flush,
    output reg [WIDTH-1:0] InstrF,
    output reg [WIDTH-1:0] PCF,
    output reg [WIDTH-1:0] PC4_out
);
    always @(posedge clk or posedge reset) begin
        if (reset||Flush) begin
            InstrF  <= 0;
            PCF     <= 0;
            PC4_out <= 0;
        end else if (!Stall) begin // Only update when not stalled
            InstrF  <= Instr;
            PCF     <= PC_in;
            PC4_out <= PC4_in;
        end
    end
endmodule