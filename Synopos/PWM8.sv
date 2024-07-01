module pwm8(clk, rst_n, duty, PWM_sig);

input clk, rst_n;
input [7:0] duty;
output reg PWM_sig;

reg [7:0] cnt;

// pwm_sig register
// only set PWM_sig to high while count is less than or equal to duty
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		PWM_sig <= 0;
	end
	else if (cnt <= duty) begin
		PWM_sig <= 1;
	end
	else begin
		PWM_sig <= 0;
	end
end

// cnt register
// always incrementing as it will evevuntally overflow & go back to 0
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		cnt <= '0;
	end
	else begin
		cnt <= cnt + 1;
	end
end

endmodule

