module ComSender(cmd, send_cmd, cmd_sent, resp, resp_rdy, clr_resp_rdy, clk, rst_n, TX, RX);

input clk, rst_n, send_cmd, RX;
input [15:0] cmd;

//new code for LA
input clr_resp_rdy;

output logic cmd_sent, resp_rdy, TX;
output logic [7:0] resp;

logic tx_done, trmt, sel_high, set_cmd_snt;
logic [7:0] cmd_lower, tx_data;

// FSM states
typedef enum logic [1:0] {IDLE, UPPER, LOWER} state_t;
state_t state, nxt_state;

// instantiate tranceiver
UART iUART (.clk(clk), .rst_n(rst_n), .RX(RX), .rx_rdy(resp_rdy), .rx_data(resp), .clr_rx_rdy(clr_resp_rdy), 
				.trmt(trmt), .tx_data(tx_data), .tx_done(tx_done), .TX(TX));

// cmd FF for lower bits
always_ff @(posedge clk) begin
	if (send_cmd) begin
		cmd_lower <= cmd[7:0];
	end
end

// mux of tx_data signal
assign tx_data = sel_high ? cmd[15:8] : cmd_lower;

//cmd_snt FF
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		cmd_sent <= 0;
	end
	else if (set_cmd_snt) begin
		cmd_sent <= 1;
	end
	else if (send_cmd) begin
		cmd_sent <= 0;
	end
end

// FSM Implementation //

// transition to next state each clock cycle 
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		state <= IDLE;
	end
	else begin
		state <= nxt_state;
	end
end

// state machine logic
always_comb begin
	// default outputs
	trmt = 0;
	sel_high = 0;
	set_cmd_snt = 0;
	nxt_state = state;
	// state transitions & ouputs
	case (state)
		// UPPER state while upper bits are being sent
		UPPER : if (tx_done) begin
			trmt = 1;
			nxt_state = LOWER;
		end
		// LOWER state while lower bits are being sent
		LOWER : if (tx_done) begin
			set_cmd_snt = 1;
			nxt_state = IDLE;
		end
		// IDLE as default state where we are waiting to send bits
		default : if (send_cmd) begin
			trmt = 1;
			sel_high = 1;
			nxt_state = UPPER;
		end
	endcase
end

endmodule
