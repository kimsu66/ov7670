module top_vga_test(
    input        clk,

    // OV7670 ports
    input  [7:0] cam_d,
    input        cam_vsync,
    input        cam_pclk,
    input        cam_href,
    output       cam_scl,
    inout        cam_sda,
    output       cam_rst,
    output       cam_xclk,
    output       cam_pwdn,

    //test
    output [2:0] led,

    // VGA
    output [3:0] vgaRed,
    output [3:0] vgaGreen,
    output [3:0] vgaBlue,
    output       Hsync,
    output       Vsync
);

    wire clk_25m;
    wire [9:0] x;
    wire [9:0] y;
    wire active_video;
    wire cam_init_done;

    wire [15:0] cap_pixel_data;
    wire        cap_pixel_valid;
    wire [9:0]  cap_pixel_x;
    wire [8:0]  cap_pixel_y;

    wire [3:0] cam_r;
    wire [3:0] cam_g;
    wire [3:0] cam_b;

    // 마지막으로 잡힌 픽셀을 VGA쪽에서 그냥 계속 보여주기 위한 레지스터
    // 완전한 CDC 처리는 아니지만, 직결 테스트용으로는 충분
    reg [15:0] display_pixel = 16'h0000;

    // ---------------------------------------------
    // 100MHz -> 25MHz
    // ---------------------------------------------
    clock_divider u_clock_divider (
        .clk_in  (clk),
        .reset   (1'b0),
        .clk_25m (clk_25m)
    );

    // ---------------------------------------------
    // VGA timing generator
    // ---------------------------------------------
    vga_controller_640x480 u_vga_controller (
        .clk          (clk_25m),
        .reset        (1'b0),
        .x            (x),
        .y            (y),
        .hsync        (Hsync),
        .vsync        (Vsync),
        .active_video (active_video)
    );

    // ---------------------------------------------    
    // OV7670 SCCb init : scl, sda -> SCCb module output으로
    // ---------------------------------------------
    ov7670_sccb_init u_ov7670_sccb_init (
        .clk       (clk),
        .reset     (1'b0),
        .cam_scl   (cam_scl),
        .cam_sda   (cam_sda),
        .init_done (cam_init_done)
    );

    // ---------------------------------------------
    // OV7670 capture
    // ---------------------------------------------
    ov7670_capture u_ov7670_capture (
        .cam_pclk    (cam_pclk),
        .reset       (1'b0),   // 1'b0 → ~cam_init_done
        .cam_d       (cam_d),
        .cam_href    (cam_href),
        .cam_vsync   (cam_vsync),
        .pixel_data  (cap_pixel_data),
        .pixel_valid (cap_pixel_valid),
        .pixel_x     (cap_pixel_x),
        .pixel_y     (cap_pixel_y)
    );

    //---------------------------------------------
    // Camera control
    //---------------------------------------------
    assign cam_rst  = 1'b1;
    assign cam_xclk = clk_25m;
    assign cam_pwdn = 1'b0;

    //---------------------------------------------
    // 마지막 유효 픽셀 보관
    //---------------------------------------------
    always @(posedge cam_pclk) begin
        if (cap_pixel_valid)
            display_pixel <= cap_pixel_data;
    end

    //---------------------------------------------
    // RGB565 -> RGB444
    //---------------------------------------------
    rgb565_to_rgb444 u_rgb (
        .rgb565(display_pixel),
        .r(cam_r),
        .g(cam_g),
        .b(cam_b)
    );
 
    // VGA output
    assign vgaRed   = active_video ? cam_r : 4'd0;
    assign vgaGreen = active_video ? cam_g : 4'd0;
    assign vgaBlue  = active_video ? cam_b : 4'd0;

    // debug LEDs 
    assign led[0] = cam_pclk;
    assign led[1] = cam_vsync;
    assign led[2] = cam_init_done;

endmodule