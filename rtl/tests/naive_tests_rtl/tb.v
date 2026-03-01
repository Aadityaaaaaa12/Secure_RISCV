module tb;

reg clk;
reg reset;
reg Ext_MemWrite;
reg [31:0] Ext_WriteData, Ext_DataAdr;

wire [31:0] WriteData, DataAdr, ReadData;
wire MemWrite;
wire [31:0] PC, Result;

FT_IO_RISCV uut (
    clk, reset,
    Ext_MemWrite, Ext_WriteData, Ext_DataAdr,
    MemWrite, WriteData, DataAdr, ReadData,
    PC, Result
);

integer cycles = 0;
integer stable_cnt = 0;

reg saw_return_to_0x08;
reg saw_enter_bad_0x30;
reg saw_popchk_bad_0x38;
reg saw_pc_halt;

reg [31:0] pc_prev;

localparam [31:0] PC_MAIN_AFTER_GOOD = 32'h0000_0008;
localparam [31:0] PC_BAD_ENTRY      = 32'h0000_0030;
localparam [31:0] PC_BAD_POPCHK     = 32'h0000_0038;
localparam [31:0] PC_SHOULD_NOT_HIT = 32'h0000_0010;

always begin
    clk <= 1'b1; #5;
    clk <= 1'b0; #5;
end

initial begin
    clk = 1'b0;
    reset = 1'b1;

    Ext_MemWrite = 1'b0;
    Ext_DataAdr = 32'b0;
    Ext_WriteData = 32'b0;

    cycles = 0;
    stable_cnt = 0;

    saw_return_to_0x08 = 1'b0;
    saw_enter_bad_0x30 = 1'b0;
    saw_popchk_bad_0x38 = 1'b0;
    saw_pc_halt = 1'b0;

    pc_prev = 32'hFFFF_FFFF;

    #20;
    reset = 1'b0;
end

always @(negedge clk) begin
    cycles = cycles + 1;

    if (!reset) begin
        if (PC == PC_MAIN_AFTER_GOOD)
            saw_return_to_0x08 <= 1'b1;

        if (PC == PC_BAD_ENTRY)
            saw_enter_bad_0x30 <= 1'b1;

        if (PC == PC_BAD_POPCHK)
            saw_popchk_bad_0x38 <= 1'b1;

        if (PC == PC_SHOULD_NOT_HIT) begin
            $display("FAIL: PC reached 0x10 (instruction after bad call). Shadow-stack fault did NOT stop execution.");
            $stop;
        end

        if (PC == pc_prev)
            stable_cnt = stable_cnt + 1;
        else
            stable_cnt = 0;

        pc_prev = PC;

        if (saw_popchk_bad_0x38 && (stable_cnt >= 6))
            saw_pc_halt <= 1'b1;

        if (saw_pc_halt) begin
            $display("PASS: Shadow-stack mismatch caused core to halt (PC stable).");
            $display("  saw_return_to_0x08   = %0d", saw_return_to_0x08);
            $display("  saw_enter_bad_0x30   = %0d", saw_enter_bad_0x30);
            $display("  saw_popchk_bad_0x38  = %0d", saw_popchk_bad_0x38);
            $display("  final PC             = 0x%08h", PC);
            $stop;
        end

        if (cycles > 500) begin
            $display("FAIL: Timeout. States:");
            $display("  saw_return_to_0x08   = %0d", saw_return_to_0x08);
            $display("  saw_enter_bad_0x30   = %0d", saw_enter_bad_0x30);
            $display("  saw_popchk_bad_0x38  = %0d", saw_popchk_bad_0x38);
            $display("  stable_cnt           = %0d", stable_cnt);
            $display("  PC                   = 0x%08h", PC);
            $stop;
        end
    end
end

endmodule