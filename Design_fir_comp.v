`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// fir_comp : 15-tap inverse-sinc (droop compensating) FIR, runs at the CIC
//            output rate (clk/512).  One multiplier is shared by all taps
//            (time-multiplexed MAC), because there are 512 clocks per sample
//            and only 15 are needed.
//
//   in  : 25-bit signed  (CIC output bits [37:13])
//   coef: 18-bit signed, Q3.15   (sum of taps = 6.85 = overall gain)
//   acc : 48-bit signed
//   out : 20-bit signed = round(acc / 2^20), saturated (never wraps)
//
//   Scaling check : out = sum(x25*coef)/2^20
//                     = (cic/2^13) * (h*2^15) / 2^20 = cic * h / 2^18
//   -> same 2^-18 scaling as Task 1, times the FIR gain of ~6.8, which uses
//      the 20-bit range (peak = about 95 % of full scale).
//////////////////////////////////////////////////////////////////////////////////
module fir_comp #(
    parameter integer TAPS = 15,
    parameter integer XW   = 25,
    parameter integer CW   = 18,
    parameter integer AW   = 48,
    parameter integer OW   = 20,
    parameter integer SH   = 20
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    in_valid,
    input  wire signed [XW-1:0]    in_data,
    output reg                     out_valid,
    output reg  signed [OW-1:0]    out_data
);
    // ---------------- sample delay line ----------------
    reg signed [XW-1:0] x [0:TAPS-1];
    integer j;

    // ---------------- coefficient ROM ----------------
    reg [3:0]            k;
    reg signed [CW-1:0]  coef;
    always @(*) begin
        case (k)
            4'd0: coef = 18'sd3196;   // h[0] = +0.097534
            4'd1: coef = 18'sd4306;   // h[1] = +0.131409
            4'd2: coef = -18'sd3335;   // h[2] = -0.101776
            4'd3: coef = -18'sd14952;   // h[3] = -0.456299
            4'd4: coef = -18'sd10989;   // h[4] = -0.335358
            4'd5: coef = 18'sd21903;   // h[5] = +0.668427
            4'd6: coef = 18'sd67540;   // h[6] = +2.061157
            4'd7: coef = 18'sd89242;   // h[7] = +2.723450
            4'd8: coef = 18'sd67540;   // h[8] = +2.061157
            4'd9: coef = 18'sd21903;   // h[9] = +0.668427
            4'd10: coef = -18'sd10989;   // h[10] = -0.335358
            4'd11: coef = -18'sd14952;   // h[11] = -0.456299
            4'd12: coef = -18'sd3335;   // h[12] = -0.101776
            4'd13: coef = 18'sd4306;   // h[13] = +0.131409
            4'd14: coef = 18'sd3196;   // h[14] = +0.097534            default: coef = 0;
        endcase
    end

    // ---------------- MAC control ----------------
    reg                    run;                 // MAC is walking through the taps
    reg                    v1, last1;           // product register valid / last tap
    reg signed [XW+CW-1:0] prod;
    reg signed [AW-1:0]    acc;
    reg                    done;

    wire signed [AW-1:0] acc_n = acc + prod;

    always @(posedge clk) begin
        if (reset) begin
            for (j = 0; j < TAPS; j = j + 1) x[j] <= 0;
            k <= 0; run <= 0; v1 <= 0; last1 <= 0;
            prod <= 0; acc <= 0; done <= 0;
        end else begin
            done <= 1'b0;

            // new sample arrives -> shift the delay line, start MAC
            if (in_valid) begin
                for (j = TAPS-1; j > 0; j = j - 1) x[j] <= x[j-1];
                x[0] <= in_data;
                k   <= 0;
                run <= 1'b1;
                acc <= 0;
            end

            // stage 1 : multiply
            v1    <= run;
            last1 <= run && (k == TAPS-1);
            if (run) begin
                prod <= x[k] * coef;
                if (k == TAPS-1) run <= 1'b0;
                else             k   <= k + 1'b1;
            end

            // stage 2 : accumulate
            if (v1) begin
                acc <= acc_n;
                if (last1) done <= 1'b1;
            end
        end
    end

    // ---------------- round, saturate to 20 bits ----------------
    localparam signed [AW-1:0] MAXV =  (1 <<< (OW-1)) - 1;
    localparam signed [AW-1:0] MINV = -(1 <<< (OW-1));

    wire signed [AW-1:0] rnd = (acc + (1 <<< (SH-1))) >>> SH;

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            out_data  <= 0;
        end else begin
            out_valid <= done;
            if (done) begin
                if      (rnd > MAXV) out_data <= MAXV[OW-1:0];
                else if (rnd < MINV) out_data <= MINV[OW-1:0];
                else                 out_data <= rnd[OW-1:0];
            end
        end
    end
endmodule
