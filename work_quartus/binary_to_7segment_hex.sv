`default_nettype none
module binary_to_7segment_hex(
	input 	logic [3:0] binaryBits,
	output 	logic	[6:0] hexCode_L
);

logic [6:0] case_output;

always_comb begin
	case (binaryBits)
		4'b0000: case_output = 7'b1000000;
		4'b0001: case_output = 7'b1111001;
		4'b0010: case_output = 7'b0100100;
		4'b0011: case_output = 7'b0110000;
		4'b0100: case_output = 7'b0011001;
		4'b0101: case_output = 7'b0010010;
		4'b0110: case_output = 7'b0000010;
		4'b0111: case_output = 7'b1111000;
		4'b1000: case_output = 7'b0000000;
		4'b1001: case_output = 7'b0011000;
		4'b1010: case_output = 7'b0001000;
		4'b1011: case_output = 7'b0000011;
		4'b1100: case_output = 7'b1000110;
		4'b1101: case_output = 7'b0100001;
		4'b1110: case_output = 7'b0000110;
		4'b1111: case_output = 7'b0001110;
		default: case_output = 7'b0101010;
	endcase
end

assign hexCode_L = case_output;

endmodule