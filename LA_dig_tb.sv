`timescale 1ns / 100ps
module LA_dig_tb();
			
import Testing_Tasks::*; //Importing package for testing tasks
			
//// Interconnects to DUT/support defined as type wire /////
logic clk400MHz,locked;			// PLL output signals to DUT
logic clk;						// 100MHz clock generated at this level from clk400MHz
logic VIH_PWM,VIL_PWM;			// connect to PWM outputs to monitor
logic CH1L,CH1H,CH2L,CH2H,CH3L;	// channel data inputs from AFE model
logic CH3H,CH4L,CH4H,CH5L,CH5H;	// channel data inputs from AFE model
logic RX,TX;						// interface to host
logic cmd_sent,resp_rdy;			// from master UART, monitored in test bench
logic [7:0] resp;				// from master UART, reponse received from DUT
logic tx_prot;					// UART signal for protocol triggering
logic SS_n,SCLK,MOSI;			// SPI signals for SPI protocol triggering
logic CH1L_mux,CH1H_mux;         // output of muxing logic for CH1 to enable testing of protocol triggering
logic CH2L_mux,CH2H_mux;			// output of muxing logic for CH2 to enable testing of protocol triggering
logic CH3L_mux,CH3H_mux;			// output of muxing logic for CH3 to enable testing of protocol triggering

////// Stimulus is declared as type reg ///////
reg REF_CLK, RST_n;
reg [15:0] host_cmd;			// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg clr_resp_rdy;				// asserted to knock down resp_rdy
reg [1:0] clk_div;				// counter used to derive 100MHz clk from clk400MHz
reg strt_tx;					// kick off unit used for protocol triggering
reg en_AFE;
reg capture_done_bit;			// flag used in polling for capture_done
reg [7:0] res, res_spi, res_spi_2, res_spi_3, exp;				// used to store result and expected read from files


wire AFE_clk;

///////////////////////////////////////////
// Channel Dumps can be written to file //
/////////////////////////////////////////
integer fptr1;		// file pointer for CH1 dumps
integer fptr2;
integer fptr3;
integer fexp;		// file pointer to file with expected results
integer fexp_cs;
integer fexp_sclk;
integer fexp_mosi;

// trig pos variables for TESTS 3-5
logic [15:0] TRIG_POSH = 16'h4F00;
logic [15:0] TRIG_POSL = 16'h5060;

// Vars for SPI len8
logic len8;

/////////////////////////////////
// Choose UART or SPI triggering
logic UART_triggering = 1'b0;	// set to true if testing UART based triggering
logic SPI_triggering = 1'b0;	// set to true if testing SPI based triggering

assign AFE_clk = en_AFE & clk400MHz;
///// Instantiate Analog Front End model (provides stimulus to channels) ///////
AFE iAFE(.smpl_clk(AFE_clk),.VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),
         .CH1L(CH1L),.CH1H(CH1H),.CH2L(CH2L),.CH2H(CH2H),.CH3L(CH3L),
         .CH3H(CH3H),.CH4L(CH4L),.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H));
		 
// Here we can determine which channel is used for certain protocol triggering

//// Mux for muxing in protocol triggering for CH1 /////
assign {CH1H_mux,CH1L_mux} = (UART_triggering) ? {2{tx_prot}} :		// assign to output of UART_tx used to test UART triggering
                             (SPI_triggering) ? {2{SS_n}}: 			// assign to output of SPI SS_n if SPI triggering , Surf select signal
				             {CH1H,CH1L}; // otherwise just testing normal front end waveform data from tx file

//// Mux for muxing in protocol triggering for CH2 /////
assign {CH2H_mux,CH2L_mux} = (SPI_triggering) ? {2{SCLK}}: 			// assign to output of SPI SCLK if SPI triggering
				             {CH2H,CH2L};	

//// Mux for muxing in protocol triggering for CH3 /////
assign {CH3H_mux,CH3L_mux} = (SPI_triggering) ? {2{MOSI}}: 			// assign to output of SPI MOSI if SPI triggering
				             {CH3H,CH3L};					  
	 
////// Instantiate DUT ////////		  
LA_dig iDUT(.clk400MHz(clk400MHz),.RST_n(RST_n),.locked(locked),
            .VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),.CH1L(CH1L_mux),.CH1H(CH1H_mux),
			.CH2L(CH2L_mux),.CH2H(CH2H_mux),.CH3L(CH3L_mux),.CH3H(CH3H_mux),.CH4L(CH4L),
			.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H),.RX(RX),.TX(TX));

///// Instantiate PLL to provide 400MHz clk from 50MHz ///////
pll8x iPLL(.ref_clk(REF_CLK),.RST_n(RST_n),.out_clk(clk400MHz),.locked(locked));

///// It is useful to have a 100MHz clock at this level similar //////
///// to main system clock (clk).  So we will create one        //////
always @(posedge clk400MHz, negedge locked)
  if (~locked)
    clk_div <= 2'b00;
  else
    clk_div <= clk_div+1;
assign clk = clk_div[1];

//// Instantiate Master UART (mimics host commands) //////
ComSender iSNDR(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX),
                .cmd(host_cmd), .send_cmd(send_cmd),
		.cmd_sent(cmd_sent), .resp_rdy(resp_rdy),
		.resp(resp), .clr_resp_rdy(clr_resp_rdy));
					 
////////////////////////////////////////////////////////////////
// Instantiate transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////
UART_tx_cfg_bd iTX(.clk(clk), .rst_n(RST_n), .TX(tx_prot), .trmt(strt_tx), // 1 channel
            .tx_data(8'h96), .tx_done(), .baud(16'h006C));	// 921600 Baud
					 
////////////////////////////////////////////////////////////////////
// Instantiate SPI transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////////
SPI_TX iSPI(.clk(clk),.rst_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.wrt(strt_tx),.done(done), // First 3 channels for SPI
            .tx_data(16'hABCD),.MOSI(MOSI),.pos_edge(1'b1),.width8(len8)); // compare 16'hABCD with MOSI

initial begin
	fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
	en_AFE = 0;
	strt_tx = 0;						// do not initiate protocol trigger for now :) 
	len8 = 1'b0;	
	//// Initialization steps
	Initialize(send_cmd, REF_CLK, RST_n, clr_resp_rdy, host_cmd); //Initalizes all inputed signals

	////// Set for CH1 triggering on positive edge //////
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH1_Posedge);
       	// check for posACK	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
    	////// Leave all other registers at their default /////
    	////// and set RUN bit, but enable AFE first but keep protocol triggering off //////	
	en_AFE = 1;
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_norm);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
    
    	//// Now read trig config polling for capture_done bit to be set ////
	/// This whole polling for capture done should be a task ///
  	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
	 
	$display("INFO: capture_done bit is set");  	
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	// set capture_done & run bits back to low
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
		
 	repeat(10) @(posedge clk);
  	$fclose(fptr1);
  
 	//// Now compare CH1dmp.txt to expected results ////
  	fexp = $fopen("test1_expected.txt","r");
  	fptr1 = $fopen("CH1dmp.txt","r");
  
  	mem_compare(fexp, fptr1);
  
  	$fclose(fexp);
  	$fclose(fptr1);
    
 	$display("YAHOO! comparison completed, test1 passed!");

	// TEST 2. Test For UART trigger on CH1 //
	
	$display("Starting TEST 2");

	// enable UART triggering and disable AFE	
	UART_triggering = 1;
	en_AFE = 0;

	// no longer trigger on posedge with CH1dmp
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH1_default);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// specify higher bits of baud rate
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, UART_BAUD_HIGH);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
		
	// specify lower bits of baud rate
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, UART_BAUD_LOW);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// specify the bits to match
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, UART_MATCH);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// adjust decimator so clk is divided by 4 so we can see full UART wave
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, DECIMATOR_FOUR);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// adjust trig pos so UART WAVE is centered
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, PROT_TRIG_POS);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
  	////// set RUN bit, and enable UART trigger //////
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_UART);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// start TX transmission 
	strt_tx = 1;
	@(posedge clk);
	strt_tx = 0;
    
	//// Now read trig config polling for capture_done bit to be set ////
  	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);

	$display("TEST 2 INFO: capture_done bit is set");
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	// set capture_done & run bits back to low
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// dump UART wave to CH1dmp.txt
  	fptr1 = $fopen("CH1dmp.txt","w");
	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
  
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
	
	// compare CH1dmp to expected UART file
  	fptr1 = $fopen("CH1dmp.txt","r");
	fexp = $fopen("UARTdmp_expected.txt", "r");
	
	mem_compare(fexp, fptr1);
	
	$fclose(fptr1);
	
	$display("YAHOO! comparison completed, first UART trigger test passed!");
	// TEST 2.5 TEST for UART trigger with a different baud rate, incorrect match & mask such that it triggers	
	$display("Starting TEST 2.5");

	// specify new bits to match so it no longer matches UART
	// match will be 0x95
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, UART_MATCH_2);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// specify a mask so that we are still triggering even with a mismatch
	// this will just set the last two bits to 1
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, UART_MASK);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

  	////// set RUN bit, and enable UART trigger //////
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_UART);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	// start TX transmission 
	strt_tx = 1;
	@(posedge clk);
	strt_tx = 0;
    
	//// Now read trig config polling for capture_done bit to be set ////
  	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);

	$display("TEST 2.5 INFO: capture_done bit is set");
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	// set capture_done & run bits back to low
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// reset mask for future tests
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_maskL);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// dump UART wave to CH1dmp.txt
  	fptr1 = $fopen("CH1dmp.txt","w");
	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
  
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
	
	// compare CH1dmp to expected UART file
  	fptr1 = $fopen("CH1dmp.txt","r");
	fexp = $fopen("UARTdmp_mask_expected.txt", "r");
	
	mem_compare(fexp, fptr1);
	
	$fclose(fptr1);
	
  	$display("YAHOO! comparison completed, second UART trigger test passed!");

	// TEST 3. TEST for CH4 Negedge trigger 
	$display("Starting TEST 3");
	
	fptr1 = $fopen("CH4dmp.txt","w");	
	UART_triggering = 0;
	
	//Setting CH4 for Negedge triggering
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH4_Negedge);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//reset decimator back to 0
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_DECIMATOR);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);


	//Changing VIH levels to 8'hCC
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h47CC);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//Changing VIL levels to 8'h33
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4833);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	
	//Changing the trigger POS should trigger in the last 1/4 of the
	//screen 
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSH);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSL);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Set RUN bit, but enable AFE first
	en_AFE = 1;
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_norm);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
	
	$display("TEST 3 INFO: capture_done bit is set"); 
	
	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH4_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
	
	repeat(10) @(posedge clk);
  	$fclose(fptr1);
	
	fexp = $fopen("test3_expected.txt", "r");
	fptr1 = $fopen("CH4dmp.txt", "r");
	
	//Compare Results
	mem_compare(fexp, fptr1);
	
	$fclose(fexp);
  	$fclose(fptr1);
    
 	$display("YAHOO! comparison completed, test 3 passed!");
	
	// TEST 4. TEST for CH5 high trigger
	$display("Starting TEST 4");
	
	fptr1 = $fopen("CH5dmp.txt","w");	
	
	en_AFE = 0;
	
	//Chaning CH4 Trig Config to default
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH4_default);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Any Regesters Changed before test
	//Configure CH5 for high triggering
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH5_High_trig);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	
	//Changing trig_pos to max (Furthest left of picture)
	TRIG_POSH = 16'h4FFF;
	TRIG_POSL = 16'h50FF;
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSH);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSL);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//decrease sampling rate by 16 times
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, DECIMATOR_EIGHT);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Setting VIH to default levels
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h47AA);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//Setting VIL to default levels
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4855);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Set RUN bit, but enable AFE first
	en_AFE = 1;
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_norm);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
	
	$display("TEST 4 INFO: capture_done bit is set"); 
	
	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH5_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
	
	repeat(10) @(posedge clk);
  	$fclose(fptr1);
	
	//// Now compare CH1dmp.txt to expected results ////
  	fexp = $fopen("test4_expected.txt","r");
  	fptr1 = $fopen("CH5dmp.txt","r");
	
	mem_compare(fexp, fptr1);
  
  	$fclose(fexp);
  	$fclose(fptr1);
    
 	$display("YAHOO! comparison completed, test 4 passed!");
		
	// TEST 5. Test for CH3 Low level
	
	$display("Starting TEST 5");
	
	fptr1 = $fopen("CH3dmp.txt","w");
	
	en_AFE = 0;
	
	//Changing CH5 Trigg Config to default
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH5_default);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Configure CH3 for low level triggering
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH3_Low_trig);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Changing trig_pos to min (Furthest right on screen)
	TRIG_POSH = 16'h4F00;
	TRIG_POSL = 16'h5000;
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSH);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, TRIG_POSL);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//decrease sampling rate by 2 times
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, DECIMATOR_TWO);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//Set RUN bit, but enable AFE first
	en_AFE = 1;
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_norm);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);

	$display("TEST 5 INFO: capture_done bit is set"); 
	
	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH3_dump, fptr1, resp_rdy, clr_resp_rdy, resp);

	repeat(10) @(posedge clk);
  	$fclose(fptr1);
	
	fexp = $fopen("test5_expected.txt","r");
  	fptr1 = $fopen("CH3dmp.txt","r");
	
	mem_compare(fexp, fptr1);
  
  	$fclose(fexp);
  	$fclose(fptr1);
    
 	$display("YAHOO! comparison completed, test 5 passed!");
 	
	// ***************************************************************** Posegedge SPI Test *********************************************************************************
    	$display("Starting Test 6: SPI test");

    	fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
    	fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
    	fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to

    	SPI_triggering = 1'b1; // SPI initilized
    	en_AFE = 0;
     	// writing in, run, posegedge, 16bit, en SPI, disable UART
	
	// reset CH3
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, CH3_default);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	// setting the Match H level
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, SPI_matchH);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	// setting the Match L level
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, SPI_matchL);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// Adjusting decimator value so full SPI wave can be captured
  	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, DECIMATOR_TWO);
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

  	// adjust trig pos so SPI waves are more centered
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, PROT_TRIG_POS);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	// setting the SPI posedge
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_SPI);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	//Waiting for armed to go high before starting SPI transmission
  	repeat(500) @(posedge clk);
    	strt_tx = 1;
    	@(posedge clk);
    	strt_tx = 0;
    
    	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
    
    	$display("INFO TEST 6: capture_done bit is set");

	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
    	//CS
    	$display("CS dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
    	//SCLK
    	$display("SCLK dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH2_dump, fptr2, resp_rdy, clr_resp_rdy, resp);
    	//MOSI
    	$display("MOSI dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH3_dump, fptr3, resp_rdy, clr_resp_rdy, resp);
	
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
    	$fclose(fptr2);
    	$fclose(fptr3);

    	fexp_cs = $fopen("SPI_Test_CS_expected.txt","r");
  	fptr1 = $fopen("CH1dmp.txt","r");

    	fexp_sclk = $fopen("SPI_Test_SCLK_expected.txt","r");
  	fptr2 = $fopen("CH2dmp.txt","r");

    	fexp_mosi = $fopen("SPI_Test_MOSI_expected.txt","r");
  	fptr3 = $fopen("CH3dmp.txt","r");

    	//Comparing expected
    	mem_compare(fexp_cs, fptr1);
    	$display ("CS compare passed");

    	mem_compare(fexp_sclk, fptr2);
    	$display ("SCLK compare passed");

    	mem_compare(fexp_mosi, fptr3);
    	$display ("MOSI compare passed");

    	$fclose(fexp_cs);
    	$fclose(fptr1);
    	$fclose(fexp_sclk);
    	$fclose(fptr2);
    	$fclose(fexp_mosi);
    	$fclose(fptr3);
    
    	$display("YAHOO! comparison completed, SPI trigger test passed!");
	// Test 6.5 MASK and Match for SPI_prot

	$display("Test 6.5 SPI trigger with Mask");

	fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
    	fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
    	fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to

    	//Changing SPI match to match ABCC
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4ACC);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//Adding a mask for last bit
	//Changing MaskH 
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4B00);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//Changing MaskL
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4C01);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// setting the SPI posedge
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, set_run_SPI);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	//Waiting for armed to go high before starting SPI transmission
  	repeat(500) @(posedge clk);
    	strt_tx = 1;
    	@(posedge clk);
    	strt_tx = 0;
    
    	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
    
    	$display("INFO TEST 6.5: capture_done bit is set");

	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//CS
    	$display("CS dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
    	//SCLK
    	$display("SCLK dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH2_dump, fptr2, resp_rdy, clr_resp_rdy, resp);
    	//MOSI
    	$display("MOSI dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH3_dump, fptr3, resp_rdy, clr_resp_rdy, resp);
	
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
    	$fclose(fptr2);
    	$fclose(fptr3);

    	fexp_cs = $fopen("SPI_Test_CS_expected.txt","r");
  	fptr1 = $fopen("CH1dmp.txt","r");

    	fexp_sclk = $fopen("SPI_Test_SCLK_expected.txt","r");
  	fptr2 = $fopen("CH2dmp.txt","r");

    	fexp_mosi = $fopen("SPI_Test_MOSI_expected.txt","r");
  	fptr3 = $fopen("CH3dmp.txt","r");

    	//Comparing expected
    	mem_compare(fexp_cs, fptr1);
    	$display ("CS compare passed");

    	mem_compare(fexp_sclk, fptr2);
    	$display ("SCLK compare passed");

    	mem_compare(fexp_mosi, fptr3);
    	$display ("MOSI compare passed");

    	$fclose(fexp_cs);
    	$fclose(fptr1);
    	$fclose(fexp_sclk);
    	$fclose(fptr2);
    	$fclose(fexp_mosi);
    	$fclose(fptr3);
    
    	$display("YAHOO! comparison completed, Test 6.5 SPI trigger test passed!");

	// Test 7 SPI Len8 test
	$display("Test 7 SPI with len8");	
	//Setting Lower
	
    	fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
    	fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
    	fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to

	//Enable len8 for SPI_tx module
	len8 = 1'b1;

	//Resetting mask from previous test
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_maskL);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	// setting the Match L level
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4AAB);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	// setting the SPI posedge and len8 to true
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4015);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	//Waiting for armed to go high before starting SPI transmission
  	repeat(500) @(posedge clk);
    	strt_tx = 1;
    	@(posedge clk);
    	strt_tx = 0;
    
    	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
    
    	$display("INFO TEST 7: capture_done bit is set");

	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
    	//CS
    	$display("CS dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
    	//SCLK
    	$display("SCLK dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH2_dump, fptr2, resp_rdy, clr_resp_rdy, resp);
    	//MOSI
    	$display("MOSI dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH3_dump, fptr3, resp_rdy, clr_resp_rdy, resp);
	
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
    	$fclose(fptr2);
    	$fclose(fptr3);

    	fexp_cs = $fopen("SPI_Test_len8_CS_expected.txt","r");
  	fptr1 = $fopen("CH1dmp.txt","r");

    	fexp_sclk = $fopen("SPI_Test_len8_SCLK_expected.txt","r");
  	fptr2 = $fopen("CH2dmp.txt","r");

    	fexp_mosi = $fopen("SPI_Test_len8_MOSI_expected.txt","r");
  	fptr3 = $fopen("CH3dmp.txt","r");

    	//Comparing expected
    	mem_compare(fexp_cs, fptr1);
    	$display ("CS compare passed");

    	mem_compare(fexp_sclk, fptr2);
    	$display ("SCLK compare passed");

    	mem_compare(fexp_mosi, fptr3);
    	$display ("MOSI compare passed");

    	$fclose(fexp_cs);
    	$fclose(fptr1);
    	$fclose(fexp_sclk);
    	$fclose(fptr2);
    	$fclose(fexp_mosi);
    	$fclose(fptr3);
    
    	$display("YAHOO! comparison completed, TEST 7 SPI_len8 trigger test passed!");
	// Test 7.5 SPI_len8 test with mask
		
	$display("Test 7.5  SPI_len8 trigger with Mask");

	fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
    	fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
    	fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to

    	//Changing SPI match AA
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4AAA);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	//Adding a mask for last bit
	//Changing MaskL
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4C01);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

	// setting the SPI posedge
    	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, 16'h4015);
    	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);

    	//Waiting for armed to go high before starting SPI transmission
  	repeat(500) @(posedge clk);
    	strt_tx = 1;
    	@(posedge clk);
    	strt_tx = 0;
    
    	wait_for_cap_done(send_cmd, cmd_sent, clk, host_cmd, read_TRIG_CFG, resp_rdy, clr_resp_rdy, resp);
    
    	$display("INFO TEST 7.5: capture_done bit is set");

	// set capture_done & run bits back to low
	Send_cmd(send_cmd, cmd_sent, clk, host_cmd, reset_TRIG_CFG);	
	check_for_posACK(clk, clr_resp_rdy, resp_rdy, resp);
	
	//CS
    	$display("CS dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH1_dump, fptr1, resp_rdy, clr_resp_rdy, resp);
    	//SCLK
    	$display("SCLK dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH2_dump, fptr2, resp_rdy, clr_resp_rdy, resp);
    	//MOSI
    	$display("MOSI dump");
    	CH_dump(send_cmd, cmd_sent, clk, host_cmd, CH3_dump, fptr3, resp_rdy, clr_resp_rdy, resp);
	
  	repeat(10) @(posedge clk);
  	$fclose(fptr1);
    	$fclose(fptr2);
    	$fclose(fptr3);

    	fexp_cs = $fopen("SPI_test_len8_mask_CS_expected.txt","r");
  	fptr1 = $fopen("CH1dmp.txt","r");

    	fexp_sclk = $fopen("SPI_test_len8_mask_SCLK_expected.txt","r");
  	fptr2 = $fopen("CH2dmp.txt","r");

    	fexp_mosi = $fopen("SPI_test_len8_mask_MOSI_expected.txt","r");
  	fptr3 = $fopen("CH3dmp.txt","r");

    	//Comparing expected
    	mem_compare(fexp_cs, fptr1);
    	$display ("CS compare passed");

    	mem_compare(fexp_sclk, fptr2);
    	$display ("SCLK compare passed");

    	mem_compare(fexp_mosi, fptr3);
    	$display ("MOSI compare passed");

    	$fclose(fexp_cs);
    	$fclose(fptr1);
    	$fclose(fexp_sclk);
    	$fclose(fptr2);
    	$fclose(fexp_mosi);
    	$fclose(fptr3);
    
    	$display("YAHOO! comparison completed, Test 7.5  SPI_len8 trigger test passed!");

	$display("YAHOO! ALL TESTS PASS :)");
	$stop; 
end

always
  #100 REF_CLK = ~REF_CLK;

endmodule	
