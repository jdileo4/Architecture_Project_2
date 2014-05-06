// Texas A&M University          //
// cpsc350 Computer Architecture //
// $Id: SingleCycleProc.v,v 1.1 2002/04/08 23:16:14 miket Exp miket $ //

// instruction opcode
//R-Type (Opcode 000000)
`define OPCODE_ADD     6'b000000
`define OPCODE_SUB     6'b000000
`define OPCODE_ADDU    6'b000000
`define OPCODE_SUBU    6'b000000
`define OPCODE_AND     6'b000000
`define OPCODE_OR      6'b000000
`define OPCODE_SLL     6'b000000
`define OPCODE_SRA     6'b000000
`define OPCODE_SRL     6'b000000
`define OPCODE_SLT     6'b000000
`define OPCODE_SLTU    6'b000000
`define OPCODE_XOR     6'b000000
`define OPCODE_JR      6'b000000
//I-Type (All opcodes except 000000, 00001x, and 0100xx)
`define OPCODE_ADDI    6'b001000
`define OPCODE_ADDIU   6'b001001
`define OPCODE_ANDI    6'b001100
`define OPCODE_BEQ     6'b000100
`define OPCODE_BNE     6'b000101
`define OPCODE_BLEZ    6'b000110
`define OPCODE_BLTZ    6'b000001
`define OPCODE_ORI     6'b001101
`define OPCODE_XORI    6'b001110
`define OPCODE_NOP     6'b110110
`define OPCODE_LUI     6'b001111
`define OPCODE_SLTI    6'b001010
`define OPCODE_SLTIU   6'b001011
`define OPCODE_LB      6'b100000
`define OPCODE_LW      6'b100011
`define OPCODE_SB      6'b101000
`define OPCODE_SW      6'b101011
// J-Type (Opcode 00001x)
`define OPCODE_J       6'b000010
`define OPCODE_JAL     6'b000011

// Top Level Architecture Model //

`include "IdealMemory.v"
`include "ProgramCounter.v"
//`include "mux.v"
`include "Control.v"
`include "Register.v"
//`include "imeminit.v"
//`include "signextend.v"
`include "ALU_Control.v"
//`include "imeminit_simple_test.v"


/*-------------------------- CPU -------------------------------
 * This module implements a single-cycle
 * CPU similar to that described in the text book 
 * (for example, see Figure 5.19). 
 *
 */

//
// Input Ports
// -----------
// clock - the system clock (m555 timer).
//
// reset - when asserted by the test module, forces the processor to 
//         perform a "reset" operation.  (note: to reset the processor
//         the reset input must be held asserted across a 
//         negative clock edge).
//   
//         During a reset, the processor loads an externally supplied
//         value into the program counter (see startPC below).
//   
// startPC - during a reset, becomes the new contents of the program counter
//	     (starting address of test program).
// 
// Output Port
// -----------
// dmemOut - contains the data word read out from data memory. This is used
//           by the test module to verify the correctness of program 
//           execution.
//-------------------------------------------------------------------------

module SingleCycleProc(CLK, Reset_L, startPC, dmemOut);
   input 	Reset_L, CLK;
   input [31:0] startPC;
   output [31:0] dmemOut;
   
  	wire [31:0] PC, Instr, readData1, readData2, ALURes, immExtend32, ALU_B_in;
	wire regDst, ALUsrc, Overflow, Carry_out, Zero, regWrite;
	wire [3:0] ALUOp, ALUInstrType;
	
	wire[4:0] writeReg;
	wire  Branch, Jump;
	wire [25:0]jumpadd;
	wire [31:0] signExtImm32;

	assign dmemOut = ALURes;

// 
// INSERT YOUR CPU MODULES HERE
//
//	ProgramCounter progCounter(CLK, Reset_L, startPC[31:0], PC[31:0]);
	ProgramCounter progCounter(CLK, Reset_L, startPC, PC[31:0], Zero,jumpadd, signExtImm32, Branch, Jump);
	InstrMem instrMem(PC[31:0], Instr[31:0]);

	Control control(Instr[31:26], regDst, regWrite, ALUsrc, ALUOp[3:0]);
	MUX5_2to1 writeRegMux(Instr[20:16], Instr[15:11], regDst, writeReg);
	Register register (CLK, Reset_L, Instr[25:21], Instr[20:16], writeReg[4:0], 
						ALURes[31:0], regWrite, readData1[31:0], readData2[31:0]);
	
	SIGN_EXTEND signExtend (Instr[15:0], immExtend32[31:0]);
	MUX32_2to1 ALUargMux (readData2[31:0], immExtend32[31:0], ALUsrc, ALU_B_in[31:0]);
	ALU_Control ALUControl (Instr[5:0], ALUOp[3:0], ALUInstrType[3:0]);
	ALU_behav ALU ( readData1[31:0], ALU_B_in[31:0], ALUInstrType[3:0], ALURes[31:0], Overflow, 1'b0, Carry_out, Zero );
	DataMem  data(ALUResult, CLK, MemRead, MemWr, busB, Mem_DOUT);
	

//
// Debugging threads that you may find helpful (you may have
// to change the variable names).
//
   /*  Monitor changes in the program counter	*/
   always @(PC)
     #10 $display($time,"PC = %d opcode=%d rd=%d rs=%d rt=%d imm16=%d funct=%d result=%h readData1=%d readData2= %d ALU_B_in = %d",
	PC[31:0], Instr[31:26], Instr[25:21],Instr[20:16],Instr[15:11],Instr[15:0],Instr[5:0],ALURes[31:0], readData1[31:0], readData2[31:0], ALU_B_in[31:0]
 );
   

   /*   Monitors memory writes
   always @(MemWrite)
	begin
	#1 $display($time," MemWrite=%b clock=%d addr=%d data=%d", 
	            MemWrite, clock, dmemaddr, rportb);
	end
   */
   
endmodule // CPU


module m555 (CLK);
   parameter StartTime = 0, Ton = 50, Toff = 50, Tcc = Ton+Toff; // 
 
   output CLK;
   reg 	  CLK;
   
   initial begin
      #StartTime CLK = 0;
   end
   
   // The following is correct if clock starts at LOW level at StartTime //
   always begin
      #Toff CLK = ~CLK;
      #Ton CLK = ~CLK;
   end
endmodule

   
module testCPU(Reset_L, startPC, testData);
   input [31:0] testData;
   output 	Reset_L;
   output [31:0] startPC;
   reg 		 Reset_L;
   reg [31:0] 	 startPC;
   
   initial begin
      // Your program 1
      Reset_L = 0;  startPC = 0 * 4;
      #101 // insures reset is asserted across negative clock edge
	  Reset_L = 1; 
      #10000; // allow enough time for program 1 to run to completion
      Reset_L = 0;
      #1 $display ("Program 1: Result: %d", testData);
      
      // Your program 2
      //startPC = 14 * 4;
      //#101 Reset_L = 1; 
      //#10000;
      //Reset_L = 0;

      //#1 $display ("Program 2: Result: %d", testData);
      
      // etc.
      // Run other programs here
      
      
      $finish;
   end
endmodule // testCPU

module TopProcessor;
   wire reset, CLK, Reset_L;
   wire [31:0] startPC;
   wire [31:0] testData;
   
   m555 system_clock(CLK);
   SingleCycleProc SSProc(CLK, Reset_L, startPC, testData);
   testCPU tcpu(Reset_L, startPC, testData); 

endmodule // TopProcessor


