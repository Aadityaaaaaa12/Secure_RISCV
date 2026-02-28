// riscv_cpu.v - single-cycle RISC-V CPU Processor

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWriteMW,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] InstrMW,
    output [31:0] Result
);

wire        ALUSrc, RegWrite, Jump, Jalr, Zero, ALUR31;
wire [1:0]  ResultSrc, ImmSrc;
wire [3:0]  ALUControl;
wire        PCSrc;
wire        Branch, MemWrite;
wire [31:0] InstrD;

controller  c   (InstrD[6:0], InstrD[14:12], InstrD[30], Zero, ALUR31,
                ResultSrc, MemWrite, PCSrc, ALUSrc, RegWrite, Jump, Branch, Jalr,
                ImmSrc, ALUControl);

datapath    dp  (clk, reset, ResultSrc, PCSrc,
                ALUSrc, RegWrite, ImmSrc, ALUControl, Jalr, Jump, Branch, MemWrite,
                Zero, ALUR31, PC, Instr, Mem_WrAddr, Mem_WrData, ReadData, InstrD, InstrMW, MemWriteMW, Result);

endmodule