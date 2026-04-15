module ov7670_init_rom(
    input  wire [7:0] addr,
    output reg [15:0] data,
    output reg        last
);

    always @(*) begin
        last = 1'b0;

        case (addr)
            // ─── 1. 소프트 리셋 ───────────────────────────────
            8'd0:  data = 16'h1280; // COM7  = 0x80 : 전체 레지스터 리셋

            // ─── 2. 출력 포맷 ─────────────────────────────────
            8'd1:  data = 16'h1204; // COM7  = 0x04 : RGB 모드
            8'd2:  data = 16'h8C00; // RGB444= 0x00 : RGB444 비활성
            8'd3:  data = 16'h40D0; // COM15 = 0xD0 : RGB565, 풀레인지 [00]~[FF]
            8'd4:  data = 16'h3A04; // TSLB  = 0x04 : YUYV 순서, 자동 윈도우
            8'd5:  data = 16'h0400; // COM1  = 0x00 : CCIR656 비활성

            // ─── 3. 클럭 설정 ─────────────────────────────────
            8'd6:  data = 16'h1100; // CLKRC = 0x00 : 프리스케일 없음
            8'd7:  data = 16'h3E19; // COM14 = 0x19 : DCW/스케일 PCLK 활성, PCLK /2
            8'd8:  data = 16'h7308; // SCALING_PCLK_DIV = 0x08 : 클럭 분주 bypass
            8'd9:  data = 16'hA202; // SCALING_PCLK_DELAY = 0x02 : 픽셀클럭 딜레이

            // ─── 4. 스케일링 (QVGA) ───────────────────────────
            8'd10: data = 16'h0C04; // COM3  = 0x04 : DCW 활성
            8'd11: data = 16'h703A; // SCALING_XSC  = 0x3A : 수평 스케일 팩터
            8'd12: data = 16'h7135; // SCALING_YSC  = 0x35 : 수직 스케일 팩터
            8'd13: data = 16'h7211; // SCALING_DCWCTR = 0x11 : 수직/수평 1/2 다운샘플

            // ─── 5. 윈도우 / 타이밍 ───────────────────────────
            8'd14: data = 16'h1714; // HSTART = 0x14
            8'd15: data = 16'h1842; // HSTOP  = 0x42
            8'd16: data = 16'h1903; // VSTRT  = 0x03
            8'd17: data = 16'h1A7B; // VSTOP  = 0x7B
            8'd18: data = 16'h3200; // HREF   = 0x00 : 오프셋 없음
            8'd19: data = 16'h1500; // COM10  = 0x00 : VSYNC/PCLK/HREF 기본 극성

            // ─── 6. 화질 설정 ─────────────────────────────────
            8'd20: data = 16'h1400; // COM9  = 0x00 : AGC ceiling 2x
            8'd21: data = 16'h3DC0; // COM13 = 0xC0 : 감마 활성, UV 자동조정
            8'd22: data = 16'h4F80; // MTX1
            8'd23: data = 16'h5030; // MTX2
            8'd24: data = 16'h5100; // MTX3
            8'd25: data = 16'h5232; // MTX4
            8'd26: data = 16'h535E; // MTX5
            8'd27: data = 16'h5480; // MTX6
            8'd28: data = 16'h589E; // MTXS  = 0x9E : 매트릭스 부호 + 자동 contrast

            default: begin
                data = 16'hFFFF;
                last = 1'b1;
            end
        endcase
    end

endmodule