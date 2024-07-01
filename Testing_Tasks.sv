package Testing_Tasks;


//Local Parameters 
localparam posACK = 8'hA5;
localparam CH1_Posedge = 16'h4110;
localparam CH4_Negedge = 16'h4408;
localparam CH5_High_trig = 16'h4504;
localparam CH3_Low_trig = 16'h4302;
localparam set_run_norm = 16'h4013;
localparam set_run_SPI = 16'h4011;
localparam set_run_UART = 16'h4012;
localparam read_TRIG_CFG = 16'h0000;
localparam capture_done_mask = 8'h20;
localparam CH1_dump = 16'h8100;
localparam CH2_dump = 16'h8200;
localparam CH3_dump = 16'h8300;
localparam CH4_dump = 16'h8400;
localparam CH5_dump = 16'h8500;
localparam CH1_default = 16'h4101;
localparam CH3_default = 16'h4301;
localparam CH4_default = 16'h4401;
localparam CH5_default = 16'h4501;
localparam reset_TRIG_CFG = 16'h4003;
localparam reset_maskL = 16'h4C00;

//test 2 & 5 variables
localparam UART_BAUD_HIGH = 16'h4D00;
localparam UART_BAUD_LOW = 16'h4E6C;
localparam UART_MATCH = 16'h4A96;
localparam UART_MATCH_2 = 16'h4A95;
localparam UART_MASK = 16'h4C03;
localparam DECIMATOR_FOUR = 16'h4602;
localparam DECIMATOR_TWO = 16'h4601;
localparam PROT_TRIG_POS = 16'h5030;
localparam SPI_matchL = 16'h4ACD; 
localparam SPI_matchH = 16'h49AB;

// test 3 variables
localparam DECIMATOR_EIGHT = 16'h4603;
localparam reset_DECIMATOR = 16'h4600;

 //Initalize 
 task automatic Initialize(ref send_cmd, ref REF_CLK, ref RST_n, ref clr_resp_rdy, ref [15:0]host_cmd);
	begin 
		send_cmd = 0;
		REF_CLK = 0;
		RST_n = 0;			// assert reset
		clr_resp_rdy = 0;
		host_cmd = '0;
		
		
		repeat (2) @(posedge REF_CLK);
		@(negedge REF_CLK);				// on negedge REF_CLK after a few REF clocks
		RST_n = 1;						// deasert reset
		@(negedge REF_CLK);
	end
  endtask
  
  //task that send command and waits for command to be sent
  //DOESN'T WAIT FOR RESPONSE
  task automatic Send_cmd(ref send_cmd, ref cmd_sent, ref clk, ref [15:0]host_cmd, input [15:0]input_cmd);
	begin 
		host_cmd = input_cmd; 
		@(posedge clk);
		send_cmd = 1;
		@(posedge clk);
		send_cmd = 0;
		//////////////////////////////////////
		// Now wait for command to be sent //
		////////////////////////////////////
		@(posedge cmd_sent);
		@(posedge clk);
	end
  endtask

  //Task for checking if cmd has been posACKed
  //automatically resets response rdy signal
  task automatic check_for_posACK(ref clk, ref clr_resp_rdy, ref resp_rdy, ref [7:0]resp);
	begin 
		@(posedge resp_rdy); //Wating for the response to be ready
		
		//Verifying if resp == posACK
		if(resp !== posACK) begin 
			$display("ERROR: posACK not recived. resp: %h", resp);
			$stop;
		end
		
		clear_resp_rdy(clk, clr_resp_rdy);
	end
  endtask
  
  //Task to clear_resp_rdy (Annoying as hell to do manually)
  task automatic clear_resp_rdy (ref clk, ref clr_resp_rdy);
	begin 
		//resetting resp_rdy
		clr_resp_rdy = 1;
		@(posedge clk);
		clr_resp_rdy = 0;
	end
  endtask
  
  //Task for polling for capture_done
  task automatic wait_for_cap_done(ref send_cmd, ref cmd_sent, ref clk, ref [15:0]host_cmd, input [15:0]input_cmd, 
							ref resp_rdy, ref clr_resp_rdy, ref [7:0]resp);
	begin
		
		logic capture_done_bit = 0;
		integer loop_cnt = 0;
		
		while(!capture_done_bit) begin 
			//Timeout Error testing
			repeat(800) @(posedge clk);
			loop_cnt = loop_cnt + 1;
			if (loop_cnt>200) begin
				$display("ERROR: capture done bit never set");
				$stop();
			end
			
			//Sending command to dump TRIG_CFG
			Send_cmd(send_cmd, cmd_sent, clk, host_cmd, input_cmd);
			
			//waiting for response
			@(posedge resp_rdy);
			
			if(resp & capture_done_mask) begin 
				capture_done_bit = 1;
			end
			
			clear_resp_rdy (clk, clr_resp_rdy);
		end
	end
  endtask
	
  
  //Dumps contents of a specific channel 
  //DOESN'T CLOSE FILES
  task automatic CH_dump(ref send_cmd, ref cmd_sent, ref clk, ref [15:0]host_cmd, input [15:0]input_cmd,
							ref integer fptr, ref resp_rdy, ref clr_resp_rdy, ref [7:0]resp);
	begin
		//Send the dump command
		Send_cmd(send_cmd, cmd_sent, clk, host_cmd, input_cmd);
		
		//dumping to file
		for(integer sample = 0; sample < 384; sample++)
			fork
				begin: timeout1
					repeat(6000) @(posedge clk);
					$display("ERR: Only received %d of 384 bytes on dump",sample);
					$stop();
					sample = 384;		// break out of loop
				end
				begin
					@(posedge resp_rdy);
					disable timeout1;
					$fdisplay(fptr,"%h",resp);	// write to CH1dmp.txt
					clear_resp_rdy(clk, clr_resp_rdy);
					if (sample % 32 === 0)
						$display("At sample %d of dump",sample);
				end
			join
	end
  endtask
  
  //Compares the contents of both files
  //Doesn't close files
  task automatic mem_compare(ref integer fexp, ref integer fptr);
	begin
		integer res;
		integer	exp;
		integer found_res;
		integer found_expected;
		integer mismatches;
		integer sample;
		
		//setup for comparing
		found_res = $fscanf(fptr, "%h", res);
		found_expected = $fscanf(fexp, "%h", exp);
		mismatches = 0; 
		sample = 1;
	
		while (found_expected == 1) 
			begin
				if(res !== exp) 
					begin 
						$display("At sample %d the result of %h does not match expected of %h",sample,res,exp);
						mismatches = mismatches + 1;
						if (mismatches > 100) begin
							$display("ERR: Too many mismatches...stopping test1");
							$stop();
						end
					end	
				sample = sample + 1;
				found_res = $fscanf(fptr,"%h",res);
				found_expected = $fscanf(fexp,"%h",exp);
			end	
	end
  endtask

endpackage
