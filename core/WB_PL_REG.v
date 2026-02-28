

module WB_PL_REG(
    input         clk, reset,
    input [31:0]  PCMW,
    input         RegWriteMW,
    input [1:0]   ResultSrcMW,
    input [31:0]  ALUResultMW,
    input [31:0] LauiPCMW,
    input [31:0]  ReadData,
    input [4:0]   RdMW,
    input [31:0]  PC4MW,
    
    output reg [31:0]  PCWB,
    output reg         RegWriteWB,
    output reg [1:0]   ResultSrcWB,
    output reg [31:0]  ALUResultWB,
    output reg [31:0]  LauiPCWB,
    output reg [31:0]  ReadDataWB,
    output reg [4:0]   RdWB,
    output reg [31:0]  PC4WB
);


always @(posedge clk or posedge reset) begin
    if (reset) begin
        PCWB         <= 0;
        RegWriteWB   <= 0;
        ResultSrcWB  <= 0;
        ALUResultWB  <= 0;
        LauiPCWB     <= 0;
        ReadDataWB   <= 0;
        RdWB         <= 0;
        PC4WB        <= 0;
    end else begin
        PCWB         <= PCMW;
        RegWriteWB   <= RegWriteMW;
        ResultSrcWB  <= ResultSrcMW;
        ALUResultWB  <= ALUResultMW;
        LauiPCWB     <= LauiPCMW;
        ReadDataWB   <= ReadData;
        RdWB         <= RdMW;
        PC4WB        <= PC4MW;
    end
end

endmodule
