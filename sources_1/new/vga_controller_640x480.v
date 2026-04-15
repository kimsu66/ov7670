module vga_controller_640x480(
    input  wire       clk,
    input  wire       reset,
    output reg [9:0]  x,
    output reg [9:0]  y,
    output wire       hsync,
    output wire       vsync,
    output wire       active_video
);

    reg [9:0] h_count;
    reg [9:0] v_count;

    // 640x480 @ 60Hz, pixel clock 25MHz
    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = 10'd800;

    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = 10'd525;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            x <= 10'd0;
            y <= 10'd0;
        end else begin
            x <= h_count;
            y <= v_count;
        end
    end

    assign active_video = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign hsync = ~((h_count >= (H_VISIBLE + H_FRONT)) &&
                     (h_count <  (H_VISIBLE + H_FRONT + H_SYNC)));

    assign vsync = ~((v_count >= (V_VISIBLE + V_FRONT)) &&
                     (v_count <  (V_VISIBLE + V_FRONT + V_SYNC)));

endmodule