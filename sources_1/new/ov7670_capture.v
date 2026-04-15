module ov7670_capture(
    input  wire       cam_pclk,
    input  wire       reset,
    input  wire [7:0] cam_d,
    input  wire       cam_href,
    input  wire       cam_vsync,

    output reg [15:0] pixel_data,
    output reg        pixel_valid,
    output reg [9:0]  pixel_x,
    output reg [8:0]  pixel_y
);

    reg        byte_phase;
    reg [7:0]  byte_high;

    always @(posedge cam_pclk or posedge reset) begin
        if (reset) begin
            byte_phase <= 1'b0;
            byte_high  <= 8'd0;
            pixel_data <= 16'd0;
            pixel_valid <= 1'b0;
            pixel_x <= 10'd0;
            pixel_y <= 9'd0;
        end else begin
            pixel_valid <= 1'b0;

            if (cam_vsync) begin
                // frame start
                byte_phase <= 1'b0;
                pixel_x    <= 10'd0;
                pixel_y    <= 9'd0;
            end
            else if (cam_href) begin
                if (byte_phase == 1'b0) begin
                    // first byte
                    byte_high  <= cam_d;
                    byte_phase <= 1'b1;
                end else begin
                    // second byte -> complete pixel
                    pixel_data  <= {byte_high, cam_d};
                    pixel_valid <= 1'b1;
                    byte_phase  <= 1'b0;

                    if (pixel_x == 10'd319) begin
                        pixel_x <= 10'd0;
                        if (pixel_y == 9'd239)
                            pixel_y <= 9'd0;
                        else
                            pixel_y <= pixel_y + 9'd1;
                    end else begin
                        pixel_x <= pixel_x + 10'd1;
                    end
                end
            end
            else begin
                // line blank
                byte_phase <= 1'b0;
            end
        end
    end

endmodule