


module FT_IO_RISCV (
    input         clk, reset,
    input         Ext_MemWrite,
    input  [31:0] Ext_WriteData, Ext_DataAdr,
    output        MemWrite,
    output [31:0] WriteData, DataAdr, ReadData,
    output [31:0] PC, Result
);

wire [31:0] Instr,InstrMW;
wire [31:0] DataAdr_rv32, WriteData_rv32;
wire        MemWrite_rv32;

riscv_cpu rvcpu    (clk, reset, PC, Instr,
                    MemWrite_rv32, DataAdr_rv32,
                    WriteData_rv32, ReadData,InstrMW, Result);
instr_mem instrmem (PC, Instr);
data_mem  datamem  (clk, MemWrite, InstrMW[14:12], DataAdr, WriteData, ReadData);

assign MemWrite  = (Ext_MemWrite && reset) ? 1 : MemWrite_rv32;
assign WriteData = (Ext_MemWrite && reset) ? Ext_WriteData : WriteData_rv32;
assign DataAdr   = reset ? Ext_DataAdr : DataAdr_rv32;

endmodule

