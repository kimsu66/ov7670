module ov7670_sccb_init(
    input  wire clk,
    input  wire reset,
    output wire cam_scl,
    inout  wire cam_sda,
    output reg  init_done
);

    localparam CLK_DIV = 250; // 약 200kHz 수준

    reg [15:0] div_cnt = 0;
    reg scl_int = 1'b1;
    reg tick = 1'b0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt <= 0;
            tick    <= 1'b0;
        end else begin
            if (div_cnt == CLK_DIV-1) begin
                div_cnt <= 0;
                tick    <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1'b1;
                tick    <= 1'b0;
            end
        end
    end

    reg sda_out = 1'b1;
    reg sda_oe  = 1'b0;

    assign cam_scl = scl_int;
    assign cam_sda = sda_oe ? sda_out : 1'bz;

    reg  [7:0] rom_addr;
    wire [15:0] rom_data;
    wire rom_last;

    ov7670_init_rom u_ov7670_init_rom (
        .addr (rom_addr),
        .data (rom_data),
        .last (rom_last)
    );

    localparam ST_BOOTWAIT  = 4'd0;
    localparam ST_LOAD      = 4'd1;
    localparam ST_START_0   = 4'd2;
    localparam ST_START_1   = 4'd3;
    localparam ST_SEND_BIT0 = 4'd4;
    localparam ST_SEND_BIT1 = 4'd5;
    localparam ST_ACK_0     = 4'd6;
    localparam ST_ACK_1     = 4'd7;
    localparam ST_STOP_0    = 4'd8;
    localparam ST_STOP_1    = 4'd9;
    localparam ST_NEXT      = 4'd10;
    localparam ST_DONE      = 4'd11;

    reg [3:0] state = ST_BOOTWAIT;

    reg [1:0] byte_index;
    reg [2:0] bit_index;
    reg [7:0] byte_data;
    reg [7:0] reg_addr_latched;
    reg [7:0] reg_data_latched;

    reg [23:0] boot_cnt = 24'd0;
    wire boot_done = (boot_cnt == 24'd999_999); // 약 10ms @100MHz

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            boot_cnt <= 24'd0;
        end else if (!boot_done) begin
            boot_cnt <= boot_cnt + 24'd1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= ST_BOOTWAIT;
            scl_int          <= 1'b1;
            sda_out          <= 1'b1;
            sda_oe           <= 1'b0;
            init_done        <= 1'b0;
            rom_addr         <= 8'd0;
            byte_index       <= 2'd0;
            bit_index        <= 3'd7;
            byte_data        <= 8'd0;
            reg_addr_latched <= 8'd0;
            reg_data_latched <= 8'd0;
        end else if (tick) begin
            case (state)
                ST_BOOTWAIT: begin
                    scl_int   <= 1'b1;
                    sda_out   <= 1'b1;
                    sda_oe    <= 1'b1;
                    init_done <= 1'b0;
                    if (boot_done)
                        state <= ST_LOAD;
                end

                ST_LOAD: begin
                    reg_addr_latched <= rom_data[15:8];
                    reg_data_latched <= rom_data[7:0];
                    byte_index       <= 2'd0;
                    state            <= ST_START_0;
                end

                ST_START_0: begin
                    scl_int <= 1'b1;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b1;
                    state   <= ST_START_1;
                end

                ST_START_1: begin
                    scl_int   <= 1'b1;
                    sda_oe    <= 1'b1;
                    sda_out   <= 1'b0;
                    bit_index <= 3'd7;
                    byte_data <= 8'h42; // OV7670 write address
                    state     <= ST_SEND_BIT0;
                end

                ST_SEND_BIT0: begin
                    scl_int <= 1'b0;
                    sda_oe  <= 1'b1;
                    sda_out <= byte_data[bit_index];
                    state   <= ST_SEND_BIT1;
                end

                ST_SEND_BIT1: begin
                    scl_int <= 1'b1;
                    if (bit_index == 0)
                        state <= ST_ACK_0;
                    else begin
                        bit_index <= bit_index - 3'd1;
                        state <= ST_SEND_BIT0;
                    end
                end

                ST_ACK_0: begin
                    scl_int <= 1'b0;
                    sda_oe  <= 1'b0; // release SDA
                    state   <= ST_ACK_1;
                end

                ST_ACK_1: begin
                    scl_int <= 1'b1;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;

                    if (byte_index == 2) begin
                        state <= ST_STOP_0;
                    end else begin
                        byte_index <= byte_index + 2'd1;
                        bit_index  <= 3'd7;

                        case (byte_index + 2'd1)
                            2'd1: byte_data <= reg_addr_latched;
                            2'd2: byte_data <= reg_data_latched;
                            default: byte_data <= 8'h00;
                        endcase

                        state <= ST_SEND_BIT0;
                    end
                end

                ST_STOP_0: begin
                    scl_int <= 1'b0;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;
                    state   <= ST_STOP_1;
                end

                ST_STOP_1: begin
                    scl_int <= 1'b1;
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b1;
                    state   <= ST_NEXT;
                end

                ST_NEXT: begin
                    if (rom_last) begin
                        init_done <= 1'b1;
                        state     <= ST_DONE;
                    end else begin
                        rom_addr <= rom_addr + 8'd1;
                        state    <= ST_LOAD;
                    end
                end

                ST_DONE: begin
                    scl_int   <= 1'b1;
                    sda_oe    <= 1'b1;
                    sda_out   <= 1'b1;
                    init_done <= 1'b1;
                end

                default: state <= ST_BOOTWAIT;
            endcase
        end
    end

endmodule