`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : cic_top
// Description : 4th-order CIC decimation filter (Task 1)
//               N = 4, R = 512, M = 1
//               Input  : 2-bit signed (values -1, 0, +1) from the testbench
//               Output : 20-bit signed (rounded), one sample every R clocks
//
// Hogenauer bit growth : Bmax = N*log2(R*M) + Bin = 4*9 + 2 = 38 bits
// CIC DC gain          : (R*M)^N = 512^4 = 2^36
// Output scaling       : cic_out = round(comb_out / 2^18)  -> max |out| = 2^18,
//                        which fits in 20-bit signed with 1 bit of headroom.
//////////////////////////////////////////////////////////////////////////////////
module cic_top #(
    parameter integer N     = 4,            // filter order
    parameter integer R     = 512,          // decimation factor
    parameter integer M     = 1,            // differential delay
    parameter integer BIN   = 2,            // input width  (signed)
    parameter integer BMAX  = 38,           // N*log2(R*M)+BIN  (Hogenauer)
    parameter integer BOUT  = 20,           // output width (hard limit)
    parameter integer SHIFT = 18            // BMAX - BOUT : drop 18 LSBs
)(
    input  wire                     clk,
    input  wire                     reset,      // synchronous, active high
    input  wire                     enable,
    input  wire signed [BIN-1:0]    din,
    output reg                      outready,   // 1-cycle pulse when cicout is new
    output reg  signed [BOUT-1:0]   cicout
);

    // ------------------------------------------------------------------
    // Integrator section (runs at input rate, 2's-complement wrap-around)
    // ------------------------------------------------------------------
    reg signed [BMAX-1:0] integ1, integ2, integ3, integ4;

    wire signed [BMAX-1:0] din_ext = {{(BMAX-BIN){din[BIN-1]}}, din}; // sign-extend

    always @(posedge clk) begin
        if (reset) begin
            integ1 <= 0; integ2 <= 0; integ3 <= 0; integ4 <= 0;
        end else if (enable) begin
            integ1 <= integ1 + din_ext;
            integ2 <= integ2 + integ1;
            integ3 <= integ3 + integ2;
            integ4 <= integ4 + integ3;
        end
    end

    // ------------------------------------------------------------------
    // Decimator : take one sample every R clocks
    // ------------------------------------------------------------------
    reg [$clog2(R)-1:0] cnt;
    wire strobe = enable && (cnt == R-1);

    always @(posedge clk) begin
        if (reset)       cnt <= 0;
        else if (enable) cnt <= (cnt == R-1) ? 0 : cnt + 1'b1;
    end

    // ------------------------------------------------------------------
    // Comb section (runs at the low rate, M = 1), pipelined one stage/step
    // ------------------------------------------------------------------
    reg signed [BMAX-1:0] samp;
    reg signed [BMAX-1:0] d1, d2, d3, d4;     // comb delay registers
    reg signed [BMAX-1:0] c1, c2, c3, c4;     // comb outputs
    reg [4:0]             v;                  // valid pipeline

    always @(posedge clk) begin
        if (reset) begin
            samp <= 0;
            d1 <= 0; d2 <= 0; d3 <= 0; d4 <= 0;
            c1 <= 0; c2 <= 0; c3 <= 0; c4 <= 0;
            v  <= 5'b0;
        end else begin
            v <= {v[3:0], strobe};
            if (strobe) samp <= integ4;
            if (v[0]) begin d1 <= samp; c1 <= samp - d1; end
            if (v[1]) begin d2 <= c1;   c2 <= c1   - d2; end
            if (v[2]) begin d3 <= c2;   c3 <= c2   - d3; end
            if (v[3]) begin d4 <= c3;   c4 <= c3   - d4; end
        end
    end

    // ------------------------------------------------------------------
    // Output scaling : round-to-nearest and keep the top 20 bits
    // ------------------------------------------------------------------
    wire signed [BMAX-1:0] rounded = c4 + (1 <<< (SHIFT-1));

    always @(posedge clk) begin
        if (reset) begin
            outready <= 1'b0;
            cicout   <= 0;
        end else begin
            outready <= v[4];
            if (v[4]) cicout <= rounded[BMAX-1:SHIFT];   // 38-18 = 20 bits
        end
    end

endmodule
