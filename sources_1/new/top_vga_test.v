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
    wire cam_rst_n;

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
        .cam_rst_n (cam_rst_n),
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
    assign cam_rst  = cam_rst_n;  // SCCB 모듈이 부팅 시 10ms 동안 LOW 유지 후 해제
    assign cam_xclk = clk_24m;
    assign cam_pwdn = 1'b0;

    // ---------------------------------------------
    // Write address: 320x240 그대로 저장
    // addr = y*320 + x = (y<<8) + (y<<6) + x
    // ---------------------------------------------
    wire [8:0] wr_x = cap_pixel_x[8:0];  // 0~319
    wire [7:0] wr_y = cap_pixel_y[7:0];  // 0~239

    wire [16:0] wr_addr =
        ({9'd0, wr_y} << 8) + ({9'd0, wr_y} << 6) + {8'd0, wr_x};

    //---------------------------------------------
    // VGA read address (1:1, 좌상단 320x240만 표시)
    //---------------------------------------------
    wire in_range = (x < 320) && (y < 240);

    wire [8:0] rd_x = x[8:0];   // 0~319
    wire [7:0] rd_y = y[7:0];   // 0~239

    wire [16:0] rd_addr =
        ({9'd0, rd_y} << 8) + ({9'd0, rd_y} << 6) + {8'd0, rd_x};

    //---------------------------------------------
    // Framebuffer
    //---------------------------------------------
    frame_buffer_dp u_fb (
        .wr_clk  (cam_pclk),
        .wr_en   (cap_pixel_valid),
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
 
    // VGA output (320x240 영역만 표시, 나머지 검정)
    assign vgaRed   = (active_video && in_range) ? cam_r : 4'd0;
    assign vgaGreen = (active_video && in_range) ? cam_g : 4'd0;
    assign vgaBlue  = (active_video && in_range) ? cam_b : 4'd0;

    // debug LEDs 
    assign led[0] = cam_pclk;
    assign led[1] = cam_vsync;
    assign led[2] = cam_init_done;

endmodule