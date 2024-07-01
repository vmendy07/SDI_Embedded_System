module UART_wrapper(clk, rst_n, RX, cmd_rdy, clr_cmd_rdy, cmd, send_resp, resp, resp_sent, TX);

input clk, rst_n, RX, clr_cmd_rdy, send_resp;
input [7:0] resp;

output logic cmd_rdy, resp_sent, TX;
output logic [15:0] cmd;

logic rx_rdy, clr_rdy, upper, set_cmd_rdy;
logic [7:0] rx_data, upper_byte;

// Instantiate 8-bit UART
UART iUART (.clk(clk), .rst_n(rst_n), .RX(RX), .rx_rdy(rx_rdy), .rx_data(rx_data), .clr_rx_rdy(clr_rdy), 
				.trmt(send_resp), .tx_data(resp), .tx_done(resp_sent), .TX(TX));

// FSM states
typedef enum logic {UPPER, LOWER} state_t;
state_t state, nxt_state;

// Flip Flop to hold upper byte of 16-bit command
always_ff @(posedge clk) begin
	if (upper) begin
		upper_byte <= rx_data;
	end
end

// FSM Implementation //

// transition to next state each clock cycle 
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		state <= UPPER;
	end
	else begin
		state <= nxt_state;
	end
end

// state machine logic
always_comb begin
	// default outputs
	upper = 0;
	clr_rdy = 0;
	set_cmd_rdy = 0;
	nxt_state = state;
	// state transitions & ouputs
	case (state)
		// LOWER state when lower bits are being sent and once done asserts set_cmd_rdy
		LOWER : if (rx_rdy) begin
			clr_rdy = 1;
			set_cmd_rdy = 1;
			nxt_state = UPPER;
		end
		// UPPER as default state where we are receving the uppper bits of command
		default : if (rx_rdy) begin
			upper = 1;
			clr_rdy = 1;
			nxt_state = LOWER;
		end
	endcase
end

// FF that asserts and deasserts cmd_rdy
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		cmd_rdy <= 0;
	end
	else if (set_cmd_rdy) begin
		cmd_rdy <= 1;
	end
	else if (clr_cmd_rdy) begin
		cmd_rdy <= 0;
	end
end

//combine upper & lower bytes into cmd output
assign cmd = {upper_byte, rx_data};

endmodule
