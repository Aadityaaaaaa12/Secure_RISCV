// datapath.v
module datapath (
    input         clk, reset,
    input [1:0]   ResultSrc,
    input         PCSrc, ALUSrc,
    input         RegWrite,
    input [1:0]   ImmSrc,
    input [3:0]   ALUControl,
	 input 			Jalr,Jump,Branch,
	 input        MemWrite,
    output        Zero, ALUR31,
    output [31:0] PC,
    input  [31:0] Instr,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] InstrD,
    output [31:0] InstrMW,
    output        MemWriteMW,
    output [31:0] Result
);

wire [31:0] PCNext, PCJalr, PCPlus4, PCTarget, AuiPC, LauiPC;
wire [31:0] ImmExt, SrcA, SrcB, WriteData, ALUResult;

always @(posedge clk) begin
    $display("------------------------------------------------------------");
    $display("IF:  PC=%h Instr=%h  StallPC_hu=%b StallF_hu=%b ss_fault=%b StallPC_eff=%b StallF_eff=%b",
             PC, Instr, StallPC_hu, StallF_hu, ss_fault, StallPC_eff, StallF_eff);

    $display("PC PATH:");
    $display("  pcmux:  PCPlus4=%h  PCTarget=%h  PCRecall=%h  PCControl=%b  => PCNext=%h",
             PCPlus4, PCTarget, PCRecall, PCControl, PCNext);

    $display("  jalrmux: PCNext=%h  ALUResult(EX)=%h  jalrE=%b  => PCJalr=%h",
             PCNext, ALUResult, jalrE, PCJalr);

    $display("  pcreg:  in=%h  (stall=%b)  => PC=%h",
             PCJalr, StallPC_eff, PC);

    $display("D:   PCD=%h InstrD=%h  RS1D=%0d RS2D=%0d RdD=%0d  FlushD=%b StallD=%b",
             PCD, InstrD, RS1D, RS2D, InstrD[11:7], FlushD, StallD);

    $display("E:   PCE=%h InstrE=%h  RS1E=%0d RS2E=%0d RdE=%0d",
             PCE, InstrE, RS1E, RS2E, RdE);

    $display("E CTRL: JumpE=%b jalrE=%b BranchE=%b TakeBranchE=%b PCSrcE=%b",
             JumpE, jalrE, BranchE, TakeBranchE, PCSrcE);

    $display("E ADDR: ImmExtE=%h  PCTargetE=%h  PCTarget(D)=%h  PCRecall=%h",
             ImmExtE, PCTargetE, PCTarget, PCRecall);

    $display("SS DETECT:");
    $display("  D: is_customD=%b opD=%b f3D=%b f7D=%b rs1_forced=%0d",
             is_customD, InstrD[6:0], InstrD[14:12], InstrD[31:25], rf_rs1_addrD);

    $display("  E: is_customE=%b opE=%b f3E=%b f7E=%b  sspushE=%b  spopchkE=%b  ra_value(RD1E)=%h  ss_fault=%b",
             is_customE, InstrE[6:0], InstrE[14:12], InstrE[31:25],
             is_sspushE, is_sspopchkE, RD1E, ss_fault);

    $display("MW:  PCMW=%h InstrMW=%h RegWriteMW=%b MemWriteMW_raw=%b MemWriteMW=%b ALUResultMW=%h",
             PCMW, InstrMW, RegWriteMW, MemWriteMW_raw, MemWriteMW, ALUResultMW);

    $display("WB:  PCWB=%h RegWriteWB=%b ResultSrcWB=%b ALUResultWB=%h ReadDataWB=%h Result=%h",
             PCWB, RegWriteWB, ResultSrcWB, ALUResultWB, ReadDataWB, Result);
end

//DECODE STAGE WIRES
wire [31:0] PCD,PC4D,ImmExtD,RD1D,RD2D;
wire [4:0] RdD;
wire [4:0] RS1D, RS2D;
wire err_flag_pc4_addr;
wire [1:0] PCControl;
wire StallD;

// Hazard/forwarding control wires (declared early to avoid implicit nets)
wire [1:0] ForwardAE, ForwardBE;
wire StallPC_hu, StallF_hu;
wire StallPC, StallF, FlushD, FlushF;

