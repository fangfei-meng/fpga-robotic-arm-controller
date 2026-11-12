// ---------------------------------------------------------------------------
// SM - X/Y Motion Control State Machine (MEALY)
//
// - Press MOTION: target X/Y switch values are captured into the holding
//   registers (capture_enable). Release MOTION: the arm moves automatically.
// - X and Y move together; each axis stops independently when it reaches its
//   target. While moving, the holding registers are NOT reloaded, so switch
//   changes and further MOTION presses are ignored.
// - If MOTION is requested while the extender is out (extended = 1), motion
//   is blocked and posc_err (System Fault) latches ON. It is cleared by fully
//   retracting the extender and pressing/releasing MOTION again.
// - The extender may only operate while the arm is at rest (or in the fault
//   state, so that it can be retracted to clear the fault).
//
// Mealy outputs: the counter enables/directions depend on the current state
// AND the live comparator inputs.
// ---------------------------------------------------------------------------
module SM (
	input  clock,
	input  reset,
	input  sm_clken,
	input  motion,                 // synchronized MOTION push-button
	input  extended,               // from SM1: extender not fully retracted
	input  x_eq, x_gt, x_lt,       // X position vs X target
	input  y_eq, y_gt, y_lt,       // Y position vs Y target
	output reg capture_enable,     // load X/Y target registers
	output reg x_cnt_en,
	output reg x_cnt_up1_dwn0,
	output reg y_cnt_en,
	output reg y_cnt_up1_dwn0,
	output reg extender_enbl,      // to SM1
	output reg posc_err            // System Fault Error (leds[0])
);

	// ----- state encoding -----
	parameter [1:0]	AT_REST   = 2'b00,	// idle at current position
						CAPTURE   = 2'b01,	// MOTION held: capture target, wait for release
						IN_MOTION = 2'b10,	// moving towards target
						FAULT     = 2'b11;	// motion requested while extended (locked)

	reg [1:0] current_state, next_state;

	// ----- REGISTER section (sequential) -----
	always @(posedge clock)
	begin
		if (reset == 1'b1)
			current_state <= AT_REST;
		else if (sm_clken == 1'b1)
			current_state <= next_state;
	end

	// ----- TRANSITION section (combinational) -----
	always @(*)
	begin
		case (current_state)
			AT_REST:
				if (motion && extended)			next_state = FAULT;
				else if (motion)					next_state = CAPTURE;
				else									next_state = AT_REST;

			CAPTURE:
				if (!motion)						next_state = IN_MOTION;
				else									next_state = CAPTURE;

			IN_MOTION:
				if (x_eq && y_eq)					next_state = AT_REST;
				else									next_state = IN_MOTION;

			FAULT:
				// fault clears only after full retraction AND a new MOTION request
				if (motion && !extended)		next_state = CAPTURE;
				else									next_state = FAULT;

			default:								next_state = AT_REST;
		endcase
	end

	// ----- DECODER section (Mealy: outputs depend on state AND inputs) -----
	always @(*)
	begin
		// all outputs default to 0
		capture_enable = 1'b0;
		x_cnt_en       = 1'b0;
		x_cnt_up1_dwn0 = 1'b0;
		y_cnt_en       = 1'b0;
		y_cnt_up1_dwn0 = 1'b0;
		extender_enbl  = 1'b0;
		posc_err       = 1'b0;

		case (current_state)
			AT_REST: begin
				extender_enbl  = 1'b1;
			end
			CAPTURE: begin
				capture_enable = 1'b1;
			end
			IN_MOTION: begin
				x_cnt_en       = ~x_eq;	// stop X when X target reached
				x_cnt_up1_dwn0 = x_lt;		// position < target -> count up
				y_cnt_en       = ~y_eq;
				y_cnt_up1_dwn0 = y_lt;
			end
			FAULT: begin
				posc_err       = 1'b1;
				extender_enbl  = 1'b1;		// allow retraction to clear fault
			end
			default: begin
			end
		endcase
	end

endmodule
