module UART_tb();

logic [7:0] tx_data, rx_data;
logic clk, rst_n, trmt, TX, RX, tx_done, rdy, clr_rdy;

UART_tx UART_tx_DUT (clk, rst_n, TX, trmt, tx_data, tx_done);
UART_rx	UART_rx_DUT	(clk, rst_n, TX, clr_rdy, rx_data, rdy);

initial begin
	clk = 0;
	rst_n = 0;
	trmt = 0;
	tx_data = '0;
	clr_rdy = 0;
	@(posedge clk);
	#1;
	
	// deasserting reset, enabling transmission, and settiing data to a set of random 1's and 0's
	rst_n = 1;
	trmt = 1;
	tx_data = 8'b00101011;
	@(posedge clk)
	#1;
	trmt = 0;
	
	while (!tx_done) begin
		@(posedge clk);
	end
	
	// check if rx_data and tx_data match after 
	if (rx_data !== tx_data) begin
		$display("ERROR: rx_data and tx_data do not match after first transmission!\n");
		$stop();
	end
	
	// check if rdy is still high after transmission
	repeat (5) @(posedge clk);
	#1;
	if (!rdy) begin
		$display("ERROR: rdy signal should have still been high after transmission\n");
		$stop();
	end
	
	//check if clr_rdy clears the rdy signal
	clr_rdy = 1;
	@(posedge clk);
	#1;
	clr_rdy = 0;
	
	if (rdy) begin
		$display("ERROR: rdy signal should have been low after asserting clr_rdy\n");
	end
	
	// send another signal and see if it rx & tx match
	tx_data = 8'b10101010;
	trmt = 1;
	@(posedge clk);
	#1;
	trmt = 0;
	
	while (!tx_done) begin
		@(posedge clk);
	end
	
	if (rx_data !== tx_data) begin
		$display("ERROR: rx_data and tx_data do not match after second transmission!\n");
		$stop();
	end
	$stop();
end

always begin
	#5 clk = ~clk;
end

endmodule


