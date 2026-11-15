//MAC is the heart of the accelerator
// We already know how the neuron computes. The mac does that one product per clock.

`default_nettype none // Esto es necesario solaente para evitar errores al crear cables. Typo protection


module mac (
	input wire logic clk,
	input wire logic rst_n, // Active low
	input wire logic load, // Bias
	input wire logic en, 
	input wire logic signed [31:0] bias,
	input wire logic signed [7:0] x,
	input wire logic signed [7:0] w,
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


// load wins over en: load starts a new neuron, so a product in that same cycle belongs to the previous one.

endmodule

`default_nettype wire