module chnnl_trig(clk, rst_n, CH_TrigCfg, armed, CH_Lff5, CH_Hff5, CH_Trig);

input clk, rst_n, armed, CH_Lff5, CH_Hff5;
input [4:0] CH_TrigCfg;
output CH_Trig;

// last # of FF name is based off the bit used in CH_TrigCfg that these flops will be anded with
logic CH_Hff5_ff4, CH_Lff5_ff3, CH_Hff5_ff2, CH_Lff5_ff1;

//second column of FFs
logic CH_Hff5_ff4_2, CH_Lff5_ff3_2;

// and gates with # in name based off bit # from CH_TrigCfg being anded
logic and4, and3, and2, and1; 

// FF that uses CH_Hff5 as clk
always @(posedge CH_Hff5, negedge armed) begin
	if (!armed) begin
		CH_Hff5_ff4 <= 0;
	end 
	else begin
		CH_Hff5_ff4 <= 1;
	end
end

// FF that uses CH_Lff5 as clk
always @(negedge CH_Lff5, negedge armed) begin	
	if (!armed) begin
		CH_Lff5_ff3 <= 0;
	end
	else begin 
		CH_Lff5_ff3 <= 1;
	end
end

// FFs that use clk signal as clk
always @(posedge clk) begin
	CH_Hff5_ff4_2 <= CH_Hff5_ff4;
	CH_Lff5_ff3_2 <= CH_Lff5_ff3;
	CH_Hff5_ff2 <= CH_Hff5;
	CH_Lff5_ff1 <= ~CH_Lff5;
end

// and gates
assign and4 = CH_Hff5_ff4_2 & CH_TrigCfg[4];
assign and3 = CH_Lff5_ff3_2 & CH_TrigCfg[3];
assign and2 = CH_Hff5_ff2 & CH_TrigCfg[2];
assign and1 = CH_Lff5_ff1 & CH_TrigCfg[1];

// final or gate that we will output to CH_Trig
assign CH_Trig = and4 | and3 | and2 | and1 | CH_TrigCfg[0];

endmodule
	



