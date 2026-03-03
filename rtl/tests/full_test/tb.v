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

reg saw_enter_main;
reg saw_call_good;
reg saw_call_bad;
reg saw_bad_popchk;
reg saw_pc_halt;

reg [31:0] pc_prev;

localparam [31:0] PC_START        = 32'h0000_0000;  // _start
localparam [31:0] PC_MAIN         = 32'h0000_00D4;  // main entry (from objdump)
localparam [31:0] PC_GOOD_FUNC    = 32'h0000_0010;  // good_func entry
localparam [31:0] PC_BAD_FUNC     = 32'h0000_0084;  // bad_func entry
localparam [31:0] PC_BAD_POPCHK   = 32'h0000_00C0;  // 0400000b inside bad_func
localparam [31:0] PC_SHOULD_NOT_HIT = 32'h0000_0000; // optional; kept for structure

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

    saw_enter_main  = 1'b0;
    saw_call_good   = 1'b0;
    saw_call_bad    = 1'b0;
    saw_bad_popchk  = 1'b0;
    saw_pc_halt     = 1'b0;

    pc_prev = 32'hFFFF_FFFF;

    #20;
    reset = 1'b0;
end

always @(negedge clk) begin
    cycles = cycles + 1;

    if (!reset) begin
        if (PC == PC_MAIN)
            saw_enter_main <= 1'b1;

        if (PC == PC_GOOD_FUNC)
            saw_call_good <= 1'b1;

        if (PC == PC_BAD_FUNC)
            saw_call_bad <= 1'b1;

        if (PC == PC_BAD_POPCHK)
            saw_bad_popchk <= 1'b1;

        // detect halt by PC stability after the bad popchk point is reached
        if (PC == pc_prev)
            stable_cnt = stable_cnt + 1;
        else
            stable_cnt = 0;

        pc_prev = PC;

        if (saw_bad_popchk && (stable_cnt >= 8))
            saw_pc_halt <= 1'b1;

        // PASS condition: we reached bad popchk and then PC stopped changing
        if (saw_pc_halt) begin
            $display("PASS: Shadow-stack mismatch caused core to halt (PC stable).");
            $display("  saw_enter_main = %0d", saw_enter_main);
            $display("  saw_call_good  = %0d", saw_call_good);
            $display("  saw_call_bad   = %0d", saw_call_bad);
            $display("  saw_bad_popchk = %0d", saw_bad_popchk);
            $display("  final PC       = 0x%08h", PC);
            $stop;
        end

        // FAIL condition: no halt after some time
        if (cycles > 2000) begin
            $display("FAIL: Timeout (no halt observed). States:");
            $display("  saw_enter_main = %0d", saw_enter_main);
            $display("  saw_call_good  = %0d", saw_call_good);
            $display("  saw_call_bad   = %0d", saw_call_bad);
            $display("  saw_bad_popchk = %0d", saw_bad_popchk);
            $display("  stable_cnt     = %0d", stable_cnt);
            $display("  PC             = 0x%08h", PC);
            $stop;
        end
    end
end

endmodule