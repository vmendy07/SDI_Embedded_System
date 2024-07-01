module UART_tx(clk, rst_n, TX, trmt, tx_data, tx_done);

input clk, rst_n, trmt;
input [7:0] tx_data;
output logic TX;
output reg tx_done;

logic init, shift, transmitting, set_done;

reg [8:0] tx_shift_reg;
reg [5:0] baud_cnt;
reg [3:0] bit_cnt;

// only 2 states for FSM
typedef enum reg {IDLE, TRANSMIT} state_t;
state_t state, nxt_state;

// tx_shift_register FF //
// starting with a 0 and the end of shift register for start bit
// keep right shifting ones on the right until we are done
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		tx_shift_reg <= '1;
	end
	else begin
		case ({init, shift})
			2'b00 :	tx_shift_reg <= tx_shift_reg;
			2'b01 :	tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
			default :	tx_shift_reg <= {tx_data, 1'b0};
		endcase
	end
end

// baud_cnt FF //
// increment baud_cnt which represents the divider number
// whenever we are transmitting and not shifting or initalizing
always_ff @(posedge clk) begin
	case ({init|shift, transmitting})
		2'b00 :	baud_cnt <= baud_cnt;
		2'b01 : baud_cnt <= baud_cnt + 1;
		default :	baud_cnt <= '0;
	endcase
end

// bit_cnt FF //
// increment bit_cnt (which represents the 
// bit we are on) each time we are shifting
always_ff @(posedge clk) begin
	case ({init, shift})
		2'b00 :	bit_cnt <= bit_cnt;
		2'b01 : bit_cnt <= bit_cnt + 1;
		default :	bit_cnt <= '0;
	endcase
end

// tx_done FF //
// set tx_done to 1 when set_done is high
// or set tx_done to 0 when init is high
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		tx_done <= 0;
	end
	else if (init) begin
		tx_done <= 0;
	end
	else if (set_done) begin
		tx_done <= 1;
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
	init = 0;
	transmitting = 0;
	set_done = 0;
	nxt_state = IDLE;
	// state transitions & ouputs
	case (state)
		// checking if we're on the 34th cycle of the last bit (bit 9) while transmitting
		// if true we set set_done to 1 so tx_done will be asserted next cycle
		TRANSMIT : if (bit_cnt == 4'h9 && shift) begin
			set_done = 1;
		end
		else begin
			transmitting = 1;
			nxt_state = TRANSMIT;
		end
		// default case = IDLE //
		// only start transmitting once trmt is high
		default : if (trmt) begin
			init = 1;
			nxt_state = TRANSMIT;
		end
	endcase
end

// asserting shirt when we reached 34 cycles by checking if the baud_cnt is 33
assign shift = baud_cnt[5] & baud_cnt[0];

// outputting end of shift register to TX
assign TX = tx_shift_reg[0];

endmodule
