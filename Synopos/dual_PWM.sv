module dual_PWM (clk, rst_n, VIL, VIH, VIL_PWM, VIH_PWM);

input clk, rst_n;
input [7:0] VIL, VIH;
output reg VIL_PWM, VIH_PWM;

// instantiated pwm8 for vil and vih pwms
pwm8 vil (.clk(clk), .rst_n(rst_n), .duty(VIL), .PWM_sig(VIL_PWM));
pwm8 vih (.clk(clk), .rst_n(rst_n), .duty(VIH), .PWM_sig(VIH_PWM));

endmodule
