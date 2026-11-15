// THIS IS NOT FINISHED YET 


`default_nettype none
module argmax(
	input wire logic [31:0] acc2,
	input wire logic valid,
	input wire logic clk,
	input wire logic reset_L,
	output logic [3:0] digit
);

logic signed [31:0] acc2_buffer [10];
logic [3:0] counter = 0;
logic [3'0] next_counter = 0;
logic [3:0] counter_max = 0;
logic signed [31:0] acc2_max;

always_ff @(posedge clk, negedge reset_L, valid) begin
	if (reset_L == 0) begin
		counter <= 4'd0;
		for (int i = 0; i <= 9; i++) begin
			acc2_buffer[i] <= 0;
		end
		
	end else if (valid == 1) begin
		
		acc2_buffer[counter] <= acc2;
		counter <= counter + 1;
end

always_comb @(*) begin
	next_counter <= counter;
	
	
end


