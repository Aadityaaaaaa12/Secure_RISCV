module MW_PL_REG(
   input         clk, reset,
   input [31:0]  PCE,
   input         RegWriteE,
   input [1:0]   ResultSrcE,
   input         MemWriteE,
   input [31:0]  ALUResult,
   input [31:0]  LauiPC,
   input [31:0]  RD2E,
   input [31:0]  InstrE,
   input [4:0]   RdE,
   input [31:0]  PC4E,
   
   output reg [31:0]  PCMW, 
   output reg         RegWriteMW,
   output reg [1:0]   ResultSrcMW,
   output reg         MemWriteMW,
   output reg [31:0]  ALUResultMW,
   output reg [31:0]  LauiPCMW,
   output reg [31:0]  RD2MW,
   output reg [31:0]  InstrMW,
   output reg [4:0]   RdMW,
   output reg [31:0]  PC4MW
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCMW         <= 0;
        RegWriteMW   <= 0;
        ResultSrcMW  <= 0;
        MemWriteMW   <= 0;
        ALUResultMW  <= 0;
        LauiPCMW     <= 0;
        RD2MW  <= 0;
        InstrMW      <= 0;
        RdMW         <= 0;
        PC4MW        <= 0;
    end else begin
        PCMW         <= PCE;
        RegWriteMW   <= RegWriteE;
        ResultSrcMW  <= ResultSrcE;
        MemWriteMW   <= MemWriteE;
        ALUResultMW  <= ALUResult;
        LauiPCMW  <= LauiPC;
        RD2MW  <= RD2E;
        InstrMW      <= InstrE;
        RdMW         <= RdE;
        PC4MW        <= PC4E;
    end
end

endmodule
