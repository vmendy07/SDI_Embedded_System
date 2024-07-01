module UART_rx(clk, rst_n, RX, clr_rdy, rx_data, rdy);

input clk, rst_n, RX, clr_rdy;
output logic [7:0] rx_data;
output reg rdy;

logic start, shift, receiving, set_rdy;

reg [8:0] rx_shift_reg;
reg [5:0] baud_cnt;
reg [3:0] bit_cnt;

// 2 reg vars to fix meta-stability in incoming RX signal before adding it to register
reg RX_2, RX_3;

// only 2 states for FSM
typedef enum reg {IDLE, RECEIVE} state_t;
state_t state, nxt_state;

// RX meta-stability FFs //
// preset FFs so we can detect a falling edge when RX_3 is 0
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		RX_2 <= 1;
		RX_3 <= 1;
	end
	else begin
		RX_2 <= RX;
		RX_3 <= RX_2;
	end
end

// rx_shift_reg FF //
// register where the RX data will be shifted into
always_ff @(posedge clk) begin
	if (shift) begin
		rx_shift_reg <= {RX_3, rx_shift_reg[8:1]};
	end
end

// baud_cnt FF //
// counting either full baud (33 in decimal) or half baud (16 in decimal) based off if we're just starting or not
always_ff @(posedge clk) begin
	case ({start|shift, receiving})
		2'b00 :	baud_cnt <= baud_cnt;
		2'b01 : baud_cnt <= baud_cnt - 1;
		default : baud_cnt <= (start ? 6'h10 : 6'h21);
	endcase
end

// bit_cnt FF //
// increment bit_cnt which represents the 
// bit we are on each time we are shifting
always_ff @(posedge clk) begin
	case ({start, shift})
		2'b00 :	bit_cnt <= bit_cnt;
		2'b01 : bit_cnt <= bit_cnt + 1;
		default : bit_cnt <= '0;
	endcase
end

// rdy FF //
// output a 1 when set_rdy is 1
// output a 0 when start or clr_rdy is 1
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		rdy <= 0;
	end
	else if (set_rdy) begin
		rdy <= 1;
	end
	else if (start | clr_rdy) begin
		rdy <= 0;
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
	start = 0;
	receiving = 0;
	set_rdy = 0;
	nxt_state = IDLE;
	// state transitions & ouputs
	case (state)
		// checking if we're on the last shift for the last bit while receiving
		// if true we set set_rdy to 1 so rdy will be asserted next cycle
		RECEIVE : if (bit_cnt == 4'h9 && shift) begin
			set_rdy = 1;
		end
		else begin
			receiving = 1;
			nxt_state = RECEIVE;
		end
		// default case = IDLE //
		// only start receiving once RX signal has a falling edge
		default : if (!RX_3) begin
			start = 1;
			nxt_state = RECEIVE;
		end
	endcase
end

// asserting shirt only when baud_cnt is 0
assign shift = ~|baud_cnt;

//output everything from register but the MSB for rx_data
assign rx_data = rx_shift_reg[7:0];

endmodule