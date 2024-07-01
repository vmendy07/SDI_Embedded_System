module trigger_logic (CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, protTrig, armed, set_capture_done, rst_n, clk, triggered);

input CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, protTrig, armed, set_capture_done, rst_n, clk;
output reg triggered;

logic trig_set, trig_and_armed, nor1, d; 

// variables checking if all the triggers are set and if armed is high
assign trig_set = CH1Trig & CH2Trig & CH3Trig & CH4Trig & CH5Trig & protTrig;
assign trig_and_armed = trig_set & armed;

// nor gate with the signal above and triggered signal as inputs
assign nor1 = ~(trig_and_armed | triggered);

// another nor gate with previous signal and set_capture_done that will be the input to the flop
assign d = ~(nor1 | set_capture_done);

//triggered FF where values will be updated every rising clock edge
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		triggered <= 1'b0;
	else 
		triggered <= d;
end

endmodule

