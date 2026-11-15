`default_nettype none

module neuron_fsm (
	input wire logic  				clk,
	input wire logic  				rst_n,
	input wire logic  				start,
	input wire logic [4:0]  		n,
	input wire logic [63:0]  		pixels,
	output logic  						done,
	output logic signed [31:0]  	acc
	
);


parameter IDLE = 3'd0, 
          BIAS = 3'd1,
			 RUN = 3'd2,
			 DRAIN1 = 3'd3,
			 DRAIN2 = 3'd4,
			 DONE = 3'd5;


	logic [2:0] state, next_state;
	logic [4:0] neuron; 
	logic [5:0] i;
	logic ask_bias; 
	logic ask_weight;

	always_ff @(posedge clk or negedge rst_n)
	begin: state_assignment
		if(!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end
	
	always_ff @(posedge clk or negedge rst_n)
	begin: save_neuron
		if (!rst_n)
			neuron <= 0;
		else if (state == IDLE && start)
			neuron <= n;
	end
	
	always_ff @(posedge clk or negedge rst_n)
	begin: pixel_counter
		if (!rst_n)
			i <= 0;
		else if (state == RUN)
			i <= i + 1;
		else
			i <= 0;
		end
	
	logic [10:0] w_address;
	logic [7:0] w1_q;
	logic [31:0] b1_q;
	
	assign w_address = neuron * 64 + 1;
	
	b1_rom bias_rom 
	
	
endmodule