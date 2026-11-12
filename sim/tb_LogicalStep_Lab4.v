`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// Self-checking testbench for the Robotic Arm Controller (RAC).
// Compile with SIM_FLAG defined so the clock-enable runs at the fast
// simulation rate, e.g. (Icarus Verilog):
//   iverilog -g2012 -DSIM_FLAG -o rac.vvp sim/tb_LogicalStep_Lab4.v sim/GLOBAL.v rtl/*.v
//   vvp rac.vvp
// ---------------------------------------------------------------------------
module tb_LogicalStep_Lab4;

	reg        clkin_50 = 1'b0;
	reg  [3:0] pb_n     = 4'b1111;   // push-buttons are active LOW
	reg  [7:0] sw       = 8'h00;
	wire [7:0] leds;
	wire [6:0] seg7_data;
	wire       seg7_char1, seg7_char2;

	integer errors = 0;

	LogicalStep_Lab4_top dut (
		.clkin_50  (clkin_50),
		.pb_n      (pb_n),
		.sw        (sw),
		.leds      (leds),
		.seg7_data (seg7_data),
		.seg7_char1(seg7_char1),
		.seg7_char2(seg7_char2)
	);

	always #10 clkin_50 = ~clkin_50;   // 50 MHz

	// wait for N global clock-enable pulses
	task wait_clken(input integer n);
		integer i;
		begin
			for (i = 0; i < n; i = i + 1) begin
				@(posedge dut.global_clk);
				while (!dut.global_clken) @(posedge dut.global_clk);
			end
		end
	endtask

	// press / hold / release a push-button (index 0..3)
	task press(input integer b);
		begin
			pb_n[b] = 1'b0;
			wait_clken(3);
			pb_n[b] = 1'b1;
			wait_clken(3);
		end
	endtask

	task check(input [255:0] what, input integer got, input integer exp);
		begin
			if (got !== exp) begin
				$display("FAIL  %0s : got %0d, expected %0d  (t=%0t)", what, got, exp, $time);
				errors = errors + 1;
			end else
				$display("PASS  %0s = %0d", what, got);
		end
	endtask

	initial begin
		$dumpfile("rac.vcd");
		$dumpvars(0, tb_LogicalStep_Lab4);

		// ---- reset ----
		pb_n[3] = 1'b0;  wait_clken(2);  pb_n[3] = 1'b1;  wait_clken(2);
		check("X after reset", dut.x_pos, 0);
		check("Y after reset", dut.y_pos, 0);

		// ---- move to (5,3) ----
		sw = 8'h53;
		press(2);
		sw = 8'hFF;                     // changing switches during motion must be ignored
		wait_clken(20);
		check("X at target", dut.x_pos, 5);
		check("Y at target", dut.y_pos, 3);

		// ---- move back down to (2,7): X counts down, Y counts up ----
		sw = 8'h27;
		press(2);
		wait_clken(20);
		check("X at target", dut.x_pos, 2);
		check("Y at target", dut.y_pos, 7);

		// ---- extend ----
		press(1);
		wait_clken(8);
		check("extender fully extended (leds[5:2])", leds[5:2], 4'b1111);
		check("Extender_OUT (leds[6])", leds[6], 1);

		// ---- grappler: close then open ----
		press(0);
		check("grappler closed (leds[1])", leds[1], 1);
		press(0);
		check("grappler open (leds[1])", leds[1], 0);
		press(0);
		check("grappler closed again", leds[1], 1);

		// ---- motion while extended -> System Fault, no movement ----
		sw = 8'hAA;
		press(2);
		wait_clken(5);
		check("posc_err (leds[0])", leds[0], 1);
		check("X did not move", dut.x_pos, 2);
		check("Y did not move", dut.y_pos, 7);

		// ---- retract, then motion clears the fault ----
		press(1);
		wait_clken(8);
		check("extender retracted", leds[5:2], 4'b0000);
		check("posc_err still latched until motion", leds[0], 1);
		press(2);
		check("posc_err cleared", leds[0], 0);
		wait_clken(20);
		check("X at new target", dut.x_pos, 10);
		check("Y at new target", dut.y_pos, 10);

		// ---- grappler must be disabled when not fully extended ----
		press(0);
		check("grappler unchanged when retracted", leds[1], 1);

		if (errors == 0) $display("\n*** ALL TESTS PASSED ***");
		else             $display("\n*** %0d TEST(S) FAILED ***", errors);
		$finish;
	end

endmodule
