// Simulation model of the Intel/Altera GLOBAL buffer primitive.
// Only needed for simulators outside Quartus (e.g. Icarus Verilog).
// Do NOT add this file to the Quartus project.
module GLOBAL (input in, output out);
	assign out = in;
endmodule
