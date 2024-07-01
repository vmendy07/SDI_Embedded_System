module cmd_cfg(clk,rst_n,resp,send_resp,resp_sent,cmd,cmd_rdy,clr_cmd_rdy,
               set_capture_done,raddr,rdataCH1,rdataCH2,rdataCH3,rdataCH4,
			   rdataCH5,waddr,trig_pos,decimator,maskL,maskH,matchL,matchH,
			   baud_cntL,baud_cntH,TrigCfg,CH1TrigCfg,CH2TrigCfg,CH3TrigCfg,
			   CH4TrigCfg,CH5TrigCfg,VIH,VIL);
			   
  parameter ENTRIES = 384,	// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;		// Log base 2 of number of entries
			
  input clk,rst_n;
  input [15:0] cmd;			// 16-bit command from UART (host) to be executed
  input cmd_rdy;			// indicates command is valid
  input resp_sent;			// indicates transmission of resp[7:0] to host is complete
  input set_capture_done;	// from the capture module (sets capture done bit in TrigCfg)
  input [LOG2-1:0] waddr;		// on a dump raddr is initialized to waddr
  input [7:0] rdataCH1;		// read data from RAMqueues
  input [7:0] rdataCH2,rdataCH3;
  input [7:0] rdataCH4,rdataCH5;
  output logic [7:0] resp;		// data to send to host as response (formed in SM)
  output logic send_resp;				// used to initiate transmission to host (via UART)
  output logic clr_cmd_rdy;			// when finished processing command use this to knock down cmd_rdy
  output logic [LOG2-1:0] raddr;		// read address to RAMqueues (same address to all queues)
  output logic [LOG2-1:0] trig_pos;	// how many sample after trigger to capture
  output reg [3:0] decimator;	// goes to clk_rst_smpl block
  output reg [7:0] maskL,maskH;				// to trigger logic for protocol triggering
  output reg [7:0] matchL,matchH;			// to trigger logic for protocol triggering
  output reg [7:0] baud_cntL,baud_cntH;		// to trigger logic for UART triggering
  output reg [5:0] TrigCfg;					// some bits to trigger logic, others to capture unit
  output reg [4:0] CH1TrigCfg,CH2TrigCfg;	// to channel trigger logic
  output reg [4:0] CH3TrigCfg,CH4TrigCfg;	// to channel trigger logic
  output reg [4:0] CH5TrigCfg;				// to channel trigger logic
  output reg [7:0] VIH,VIL;					// to dual_PWM to set thresholds
  
 
  typedef enum reg[1:0] {IDLE, UART, DUMP, WAIT} state_t;
  
  state_t state,nxt_state;
  
  //// rest is up to you ////
  
// registers for trig_pos high & low and combining registers to return trig_pos 
logic [7:0] trig_posL;
logic [7:0] trig_posH;
assign trig_pos = {trig_posH[LOG2-9:0], trig_posL};
  
// signal to enable write to register if we have a write_reg cmd
logic write_reg;

// signals/registers to keep track of current addr that we are on for a DUMP command
logic set_addr, inc_addr;
logic [LOG2-1:0] addr_ptr;

// Flip Flops for most cmd_cfg registers
always_ff @(posedge clk) begin
	if (!rst_n) begin
		CH1TrigCfg <= 5'h01;
		CH2TrigCfg <= 5'h01;
		CH3TrigCfg <= 5'h01;
		CH4TrigCfg <= 5'h01;
		CH5TrigCfg <= 5'h01;
		decimator <= 4'h0;
		VIH <= 8'hAA;
		VIL <= 8'h55;
		matchH <= 8'h00;
		matchL <= 8'h00;
		maskH <= 8'h00;
		maskL <= 8'h00;
		baud_cntH <= 8'h06;
		baud_cntL <= 8'hC8;
		trig_posH <= 8'h00;
		trig_posL <= 8'h01;
	end
	// write to a register once we recieve WRITE cmd
	else if (write_reg) begin
		case (cmd[13:8])
			8'h01:	CH1TrigCfg <= cmd[4:0];
			8'h02:	CH2TrigCfg <= cmd[4:0];
			8'h03:	CH3TrigCfg <= cmd[4:0];
			8'h04:	CH4TrigCfg <= cmd[4:0];
			8'h05:	CH5TrigCfg <= cmd[4:0];
			8'h06:	decimator <= cmd[3:0];
			8'h07:	VIH <= cmd[7:0];
			8'h08:  VIL <= cmd[7:0];
			8'h09:  matchH <= cmd[7:0];
			8'h0A:  matchL <= cmd[7:0];
			8'h0B:  maskH <= cmd[7:0];
			8'h0C:  maskL <= cmd[7:0];
			8'h0D:  baud_cntH <= cmd[7:0];
			8'h0E:  baud_cntL <= cmd[7:0];
			8'h0F:  trig_posH <= cmd[7:0];
			8'h10:  trig_posL <= cmd[7:0];
		endcase
	end
