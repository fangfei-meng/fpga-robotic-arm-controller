// ---------------------------------------------------------------------------
// SM1 - Extender Control State Machine (MOORE)
//
// Drives the 4-bit bidirectional shift register that models the extender:
//   0000 -> 1000 -> 1100 -> 1110 -> 1111   (extend,  right shift filling 1s)
//   1111 -> 1110 -> 1100 -> 1000 -> 0000   (retract, left shift filling 0s)
//
// - Extension starts on press/hold/release of EXTENDER, only while
//   extender_enbl is active (X/Y motion controller is at rest).
// - Retraction starts on the next press/hold/release while fully extended.
// - grappler_enbl is active only while FULLY EXTENDED.
// - extended is active whenever the extender is NOT fully retracted.
// ---------------------------------------------------------------------------
module SM1 (
	input  clock,
	input  reset,
	input  sm_clken,
	input  extender,               // synchronized EXTENDER push-button
	input  extender_enbl,          // from SM: X/Y motion is at rest
	input  [3:0] extender_pos,     // current shift register value
	output reg extender_in_motion, // enables the shift register
	output reg extender_dir,       // 1 = extend (right shift), 0 = retract (left shift)
	output reg extended,           // to SM: extender is not fully retracted
	output reg grappler_enbl       // to SM2: extender is fully extended
);

	// ----- state encoding -----
	parameter [2:0]	RETRACTED      = 3'b000,	// fully retracted, idle
						EXTEND_PRESSED = 3'b001,	// press seen, wait for release
						EXTENDING      = 3'b010,	// shifting out
						FULL_EXTENDED  = 3'b011,	// fully extended, idle
						RETRACT_PRESSED= 3'b100,	// press seen, wait for release
						RETRACTING     = 3'b101;	// shifting in

	reg [2:0] current_state, next_state;

	// ----- REGISTER section (sequential) -----
	always @(posedge clock)
	begin
		if (reset == 1'b1)
			current_state <= RETRACTED;
		else if (sm_clken == 1'b1)
			current_state <= next_state;
	end

	// ----- TRANSITION section (combinational) -----
	always @(*)
	begin
		case (current_state)
			RETRACTED:
				if (extender && extender_enbl)	next_state = EXTEND_PRESSED;
				else										next_state = RETRACTED;

			EXTEND_PRESSED:
				if (!extender)							next_state = EXTENDING;
				else										next_state = EXTEND_PRESSED;

			EXTENDING:
				if (extender_pos == 4'b1111)		next_state = FULL_EXTENDED;
				else										next_state = EXTENDING;

			FULL_EXTENDED:
				if (extender)							next_state = RETRACT_PRESSED;
				else										next_state = FULL_EXTENDED;

			RETRACT_PRESSED:
				if (!extender)							next_state = RETRACTING;
				else										next_state = RETRACT_PRESSED;

			RETRACTING:
				if (extender_pos == 4'b0000)		next_state = RETRACTED;
				else										next_state = RETRACTING;

			default:									next_state = RETRACTED;
		endcase
	end

	// ----- DECODER section (Moore: outputs depend on current_state only) -----
	always @(*)
	begin
		// defaults
		extender_in_motion = 1'b0;
		extender_dir       = 1'b0;
		extended           = 1'b1;
		grappler_enbl      = 1'b0;

		case (current_state)
			RETRACTED: begin
				extended = 1'b0;
			end
			EXTEND_PRESSED: begin
				extended = 1'b0;
			end
			EXTENDING: begin
				extender_in_motion = 1'b1;
				extender_dir       = 1'b1;
			end
			FULL_EXTENDED: begin
				grappler_enbl      = 1'b1;
			end
			RETRACT_PRESSED: begin
				// still fully extended, waiting for button release
			end
			RETRACTING: begin
				extender_in_motion = 1'b1;
				extender_dir       = 1'b0;
			end
			default: begin
				extended = 1'b0;
			end
		endcase
	end

endmodule
