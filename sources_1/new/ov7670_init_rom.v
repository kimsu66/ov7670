module ov7670_init_rom(
    input  wire [7:0] addr,
    output reg [15:0] data,
    output reg        last
);

    always @(*) begin
        last = 1'b0;

        case (addr)
            8'd0:  data = 16'h1280; // COM7 reset
            8'd1:  data = 16'h1204; // COM7 = RGB
            8'd2:  data = 16'h1100; // CLKRC
            8'd3:  data = 16'h0C00; // COM3
            8'd4:  data = 16'h3E00; // COM14
            8'd5:  data = 16'h8C00; // RGB444 disable
            8'd6:  data = 16'h0400; // COM1
            8'd7:  data = 16'h4010; // COM15 full-range RGB
            8'd8:  data = 16'h3A04; // TSLB
            8'd9:  data = 16'h1400; // COM9
            8'd10: data = 16'h4F80;
            8'd11: data = 16'h5030;
            8'd12: data = 16'h5100;
            8'd13: data = 16'h5232;
            8'd14: data = 16'h535E;
            8'd15: data = 16'h5480;
            8'd16: data = 16'h589E;
            8'd17: data = 16'h3DC0; // COM13
            8'd18: data = 16'h1714; // HSTART
            8'd19: data = 16'h1842; // HSTOP
            8'd20: data = 16'h1903; // VSTART
            8'd21: data = 16'h1A7B; // VSTOP
            8'd22: data = 16'h3200; // HREF

            // QVGA scaling
            8'd23: data = 16'h703A; // SCALING_XSC
            8'd24: data = 16'h7135; // SCALING_YSC
            8'd25: data = 16'h7211; // SCALING_DCWCTR
            8'd26: data = 16'h73F0; // SCALING_PCLK_DIV
            8'd27: data = 16'hA202; // SCALING_PCLK_DELAY

            8'd28: data = 16'h1500; // COM10

            // test pattern on
            8'd29: data = 16'h70BA;
            8'd30: begin
                data = 16'h71B5;
                last = 1'b1;
            end

            default: begin
                data = 16'hFFFF;
                last = 1'b1;
            end
        endcase
    end

endmodule