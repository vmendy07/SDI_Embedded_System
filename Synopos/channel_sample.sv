module channel_sample(smpl_clk, clk, CH_H, CH_L, CH_Hff5, CH_Lff5, smpl);

// create signals/registers
input smpl_clk, clk, CH_H, CH_L;
output logic CH_Hff5, CH_Lff5;
output logic [7:0] smpl;

logic CH_Hff1, CH_Lff1, CH_Hff2, CH_Lff2, CH_Hff3, CH_Lff3, CH_Hff4, CH_Lff4;

// FFs for CHxL and CHxH signals
always_ff @(negedge smpl_clk) begin
	
	CH_Hff1 <= CH_H;
	CH_Lff1 <= CH_L;
	
	CH_Hff2 <= CH_Hff1;
	CH_Lff2 <= CH_Lff1;
	
	CH_Hff3 <= CH_Hff2;
	CH_Lff3 <= CH_Lff2;
	
	CH_Hff4 <= CH_Hff3;
	CH_Lff4 <= CH_Lff3;
	
	CH_Hff5 <= CH_Hff4;
	CH_Lff5 <= CH_Lff4;
end

// FF for smpl signal
always_ff @(posedge clk) begin
	smpl <= {CH_Hff2, CH_Lff2, CH_Hff3, CH_Lff3, CH_Hff4, CH_Lff4, CH_Hff5, CH_Lff5};
end

endmodule