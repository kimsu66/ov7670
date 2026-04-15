`timescale 1ns / 1ps

// Clocking Wizard (MMCME2_BASE)
// Input  : 100MHz
// clk_out1 : 24.000MHz  → cam_xclk  (600 / 25   = 24.000)
// clk_out2 : 25.000MHz  → VGA pixel (600 / 24   = 25.000, ≈25.175MHz)
// VCO      : 100 * 6    = 600MHz

module clk_wiz_0 (
    input  wire clk_in1,
    input  wire reset,
    output wire locked,
    output wire clk_out1,   // 24MHz  → cam_xclk
    output wire clk_out2    // 25MHz  → VGA pixel clock
);

    wire clkfb;
    wire clkout0_raw;
    wire clkout1_raw;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (6.000),    // VCO = 100 * 6 = 600MHz
        .CLKFBOUT_PHASE     (0.0),
        .CLKIN1_PERIOD      (10.0),     // 100MHz → 10ns
        .DIVCLK_DIVIDE      (1),

        // clk_out1: 24MHz  (600 / 25 = 24.000MHz)
        .CLKOUT0_DIVIDE_F   (25.000),
        .CLKOUT0_DUTY_CYCLE (0.5),
        .CLKOUT0_PHASE      (0.0),

        // clk_out2: 25MHz  (600 / 24 = 25.000MHz)
        .CLKOUT1_DIVIDE     (24),
        .CLKOUT1_DUTY_CYCLE (0.5),
        .CLKOUT1_PHASE      (0.0),

        .CLKOUT2_DIVIDE     (1),
        .CLKOUT3_DIVIDE     (1),
        .CLKOUT4_DIVIDE     (1),
        .CLKOUT5_DIVIDE     (1),
        .CLKOUT6_DIVIDE     (1),

        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) u_mmcm (
        .CLKIN1    (clk_in1),
        .CLKFBIN   (clkfb),
        .RST       (reset),
        .PWRDWN    (1'b0),

        .CLKOUT0   (clkout0_raw),
        .CLKOUT0B  (),
        .CLKOUT1   (clkout1_raw),
        .CLKOUT1B  (),
        .CLKOUT2   (),
        .CLKOUT2B  (),
        .CLKOUT3   (),
        .CLKOUT3B  (),
        .CLKOUT4   (),
        .CLKOUT5   (),
        .CLKOUT6   (),

        .CLKFBOUT  (clkfb),
        .CLKFBOUTB (),
        .LOCKED    (locked)
    );

    // 글로벌 클럭 버퍼
    BUFG u_buf_out1 (.I(clkout0_raw), .O(clk_out1));
    BUFG u_buf_out2 (.I(clkout1_raw), .O(clk_out2));

endmodule
