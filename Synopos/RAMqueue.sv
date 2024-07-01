module RAMqueue(clk, we, waddr, wdata, raddr, rdata);

parameter ENTRIES = 384;
parameter LOG2 = 9;

input [LOG2-1:0] waddr, raddr;
input [7:0] wdata;
input clk, we;
output reg [7:0] rdata;

// synopsys translate_off

reg [7:0] memory [0:ENTRIES-1];



// writing data and reading data based off addresses and if "we" is on during rising edge
always_ff @(posedge clk) begin
	if (we) begin
		memory[waddr] <= wdata;
	end
	rdata <= memory[raddr];
end
// synopsys translate_on

endmodule