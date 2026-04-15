`timescale 1ns/1ps

module tb_capture_rgb;

    reg        pclk  = 0;
    reg        href  = 0;
    reg        vsync = 0;
    reg [7:0]  cam_d = 0;

    wire [15:0] pixel_data;
    wire        pixel_valid;
    wire [9:0]  pixel_x;
    wire [8:0]  pixel_y;

    wire [3:0] r, g, b;

    // PCLK 생성 (12MHz 가정)
    always #41 pclk = ~pclk;

    // capture 인스턴스
    ov7670_capture u_cap (
        .cam_pclk    (pclk),
        .reset       (1'b0),
        .cam_d       (cam_d),
        .cam_href    (href),
        .cam_vsync   (vsync),
        .pixel_data  (pixel_data),
        .pixel_valid (pixel_valid),
        .pixel_x     (pixel_x),
        .pixel_y     (pixel_y)
    );

    // rgb565→rgb444 인스턴스
    rgb565_to_rgb444 u_rgb (
        .rgb565 (pixel_data),
        .r (r),
        .g (g),
        .b (b)
    );

    task send_pixel;
        input [7:0] byte1;
        input [7:0] byte2;
        begin
            // 첫 번째 바이트
            @(posedge pclk);
            href  = 1;
            cam_d = byte1;

            // 두 번째 바이트
            @(posedge pclk);
            cam_d = byte2;

            @(posedge pclk);
            href = 0;
        end
    endtask

    initial begin
        // VSYNC로 프레임 시작
        vsync = 1; #200;
        vsync = 0; #200;

        $display("=== 순수 빨강 (0xF800) ===");
        send_pixel(8'hF8, 8'h00);
        #100;
        $display("pixel_data = %h (기대: F800)", pixel_data);
        $display("R=%h G=%h B=%h (기대: R=F G=0 B=0)", r, g, b);

        #100;
        $display("=== 순수 초록 (0x07E0) ===");
        send_pixel(8'h07, 8'hE0);
        #100;
        $display("pixel_data = %h (기대: 07E0)", pixel_data);
        $display("R=%h G=%h B=%h (기대: R=0 G=F B=0)", r, g, b);

        #100;
        $display("=== 순수 파랑 (0x001F) ===");
        send_pixel(8'h00, 8'h1F);
        #100;
        $display("pixel_data = %h (기대: 001F)", pixel_data);
        $display("R=%h G=%h B=%h (기대: R=0 G=0 B=F)", r, g, b);

        #200;
        $finish;
    end

endmodule