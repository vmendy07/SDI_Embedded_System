module UART_rx_cfg_baud (RX, clk, rst_n, clr_rdy, rx_data, rdy, baud_cnt);

input RX, clr_rdy, clk, rst_n;
input logic [15:0] baud_cnt;
output reg rdy;
output [7:0] rx_data;


logic RX_FF1, RX_Clean, shift, start, start_or_shift, receiving, set_rdy, start_or_clr_rdy;
logic [8:0] rx_shift_reg;
logic [15:0] timer_load, baud_inc;
logic [3:0] bit_cnt;

/*FLIP FLOPS
* ---------------------------------------------------------------------
*/

//RX Meta-stability registers
//Cleaning RX from meta-stability by FF it twice
always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin 
		RX_FF1 <= 1'b1;
		RX_Clean <= 1'b1;
	end
	else begin 
		RX_FF1 <= RX;
		RX_Clean <= RX_FF1;
	end
end

//RX shift-in 9 bit register
//When shift is 1 rx_shift_reg will be shifted right 
//RX will become the MSB
always_ff @(posedge clk) begin
	if(shift)
		rx_shift_reg <= {RX_Clean, rx_shift_reg[8:1]};
end

//Ignore the MSB of rx_shift_reg becasue it is the END bit
assign rx_data = rx_shift_reg[7:0];

//Baud_counter 6 bit register
//Count down timer. First counts down from 16 to start sampling from middle of signal
//Then counts down from 33 for baudrate
always_ff @(posedge clk) begin 
	case({start_or_shift, receiving})
		2'b00 : baud_inc <= baud_inc;
		2'b01 : baud_inc <= baud_inc - 1; 
		default : baud_inc <= timer_load;
	endcase
end

assign start_or_shift = start | shift;

//If starting then load the timer with half the baud count, otherwise baud count
//Subtracting 2 to alight sampling better
assign timer_load = start ? baud_cnt >> 1 : baud_cnt; 

assign shift = ~|baud_inc; //If baud_cnt == 0 then it is time to shift
	
//bit_counter 4 bit register 
//Counts the number of bits currently received
//when reaches 10, message has been received completly
always_ff @(posedge clk) begin 
	case({start, shift})
		2'b00: bit_cnt <= bit_cnt;
		2'b01: bit_cnt <= bit_cnt + 1;
		default: bit_cnt <= '0;
	endcase
end	

//Output rdy register
//outputs rdy when the byte is ready for reading
//rdy goes 1 when set_rdy = 1 and 0 when start or clr_rdy is 1;
always_ff @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		rdy <= 1'b0;
	else if(set_rdy)
		rdy <= 1'b1;
	else if(start_or_clr_rdy)
		rdy <= 1'b0;
end

assign start_or_clr_rdy = start | clr_rdy;



/* STATE MACHINE CODE
* ---------------------------------------------------------
*/
typedef enum logic {IDLE, RECEIVING} state_t;

state_t state, nxt_state; 

//FFs Determines the current state of the machine
always_ff @(posedge clk, negedge rst_n) begin 
	if(!rst_n)
		state <= IDLE; 
	else
		state <= nxt_state;
end


//State Machine combinational logic
always_comb begin 
	//Default Ouputs
	start = 1'b0;
	receiving = 1'b0;
	set_rdy = 1'b0;
	nxt_state = state;

	case (state) 
	
		RECEIVING : begin 
		receiving = 1'b1; 
		if(bit_cnt == 4'hA) begin // 10 Bits have been passed through. Byte has been received. 
			set_rdy = 1'b1; //Byte is ready 
			nxt_state = IDLE; //Wait for to receive next transmission
			end
		end 	
	
		default: begin //IDLE
			if(!RX_Clean) begin //Transmission starts when RX == 0. 
				//Starting transmission
				start = 1'b1; 
				nxt_state = RECEIVING; 
			end
	
		end 

	endcase
end

endmodule
