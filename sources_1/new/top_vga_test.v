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

    wire clk_24m;   // → cam_xclk
    wire clk_vga;   // → vga_controller (25.175MHz)
    wire pll_locked;

    wire [9:0] x;
    wire [9:0] y;
    wire active_video;

    wire cam_init_done;

    wire [15:0] cap_pixel_data;
    wire        cap_pixel_valid;
    wire [9:0]  cap_pixel_x;
    wire [8:0]  cap_pixel_y;

    wire [3:0]  cam_r;
    wire [3:0]  cam_g;
    wire [3:0]  cam_b;

    wire [15:0] fb_pixel;
    wire [15:0] display_pixel;

    // ---------------------------------------------
    // Clocking Wizard: 100MHz → 24MHz, 25.175MHz
    // Vivado IP: clk_wiz_0
    //   clk_out1 = 24MHz     (cam_xclk)
    //   clk_out2 = 25.175MHz (VGA pixel clock)
    // ---------------------------------------------
    clk_wiz_0 u_clk_wiz (
        .clk_in1  (clk),
        .reset    (1'b0),
        .locked   (pll_locked),
        .clk_out1 (clk_24m),
        .clk_out2 (clk_vga)
    );

    // ---------------------------------------------
    // VGA timing generator
    // ---------------------------------------------
    vga_controller_640x480 u_vga_controller (
        .clk          (clk_vga),
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
    assign cam_xclk = clk_24m;
    assign cam_pwdn = 1'b0;

    // ---------------------------------------------
    // Downsample (320x240 → 160x120)
    // ---------------------------------------------

    // downsample: 짝수 픽셀만 사용 (160x120)
    wire wr_en_ds = cap_pixel_valid & ~cap_pixel_x[0] & ~cap_pixel_y[0];

    // x/2, y/2
    wire [7:0] ds_x = cap_pixel_x[9:1];   // 0~159
    wire [6:0] ds_y = cap_pixel_y[8:1];   // 0~119

    // addr = y*160 + x = (y<<7) + (y<<5) + x
    wire [14:0] wr_addr =
        (ds_y << 7) + (ds_y << 5) + ds_x;

    //---------------------------------------------
    // VGA read address (4배 확대)
    //---------------------------------------------
    wire [7:0] rd_x = x[9:2];  // /4
    wire [6:0] rd_y = y[8:2];  // /4

    wire [14:0] rd_addr =
        (rd_y << 7) + (rd_y << 5) + rd_x;

    //---------------------------------------------
    // Framebuffer
    //---------------------------------------------
    frame_buffer_dp u_fb (
        .wr_clk  (cam_pclk),
        .wr_en   (wr_en_ds),
        .wr_addr (wr_addr),
        .wr_data (cap_pixel_data),

        .rd_clk  (clk_vga),
        .rd_addr (rd_addr),
        .rd_data (fb_pixel)
    );

    //---------------------------------------------
    // Framebuffer → display 연결
    //---------------------------------------------
    assign display_pixel = fb_pixel;

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