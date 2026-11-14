//MAC is the heart of the accelerator
// We already know how the neuron computes. The mac does that one product per clock.

`default_nettype none // Esto es necesario?


module mac (
	input logic clk,
	input logic rst_n, // Active low
	input logic load, // Bias
	input logic en, 
	input logic signed [31:0] bias,
	input logic signed [7:0] x,
	input logic signed [7:0] w,
	output logic signed [31:0] acc
);

	logic signed [15:0] product;
	assign product = x * w;
	
	always_ff @(posedge clk or negedge rst_n)
	begin
		if (!rst_n)    	acc <= '0;
		else if (load) 	acc <= bias;
		else if (en)   	acc <= acc + product;
	end 




endmodule

`default_nettype wire