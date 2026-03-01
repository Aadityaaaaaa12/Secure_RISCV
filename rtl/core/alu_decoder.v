module alu_decoder (
    input            opb5,
    input [2:0]      funct3,
    input            funct7b5,
    input [1:0]      ALUOp,
    output reg [3:0] ALUControl
);

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 4'b0000;             // addition
        2'b01: ALUControl = 4'b0001;             // subtraction
        default:
            case (funct3) // R-type or I-type ALU
                3'b000: begin
                    // True for R-type subtract
                    if (funct7b5 & opb5) ALUControl = 4'b0001; //sub
                    else ALUControl = 4'b0000; // add, addi
                end
                3'b001:  ALUControl = 4'b0111;  // SLL, SLLI
                3'b010:  ALUControl = 4'b0101;  // SLT, SLTI (signed less than)
                3'b011:  ALUControl = 4'b1001;  // SLTU, SLTIU (unsigned less than)
                3'b110:  ALUControl = 4'b0011;  // OR, ORI
                3'b111:  ALUControl = 4'b0010;  // AND, ANDI
                3'b100:  ALUControl = 4'b0100;  // XOR
                3'b101: begin
                    case(funct7b5)
                        1'b0: ALUControl = 4'b0110;  // SRL, SRLI
                        1'b1: ALUControl = 4'b1000;  // SRA, SRAI
                    endcase
                end
                default: ALUControl = 4'b0000;   // undefined
            endcase
    endcase
end

endmodule
    