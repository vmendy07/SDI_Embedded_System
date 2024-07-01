module capture(clk,rst_n,wrt_smpl,run,capture_done,triggered,trig_pos,
               we,waddr,set_capture_done,armed);

  parameter ENTRIES = 384,		// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;			// Log base 2 of number of entries
  
  input clk;					// system clock.
  input rst_n;					// active low asynch reset
  input wrt_smpl;				// from clk_rst_smpl.  Lets us know valid sample ready
  input run;					// signal from cmd_cfg that indicates we are in run mode
  input logic capture_done;			// signal from cmd_cfg register.
  input triggered;				// from trigger unit...we are triggered
  input [LOG2-1:0] trig_pos;	// How many samples after trigger do we capture
  
  output logic we;					// write enable to RAMs
  output reg [LOG2-1:0] waddr;	// write addr to RAMs
  output logic set_capture_done;	// asserted to set bit in cmd_cfg
  output reg armed;				// we have enough samples to accept a trigger

  /// declare needed internal registers
  
  logic init, inc_waddr, inc_trig, clr_arm, armed_sig, look_for_armed; 
  
  logic [LOG2-1:0] trig_cnt, true_trig_pos;
  

  ////////////////////////////////////////////////////////
  ///////////////////STATE MACHINE////////////////////////
  ////////////////////////////////////////////////////////  
  typedef enum logic [1:0] {IDLE, INC, DONE} state_t;
  
  state_t state, nxt_state;


  always_ff @(posedge clk) begin 
	if(!rst_n) 
		state <= IDLE;
	else
		state <= nxt_state;
  end
    
  
  always_comb begin 
	//default outputs
	init = 1'b0;
	inc_waddr = 1'b0;
	inc_trig = 1'b0; 
	we = 1'b0;
	set_capture_done = 1'b0;
	clr_arm = 1'b0;
	look_for_armed = 1'b0;
	nxt_state = state;
  
	case (state) 
		INC : begin 			//INC state, increments waddr and trig_cnt when wrt_smpl goes high
			if (triggered && (trig_cnt == true_trig_pos)) begin
				set_capture_done = 1'b1;
				clr_arm = 1'b1;
				nxt_state = DONE;
			end
			else if (wrt_smpl) begin
				we = 1'b1; 
				inc_waddr = 1'b1;
				inc_trig = triggered;
				look_for_armed = 1'b1;
			end
		end
		DONE: begin				//DONE state, signifies that the SDRAM has been looped through
			if(!capture_done) begin 
				nxt_state = IDLE;
			end
		end
		IDLE: begin 			//IDLE state, Wait here until run is asserted
			if(run) begin 
				init = 1'b1;
				nxt_state = INC;
			end
		end
		default: begin 			//If in unused state then go to IDLE 
			nxt_state = IDLE;
		end
	endcase
  
  
  
  end

/////////////////////////////////////////////////////
//          Flop Flop to infer init
////////////////////////////////////////////////////

// This block infers resets of the flops initalize signal and the incrementing of waddr once in the incrment state
  always_ff @(posedge clk) begin
    if (init) 
      waddr <= '0;
    else if (inc_waddr)
      waddr <= (waddr == ENTRIES-1) ? 0 : waddr + 1'b1;
  end

// This block infers resets of the flops initalize signal and the incrementing of trig_cnt once in the incrment state
  always_ff @(posedge clk) begin
	if(init) 
		trig_cnt <= '0;
	else if (inc_trig)
      trig_cnt <= trig_cnt + 1'b1;
  end
  
	

/////////////////////////////////////////////////////
//          Flop Flop to infer armed conditions
////////////////////////////////////////////////////

  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
      armed <= 1'b0; 
    else if (armed_sig)
      armed <= 1'b1;
    else if (clr_arm)
      armed <= 1'b0;  
  end
  
  
  //Once this conditional has been acheived then assign armed
  assign armed_sig = ((waddr + true_trig_pos) == (ENTRIES - 1)) && look_for_armed; 
  
  
  //combination logic to snip trig_pos if greater than ENTRIES - 1   
  assign true_trig_pos = (trig_pos > ENTRIES - 1) ? ENTRIES - 1 : trig_pos;
  
endmodule
