`timescale 1ns/1ps

module tb_sccb;

    reg clk  = 0;
    reg reset = 0;
    always #5 clk = ~clk; // 100MHz

    wire cam_scl;
    wire cam_rst_n;
    wire init_done;
    wire cam_sda;

    // SDA 풀업
    assign (weak1, highz0) cam_sda = 1'b1;

    ov7670_sccb_init u_sccb (
        .clk       (clk),
        .reset     (reset),
        .cam_scl   (cam_scl),
        .cam_sda   (cam_sda),
        .cam_rst_n (cam_rst_n),
        .init_done (init_done)
    );

    initial begin
        $dumpfile("tb_sccb.vcd");
        $dumpvars(0, tb_sccb);

        // 리셋으로 X 제거
        reset = 1;
        #100;
        reset = 0;

        // boot_cnt를 9로 줄였으니까 금방 지나감
        // SCL 토글 구간까지 대기
        #3_000_000;

        $display("init_done = %b (기대: 1)", init_done);
        $display("cam_rst_n = %b (기대: 1)", cam_rst_n);
        $finish;
    end

    // SCL 엣지마다 SDA 찍기
    always @(posedge cam_scl) begin
        $display("t=%0t SCL↑ SDA=%b rst_n=%b done=%b",
                  $time, cam_sda, cam_rst_n, init_done);
    end

    // init_done 변화 감지
    always @(posedge init_done) begin
        $display("t=%0t ★ init_done 완료!", $time);
    end
    
    always @(negedge cam_scl) begin
        $display("t=%0t SCL↓ SDA=%b state=%0d",
                  $time, cam_sda, u_sccb.state);
    end

    always @(posedge cam_scl) begin
        $display("t=%0t SCL↑ SDA=%b state=%0d",
                  $time, cam_sda, u_sccb.state);
    end
endmodule