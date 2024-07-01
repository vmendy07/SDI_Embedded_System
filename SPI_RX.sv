module SPI_RX(clk, rst_n, SS_n, SCLK, MOSI, edg, len8, mask, match, SPItrig);

input clk, rst_n, SS_n, SCLK, MOSI, edg, len8;
input [15:0] mask, match;
output SPItrig;

// create all needed signals for logic & FSM
logic SCLK_ff1, SCLK_ff2, SCLK_ff3, SCLK_rise, SCLK_fall;
logic MOSI_ff1, MOSI_ff2, MOSI_ff3;
logic SS_ff1, SS_ff2;
logic shift, done;
logic [15:0] shift_reg;

logic [15:0] equal_no_mask, mask_with_len8, equal_with_mask;

// flop SCLK signal
always_ff @(posedge clk) begin
	SCLK_ff1 <= SCLK;
	SCLK_ff2 <= SCLK_ff1;
	SCLK_ff3 <= SCLK_ff2;
end

// flop MOSI signal
always_ff @ (posedge clk) begin
	MOSI_ff1 <= MOSI;
	MOSI_ff2 <= MOSI_ff1;
	MOSI_ff3 <= MOSI_ff2;
end

//flop SS_n signal
always_ff @ (posedge clk) begin
	SS_ff1 <= SS_n;
	SS_ff2 <= SS_ff1;
end

//logic to detect a rising and falling edge
assign SCLK_rise = SCLK_ff2 & ~SCLK_ff3;
assign SCLK_fall = ~SCLK_ff2 & SCLK_ff3;

// shift register for MOSI signal
always_ff @(posedge clk) begin
	if (shift) begin
		shift_reg <= {shift_reg[14:0], MOSI_ff3};
	end
end

// FSM implementation //

// FSM states
typedef enum logic {IDLE, RX} state_t;
state_t state, nxt_state;

// transition to next state each clock cycle 
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		state <= IDLE;
	end else begin
		state <= nxt_state;
	end
end

// state machine logic
always_comb begin
	// set default values
	done = 0;
	shift = 0;
	nxt_state = state;
	case (state)
		// when SS_n goes down start sampling MOSI signal 
		IDLE: if (!SS_ff2) begin
			nxt_state = RX;
		end
		// stop sampling MOSI signal when SS_n goes high and assert done
		RX : if (SS_ff2) begin
			done = 1;
			nxt_state = IDLE;
		end 
		// in RX state shift during rising edge of SCLK when edg is 1
		// or shift on falling edge of SCLK when edg is 0
		else begin
			if (edg) begin
				shift = SCLK_rise;
			end else begin
				shift = SCLK_fall;
			end
		end
	endcase
end

// mask, match, len8, & done logic

// check if shift register matches match without mask
assign equal_no_mask = shift_reg ^ match;

// create mask based off whether len8 is enabled or not
assign mask_with_len8 = len8 ?  (16'hFF00 | mask) : mask;

// apply mask to see if data still matches
assign equal_with_mask = (~mask_with_len8) & equal_no_mask;

// only assert SPItrig once done is high & data matches
assign SPItrig = done & (~|equal_with_mask);

endmodule
