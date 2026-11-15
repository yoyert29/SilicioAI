// THIS IS NOT FINISHED YET 


`default_nettype none
module argmax(
	input wire logic signed [31:0] acc2,
	input wire logic valid,
	input wire logic clk,
	input wire logic reset_L,
	input wire logic start,
	output logic [3:0] digit,
	output logic valid_out
);

// States for FSM

typedef enum logic [1:0] {
	idle,
	counting,
	done
} statetype;

statetype current_state, next_state;

logic signed [31:0] acc2_buffer [10];
logic signed [31:0] next_acc2_buffer [10];

logic [3:0] counter;
logic [3:0] next_counter;

logic [3:0] digit_max;
logic [3:0] next_digit_max;

logic signed [31:0] acc2_max;
logic signed [31:0] next_acc2_max;



always_ff @(posedge clk, negedge reset_L) begin
	if (reset_L == 0) begin
		counter <= 4'd0;
		current_state <= idle;
		digit_max <= 0;
		acc2_max <= 32'h8000_0000;
		
		for(int i = 0; i <= 9; i++) 
			acc2_buffer[i] <= 0;
		
	end else begin
		counter <= next_counter;
		current_state <= next_state;
		digit_max <= next_digit_max;
		acc2_max <= next_acc2_max;
		acc2_buffer <= next_acc2_buffer;	
	end
end

always_comb begin
	next_counter = counter;
	next_state = current_state;
	next_digit_max = digit_max;
	next_acc2_buffer = acc2_buffer;
	next_acc2_max = acc2_max;
	
	case(current_state)
		idle: begin		
			if (start == 1)
				next_state = counting;
				
		end
		
		counting: begin
			if (valid == 1) begin
				if (acc2 > acc2_max) begin
					next_acc2_max = acc2;
					next_digit_max = counter;
				end
						
				next_acc2_buffer[counter] = acc2;
				next_counter = counter + 1; 
				
					
				if (counter == 9)
					next_state = done;	
			end
		end
		
		done: begin
			
		end
	endcase
	
end

assign digit = digit_max;
assign valid_out = (current_state == done);

endmodule