end

// make extra always block for TrigCfg register
always_ff @(posedge clk) begin
	if (!rst_n) begin
		TrigCfg <= 6'h03;
	end
	else if (write_reg) begin
		if (cmd[13:8] == 8'h00) begin
			TrigCfg <= cmd[5:0];
		end
	end
	else if (set_capture_done) begin
		TrigCfg <= TrigCfg | 6'b100000;
	end
end

// FF for addr_ptr that is essentially a counter that loops back once we reach end of RAMqueue
always_ff @(posedge clk) begin
	if (!rst_n) begin
		addr_ptr <= 0;
	end
	// set addr_ptr to waddr once we recieve DUMP cmd
	else if (set_addr) begin
		addr_ptr <= waddr;
	end
	// inc addr_ptr once we finish UART transmission
	// set it back to zero if we are at max index
	else if (inc_addr) begin
		if (addr_ptr == ENTRIES - 1) begin
			addr_ptr <= 0;
		end
		else begin
			addr_ptr <= addr_ptr + 1;
		end
	end
end
  
// FSM Implementation //
  
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
	write_reg = 0;
	set_addr = 0;
	inc_addr = 0;
	resp = '0;
	send_resp = 0;
	clr_cmd_rdy = 0;
	raddr = '0;
	nxt_state = state;
	case (state)
		// decode command while in IDLE state once cmd is ready
		IDLE: 	if (cmd_rdy) begin
					case (cmd[15:14])
						// checking for a READ cmd
						2'b00: 	begin
									case (cmd[13:8])
										8'h00:	resp = TrigCfg;
										8'h01:	resp = CH1TrigCfg;
										8'h02:	resp = CH2TrigCfg;
										8'h03:	resp = CH3TrigCfg;
										8'h04:	resp = CH4TrigCfg;
										8'h05:	resp = CH5TrigCfg;
										8'h06:	resp = decimator;
										8'h07:	resp = VIH;
										8'h08:  resp = VIL;
										8'h09:  resp = matchH;
										8'h0A:  resp = matchL;
										8'h0B:  resp = maskH;
										8'h0C:  resp = maskL;
										8'h0D:  resp = baud_cntH;
										8'h0E:  resp = baud_cntL;
										8'h0F:  resp = trig_posH;
										8'h10:  resp = trig_posL;
									endcase
									send_resp = 1;
									nxt_state = UART;
								end
						// checking for a WRITE cmd
						2'b01:	begin
									write_reg = 1;
									resp = 8'hA5;
									send_resp = 1;
									nxt_state = UART;
								end
						// checking for a DUMP cmd
						// set raddr to waddr and send responses in WAIT state as we have to wait 
						// for next rising edge for RAMqueue to read data from the updated raddr address
						2'b10:	begin
									raddr = waddr;
									set_addr = 1;
									nxt_state = WAIT;
								end
						// send a neg ack if upper 2 bits don't match a valid cmd
						2'b11:	begin
									resp = 8'hEE;
									send_resp = 1;
									nxt_state = UART;
								end
					endcase
				end
		// wait for resp_sent while in UART state
		// if we are doing a DUMP, go to DUMP state
		// if it's any other command go back to IDLE state & assert clr_cmd_rdy
		UART:	if (resp_sent) begin
					// check if we are finishing UART transmission for a DUMP command
					if (cmd[15:14] == 2'b10) begin
						nxt_state = DUMP;
					end
					// go back to IDLE for all other commands
					else begin
						clr_cmd_rdy = 1;
						nxt_state = IDLE;
					end
				end
		// DUMP state
		// if our addr_ptr has looped back to waddr return to IDLE 
		// if not update raddr to current addr_ptr and go to WAIT
		DUMP:	if (addr_ptr == waddr) begin
					clr_cmd_rdy = 1;
					nxt_state = IDLE;
				end
				else begin
					raddr = addr_ptr;
					nxt_state = WAIT;
				end
		// WAIT state for DUMP command so we can correctly send updated rdata read at raddr
		// increment addr_ptr here so it can be assigned at raddr in DUMP state
		WAIT:	begin
					case (cmd[10:8])
						3'b001:	resp = rdataCH1;
						3'b010:	resp = rdataCH2;
						3'b011:	resp = rdataCH3;
						3'b100:	resp = rdataCH4;
						3'b101:	resp = rdataCH5;
					endcase
					send_resp = 1;
					inc_addr = 1;
					nxt_state = UART;
				end
	endcase
end

endmodule
  
