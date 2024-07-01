module UART_prot (clk, rst_n, RX, baud_cnt, match, mask, UARTtrig);

input clk, rst_n, RX;
input [15:0] baud_cnt;
input [7:0] match;
input [7:0] mask; //If the bit is a 1 then it is considered a don't care

output UARTtrig;

logic [7:0] rx_data, compare;
logic rdy, clr_rdy;

UART_rx_cfg_baud UART_RX(.RX(RX), .clk(clk), .rst_n(rst_n), 
							.clr_rdy(clr_rdy), .rx_data(rx_data), 
							.rdy(rdy), .baud_cnt(baud_cnt));


//Comparing match and rx_data if all 8 bits are 1's then output matched 
assign compare = ~((match | mask) ^ (rx_data | mask));

//Reduces compare to a single bit telling if there are no zeros, then if rdy is asserted
//then UARTtrig must be triggered
assign UARTtrig = (&compare) & rdy;

//Signal meant to control clr_rdy and assert it one clock cycle after rdy goes high
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		clr_rdy <= 1'b0;
	else if (rdy) 
		clr_rdy <= 1'b1;
	else
		clr_rdy <= 1'b0;
end










endmodule