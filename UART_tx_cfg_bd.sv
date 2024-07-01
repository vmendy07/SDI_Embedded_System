module UART_tx_cfg_bd (clk, rst_n, trmt, TX, tx_data, tx_done, baud);

input clk, rst_n, trmt;
input [7:0] tx_data;
input [15:0] baud; 
output reg tx_done;
output TX;


logic init, set_done, transmitting, shift, init_or_shift;
logic [8:0] tx_shift_reg;
logic [15:0] baud_inc;
logic [3:0] bit_cnt; 

 
/* FLIP_FLOPS
*---------------------------------------------------------------------
*/

//9 bit shift register for transmitting UART data
//Register initalizes the data by shifting tx_data left and adding a 0 to the LSB
//Register then shifts out data based on the baud timer. The LSB is TX
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)  
		tx_shift_reg <= '1;
	else if(init) 
		tx_shift_reg <= {tx_data ,1'b0};
	else if(shift) 
		tx_shift_reg <= {1'b1, tx_shift_reg[8:1]};
end

assign init_or_shift = init | shift;


//6 bit baud timer register
//counts up from zero to 32 to determine baud rate
always_ff @(posedge clk) begin
	if(init_or_shift)
		baud_inc <= '0;
	else if(transmitting)
		baud_inc <= baud_inc + 1;
end
assign shift = baud_inc == baud; //Has counter reached 32. 

//4-bit bit timer register
//Counters up from 0 to 9 in order to determine if a full byte has been transmitted
always_ff @(posedge clk) begin
	if(init)
		bit_cnt <= '0;
	else if(shift)
		bit_cnt <= bit_cnt + 1;
end

//FF to determine if a transmit has been completed 
//If set_done is true then it has been completed and stays up 
//until another transmition is initalized. 
always_ff @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		tx_done <= 1'b0;
	else if(init)
		tx_done <= 1'b0;
	else if(set_done)
		tx_done <= 1'b1;
end


/*
	State Machine 
	
------------------------------------------------------------------
	
	IDLE: Waiting to transmit an UART Byte
	
	TRANSMIT: Currently transmitting a UART Byte
*/

typedef enum logic {IDLE, TRANSMIT} state_t;

state_t state, nxt_State;


//State Machine Flip Flops
//Determines state of machine
always_ff @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_State;
end  

//State Machine

always_comb begin
//Default output
	init = 0; 
	transmitting = 0;
	set_done = 0;
	nxt_State = state;
	
case (state)
	TRANSMIT: begin
		transmitting = 1'b1;
		if (bit_cnt == 4'hA) begin //If 10 has been reached then full message has been sent. 
		set_done = 1'b1; //Message has been completed signal
		nxt_State = IDLE;
		end
	end
	
	default : begin //IDLE
		if(trmt) begin //Begin transmition
			init = 1'b1;
			nxt_State = TRANSMIT;
		end
	end
endcase
end

assign TX = tx_shift_reg[0]; //Setting TX output


endmodule