//EXECUTE STAGE WIRES 
wire [31:0] PCE,PC4E,ImmExtE,RD1E,RD2E,RD2EF,SrcBE,PCTargetE,InstrE,PCRecall;

// Shadow stack custom instruction detection (CUSTOM-0 opcode 0x0B)
wire is_customD   = (InstrD[6:0] == 7'b0001011) && (InstrD[14:12] == 3'b000);
wire is_customE   = (InstrE[6:0] == 7'b0001011) && (InstrE[14:12] == 3'b000);
wire is_sspushE   = is_customE && (InstrE[31:25] == 7'b0000001);
wire is_sspopchkE = is_customE && (InstrE[31:25] == 7'b0000010);

// Force regfile read port 1 to x1 for shadow stack ops (so RD1* carries RA)
wire [4:0] rf_rs1_addrD = is_customD ? 5'd1 : InstrD[19:15];
wire [4:0] rf_rs2_addrD = is_customD ? 5'd0 : InstrD[24:20];

wire [4:0] RdE,RS1E,RS2E;
wire RegWriteE;
wire [1:0]   ResultSrcE;
wire [3:0]   ALUControlE;
wire BranchTest;
reg BranchTestT;
wire ALUSrcE;
wire [2:0] funct3;
wire [6:0] op;
wire [1:0]PCSrcE;
wire JumpE,jalrE;
wire err_flag_alu,err_flag_pcT_addr;

//memory write stage wires
wire         RegWriteMW;
wire [1:0]   ResultSrcMW;
wire         MemWriteMW_raw;
wire [31:0]  ALUResultMW,PCMW;
wire [31:0]  LauiPCMW;
wire [31:0]  RD2MW;
wire [4:0]   RdMW;
wire [31:0]  PC4MW;

wire [31:0] ResultMW_fwd;
assign ResultMW_fwd =
    (ResultSrcMW == 2'b00) ? ALUResultMW :
    (ResultSrcMW == 2'b01) ? ReadData :
    (ResultSrcMW == 2'b10) ? PC4MW :
                             LauiPCMW;

//WRITE BACK STAGE WIRES
wire [1:0]   ResultSrcWB;
wire [31:0]  ALUResultWB;
wire [31:0]  ReadDataWB;
wire [4:0]   RdWB;
wire [31:0]  PC4WB,LauiPCWB,PCWB;



// next PC logic
mux3 #(32)     pcmux(PCPlus4, PCTarget,PCRecall, PCControl, PCNext);
mux2 #(32)		jalrmux(PCNext, ALUResult, jalrE, PCJalr);
adder          pcadd4(PC, 32'd4, PCPlus4);

// Shadow stack fault handling: stop fetching/committing on fault
wire ss_fault;
wire StallPC_eff = StallPC_hu | ss_fault;
wire StallF_eff  = StallF_hu  | ss_fault;

reset_ff #(32) pcreg(clk, reset,StallPC_eff, PCJalr, PC);

IF_PL_REG IF_reg (
    .clk(clk),
    .reset(reset),
    .Instr(Instr),
    .PC_in(PC),
    .PC4_in(PCPlus4),
    .Stall(StallF_eff), 
    .Flush(FlushF),
    .InstrF(InstrD),
    .PCF(PCD),
    .PC4_out(PC4D)
);

assign RS1D = rf_rs1_addrD;
assign RS2D = rf_rs2_addrD;

reg_file       rf (clk, RegWriteWB, rf_rs1_addrD, rf_rs2_addrD, RdWB, Result, RD1D, RD2D);
imm_extend     ext (InstrD[31:7], ImmSrc, ImmExt);
adder          pcaddbranch(PCD, ImmExt, PCTarget);

DE_PL_REG DE_reg(
    .clk(clk),
    .reset(reset),
    .Flush(FlushD), 
    .ResultSrcD(ResultSrc),
    .ALUSrcD(ALUSrc),
    .RegWriteD(RegWrite),
    .ALUControlD(ALUControl),
    .MemWriteD(MemWrite),
    .RD1D(RD1D),
    .RD2D(RD2D),
    .PCD(PCD),
    .PCTargetD(PCTarget),
    .RdD(InstrD[11:7]),
    .RS1D(RS1D),
    .RS2D(RS2D),
    .ImmExtD(ImmExt),
    .InstrD(InstrD),
    .PC4D(PC4D),
    .Jump(Jump),
    .Branch(Branch),
    .jalr(Jalr),
    .RegWriteE(RegWriteE),
    .ResultSrcE(ResultSrcE),
    .MemWriteE(MemWriteE),
    .ALUControlE(ALUControlE),
    .ALUSrcE(ALUSrcE),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .PCTargetE(PCTargetE),
    .RdE(RdE),
    .RS1E(RS1E),
    .RS2E(RS2E),
    .ImmExtE(ImmExtE),
    .InstrE(InstrE),
    .PC4E(PC4E),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .jalrE(jalrE)
);

//FORWARDING ALU LOGIC
mux3 #(32) SrcAForward(RD1E, Result, ResultMW_fwd, ForwardAE, SrcA);
mux3 #(32) SrcBForward(RD2E, Result, ResultMW_fwd, ForwardBE, RD2EF);

// ALU logic
mux2 #(32)     srcbmux(RD2EF, ImmExtE, ALUSrcE, SrcB);
alu            alu (SrcA, SrcB, ALUControlE, ALUResult, Zero,err_flag_alu);
adder #(32)		auipcadder({InstrE[31:12],12'b0}, PCE, AuiPC);
mux2 #(32)		LauiPCmux(AuiPC, {InstrE[31:12], 12'b0}, InstrE[5], LauiPC);

assign ALUR31 = ALUResult[31];

reg TakeBranchE;

always @(*) begin
    case (InstrE[14:12]) 
        3'b000: TakeBranchE = Zero;       // beq
        3'b001: TakeBranchE = !Zero;      // bne
        3'b100: TakeBranchE = ALUR31;     // blt
        3'b101: TakeBranchE = !ALUR31;    // bge
        3'b110: TakeBranchE = ALUR31;     // bltu
        3'b111: TakeBranchE = !ALUR31;    // bgeu
        default: TakeBranchE = 0;
    endcase
end

// PCSrcE = 2'b00 by default, 2'b01 when redirect is needed
assign PCSrcE = ((TakeBranchE & BranchE) | JumpE | jalrE) ? 2'b01 : 2'b00;

wire [31:0] ra_value_fwdE;
mux3 #(32) RAForward(RD1E, Result, ResultMW_fwd, ForwardAE, ra_value_fwdE);

// Shadow stack module (internal, not accessible via normal lw/sw)
shadow_stack #(.DEPTH(256)) u_shadow_stack (
    .clk(clk),
    .reset(reset),
    .push_en(is_sspushE),
    .popchk_en(is_sspopchkE),
    .ra_value(ra_value_fwdE),
    .fault(ss_fault)
);

MW_PL_REG MW(clk,reset,PCE,RegWriteE,ResultSrcE,MemWriteE,ALUResult,LauiPC,RD2E,InstrE,RdE,PC4E,PCMW,RegWriteMW,ResultSrcMW,MemWriteMW_raw,ALUResultMW,LauiPCMW,RD2MW,InstrMW,RdMW,PC4MW);

assign MemWriteMW = MemWriteMW_raw & ~ss_fault;
assign Mem_WrData = RD2MW;
assign Mem_WrAddr = ALUResultMW;

WB_PL_REG WB(clk,reset,PCMW,RegWriteMW,ResultSrcMW,ALUResultMW,LauiPCMW,ReadData,RdMW,PC4MW,PCWB,RegWriteWB,ResultSrcWB,ALUResultWB,LauiPCWB,ReadDataWB,RdWB,PC4WB);

//result mux
mux4 #(32)     resultmux(ALUResultWB, ReadDataWB, PC4WB, LauiPCWB, ResultSrcWB, Result);

// HAZARD UNIT CALL AND DECLARATIONS
HAZARD_UNIT HU(
    RS1D, RS2D, RS1E, RS2E, RdD, RdE, RdMW, RdWB,
    RegWriteMW, RegWriteWB, ResultSrcE,
    PCSrcE, Branch, Jump, Jalr, BranchE, TakeBranchE, jalrE,
    PC4D, clk, PCRecall,
    ForwardAE, ForwardBE,
    StallPC_hu, StallF_hu, StallD, FlushF, FlushD, PCControl
);

assign StallPC = StallPC_eff;
assign StallF  = StallF_eff;

//HAZARD UNIT END


endmodule