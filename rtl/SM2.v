// ---------------------------------------------------------------------------
// SM2 - Grappler Control State Machine (MOORE)
//
// The grappler toggles between OPEN and CLOSED on each press/hold/release of
// the GRAPPLER push-button, but only while grappler_enbl is active (i.e. the
// extender is fully extended, as reported by SM1).
//
//   grappler_on = 1 : grappler CLOSED
//   grappler_on = 0 : grappler OPEN
//
// Separate states are used to detect the button PRESS and the button RELEASE
// so that one press/hold/release produces exactly one toggle.
// ---------------------------------------------------------------------------
module SM2 (
	input  clock,
	input  reset,
	input  sm_clken,
	input  grappler,         // synchronized GRAPPLER push-button (active high)
	input  grappler_enbl,    // from SM1: extender is fully extended
	output reg grappler_on   // 1 = CLOSED, 0 = OPEN
);

	// ----- state encoding -----
	parameter [1:0]	OPEN          = 2'b00,	// grappler open, waiting for press
						CLOSE_PRESSED = 2'b01,	// press seen while open, wait for release
						CLOSED        = 2'b10,	// grappler closed, waiting for press
						OPEN_PRESSED  = 2'b11;	// press seen while closed, wait for release

	reg [1:0] current_state, next_state;

	// ----- REGISTER section (sequential) -----
	always @(posedge clock)
	begin
		if (reset == 1'b1)
			current_state <= OPEN;
		else if (sm_clken == 1'b1)
			current_state <= next_state;
	end

	// ----- TRANSITION section (combinational) -----
	always @(*)
	begin
		case (current_state)
			OPEN:
				if (grappler && grappler_enbl)	next_state = CLOSE_PRESSED;
				else										next_state = OPEN;

			CLOSE_PRESSED:
				if (!grappler)							next_state = CLOSED;
				else										next_state = CLOSE_PRESSED;

			CLOSED:
				if (grappler && grappler_enbl)	next_state = OPEN_PRESSED;
				else										next_state = CLOSED;

			OPEN_PRESSED:
				if (!grappler)							next_state = OPEN;
				else										next_state = OPEN_PRESSED;

			default:									next_state = OPEN;
		endcase
	end

	// ----- DECODER section (Moore: outputs depend on current_state only) -----
	always @(*)
	begin
		case (current_state)
			OPEN:				grappler_on = 1'b0;
			CLOSE_PRESSED:	grappler_on = 1'b0;	// changes only after release
			CLOSED:			grappler_on = 1'b1;
			OPEN_PRESSED:	grappler_on = 1'b1;
			default:			grappler_on = 1'b0;
		endcase
	end

endmodule
