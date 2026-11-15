`default_nettype none

module requant
import nn_params_pkg::*;
(
	input wire logic signed [31:0] acc,
	output logic [7:0] h_q
);

logic [31:0] h;
		
assign h = (acc > 0)  ? (acc * M1) >>> SHIFT : 0;
assign h_q = (h >= 8'd127) ?  8'd127 : h[7:0];

endmodule