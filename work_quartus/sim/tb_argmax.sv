//Testbench de argmax
`timescale 1ns/1ps
`default_nettype none

module tb_argmax;
	import nn_params_pkg::*;
	
	logic signed [31:0] acc2;
	logic valid;
	logic clk;
	logic reset_L;
	logic start;
	logic [3:0] digit;
	logic valid_out;
	
	int pass_count = 0;
	int fail_count = 0;
	
	argmax dut (
		.acc2(acc2), 
		.valid(valid), 
		.clk(clk),
		.reset_L(reset_L),
		.start(start),
		.digit(digit),
		.valid_out(valid_out)
	);
	
	initial begin
		clk = 1'b0;
		forever #10ns clk = ~clk;
	end
	
	initial begin
		acc2 = 0;
		valid = 0;
		start = 0;
		reset_L = 1;
		
		repeat (10) @(posedge clk);
		reset_L = 0;
		repeat (2)  @(posedge clk);
		reset_L = 1;
		repeat (10) @(posedge clk);
		
		if (valid_out === 0)
			pass_count = pass_count + 1;
		else 
			fail_count = fail_count + 1;
			
		$display("There were %d fails and %d tests passed", fail_count, pass_count);
	end
	
endmodule