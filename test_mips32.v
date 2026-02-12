`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.09.2025 23:35:10
// Design Name: 
// Module Name: test_mips32
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Adding 3 Numbers 10,20 and 30 stored in processor register
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_mips32();

reg clk1,clk2;

pipe_MIPS32 mips(clk1,clk2);

initial begin
	clk1=0; clk2=0;
	repeat(20)					//Generating 2-Phase clock
		begin
			#5 clk1=1;	#5clk1=0;
			#5 clk2=1;	#5clk2=0;
		end
end
initial begin
	for(integer k=0;k<31; k=k+1)
		mips.Reg[k]=k;
		
		mips.Mem[0] = 32'h2801000a;		//ADDI	R1,R0,10
		mips.Mem[1] = 32'h28020014;		//ADDI	R2,R0,20
		mips.Mem[2] = 32'h28030019;		//ADDI	R3,R0,25
		mips.Mem[3] = 32'h0ce77800;		//OR	R7,R7,R7
		mips.Mem[4] = 32'h0ce77800;		//OR	R7,R7,R7	--dummy instr
		mips.Mem[5] = 32'h00222000;		//ADD	R4,R1,R2	--dummy instr
		mips.Mem[6] = 32'h0ce77800;		//OR	R7,R7,R7
		mips.Mem[7] = 32'h00832800;		//ADDI	R5,R4,R3	--dummy instr
		mips.Mem[8] = 32'hfc000000;		//HLT
	
		mips.HALTED =0;
		mips.PC =0;
		mips.TAKEN_BRANCH =0;
		
		#280
		for(integer k=0;k<6;k=k+1)
			$display("R%1d - %2d",k,mips.Reg[k]);
	end
initial 
begin
	$dumpfile ("mips.vcd");
	$dumpvars (0,test_mips32);
	#300 $finish;	
 end
endmodule
