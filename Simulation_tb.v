`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: cic_tb   (simulation source for cic_top, Task 1, 10 Hz tone)
// Put hz10.mem in the simulation sources / simulation run directory.
// Output files (in <project>.sim/sim_1/behav/xsim/):
//    out_10_1.txt      -> 2 kHz samples  (feed this to fft_2.m)
//    cic512_10.txt     -> every CIC output (8 kHz equivalent, R = 512)
//    bits.txt          -> the 2-bit stream actually fed to the DUT
//////////////////////////////////////////////////////////////////////////////////
module cic_tb();
    reg data [0:4096025];

    reg clk, clk3, reset, enable;
    wire outready;

    reg  signed [1:0] bits;

    wire signed [19:0] cicout;      // 20-bit output (hard limit)

    initial begin
        $readmemh("hz990.mem", data);   // input data  (change to hz500.mem / hz990.mem later)
    end

    initial begin
        clk    = 0;
        clk3   = 0;
        bits   = 0;
        enable = 0;
        reset  = 1;
        #51 reset = 0;
        enable = 1;
    end
    always #50     clk  = ~clk;      // 10 MHz, 1 sample/clock
    always #102400 clk3 = ~clk3;     // period 2048 clocks = R*4 -> "by4" output (2 kHz)

    integer i;
    initial i = 0;

    integer fd1, fd2, fd4;
    initial begin
        fd1 = $fopen("bits.txt","w");
        fd2 = $fopen("cic512_990.txt","w");   // all CIC outputs
        fd4 = $fopen("out_990_cicfir.txt","w");    // name expected by fft_2.m
    end

    // Drive input (non-blocking => no race with the DUT's posedge clk)
    always @(posedge clk) begin
        if (i < 4096026) begin
            if (i%2==0) bits <= {1'b0, data[i]};
            else        bits <= {2{data[i]}};
            i <= i + 1;
        end else begin
            #200;
            $finish;
        end
    end

    always @(posedge clk) $fwrite(fd1, "%d\n", bits);

    always @(posedge clk) begin
        if (outready) $fwrite(fd2, "%d\n", $signed(cicout));
    end

    always @(posedge clk3) begin
        $fwrite(fd4, "%d\n", $signed(cicout));
    end

    // DUT
       // DUT
    top_cic_fir cic (.clk(clk), .reset(reset), .enable(enable),
                     .din(bits), .outready(outready), .cicout(cicout));

endmodule
