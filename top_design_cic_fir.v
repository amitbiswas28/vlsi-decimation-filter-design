`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// top_cic_fir : your existing cic_top (UNCHANGED)  ->  fir_comp (droop compensator)
// Same ports as cic_top, so the testbench only needs its instance line changed.
//////////////////////////////////////////////////////////////////////////////////
module top_cic_fir (
    input  wire               clk,
    input  wire               reset,
    input  wire               enable,
    input  wire signed [1:0]  din,
    output wire               outready,
    output wire signed [19:0] cicout
);
    wire               cic_valid;
    wire signed [19:0] cic_data;

    // your Task-1 CIC, no change
    cic_top #(.N(4), .R(512), .M(1), .BIN(2), .BMAX(38), .BOUT(20), .SHIFT(18))
        u_cic (.clk(clk), .reset(reset), .enable(enable),
               .din(din), .outready(cic_valid), .cicout(cic_data));

    // FIR: 20-bit input, so XW=20 and the output shift is 15 (coefficients are Q3.15)
    fir_comp #(.XW(20), .SH(15)) u_fir (
        .clk(clk), .reset(reset),
        .in_valid(cic_valid), .in_data(cic_data),
        .out_valid(outready), .out_data(cicout));
endmodule
