module ov7670_sccb_init(
    input  wire clk,
    input  wire reset,
    output wire cam_scl,
    inout  wire cam_sda,
    output reg  cam_rst_n,   // 추가: active-LOW 하드웨어 리셋
    output reg  init_done
);

    localparam CLK_DIV = 250; // tick rate = 100MHz / 250 = 400kHz

    reg [15:0] div_cnt = 0;
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
    reg scl_int = 1'b1;

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

    localparam ST_BOOTWAIT   = 4'd0;
    localparam ST_LOAD       = 4'd1;
    localparam ST_START_0    = 4'd2;
    localparam ST_START_1    = 4'd3;
    // [수정] START 조건 후 SCL을 내리는 단계 추가
    // 기존에는 START_1에서 바로 SEND_BIT0으로 가서
    // SCL↑ 구간에 SDA=0(START)이 첫 비트로 잡혀 슬레이브 주소가 1비트 밀렸음
    localparam ST_START_2    = 4'd13; // [수정] SCL 내리는 단계
    localparam ST_SEND_BIT0  = 4'd4;
    localparam ST_SEND_BIT1  = 4'd5;
    localparam ST_ACK_0      = 4'd6;
    localparam ST_ACK_1      = 4'd7;
    localparam ST_STOP_0     = 4'd8;
    localparam ST_STOP_1     = 4'd9;
    localparam ST_NEXT       = 4'd10;
    localparam ST_DONE       = 4'd11;
    localparam ST_SWRST_WAIT = 4'd12; // 소프트 리셋 후 대기

    reg [3:0] state = ST_BOOTWAIT;

    reg [1:0] byte_index;
    reg [2:0] bit_index;
    reg [7:0] byte_data;
    reg [7:0] reg_addr_latched;
    reg [7:0] reg_data_latched;

    // ── 부팅 대기 : 10ms (하드웨어 리셋 유지) ───────────────────────
    reg [23:0] boot_cnt = 24'd0;
    wire boot_done = (boot_cnt == 24'd999_999);
    // wire boot_done = (boot_cnt == 24'd9);

    always @(posedge clk or posedge reset) begin
        if (reset)
            boot_cnt <= 24'd0;
        else if (!boot_done)
            boot_cnt <= boot_cnt + 24'd1;
    end

    // ── 소프트 리셋 후 대기 : 5ms (400kHz tick 기준 2000 tick) ──────
    reg [11:0] swrst_cnt;
    localparam SWRST_WAIT = 12'd1999;
    // localparam SWRST_WAIT = 12'd4;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= ST_BOOTWAIT;
            scl_int          <= 1'b1;
            sda_out          <= 1'b1;
            sda_oe           <= 1'b0;
            cam_rst_n        <= 1'b0;  // 리셋 시작 시 카메라 하드웨어 리셋 assert
            init_done        <= 1'b0;
            rom_addr         <= 8'd0;
            byte_index       <= 2'd0;
            bit_index        <= 3'd7;
            byte_data        <= 8'd0;
            reg_addr_latched <= 8'd0;
            reg_data_latched <= 8'd0;
            swrst_cnt        <= 12'd0;
        end else if (tick) begin
            case (state)

                ST_BOOTWAIT: begin
                    // cam_rst_n = 0 유지 → 카메라 하드웨어 리셋 중
                    scl_int   <= 1'b1;
                    sda_out   <= 1'b1;
                    sda_oe    <= 1'b1;
                    init_done <= 1'b0;
                    if (boot_done) begin
                        cam_rst_n <= 1'b1; // 하드웨어 리셋 해제
                        state     <= ST_LOAD;
                    end
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
                    scl_int <= 1'b1;   // SCL 반드시 HIGH 유지 (START: SCL=H일 때 SDA 하강)
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;   // SDA만 LOW로 → START 조건 성립
                    state   <= ST_START_2;
                end
 
                // [수정] START 후 SCL을 내리고 나서 데이터 전송 시작
                // 이전: START_1에서 바로 SEND_BIT0으로 가서 슬레이브 주소 1비트 밀림
                // 수정: SCL=0으로 내린 후 bit_index/byte_data 세팅하고 전송 시작
                ST_START_2: begin
                    scl_int   <= 1'b0;    // SCL 내림
                    bit_index <= 3'd7;
                    byte_data <= 8'h42;   // OV7670 write address
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
                        state     <= ST_SEND_BIT0;
                    end
                end

                ST_ACK_0: begin
                    scl_int <= 1'b0;
                    sda_oe  <= 1'b0; // SDA 해제 (카메라가 ACK)
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
                    end else if (rom_addr == 8'd0) begin
                        // 소프트 리셋 직후 → 5ms 대기
                        swrst_cnt <= 12'd0;
                        state     <= ST_SWRST_WAIT;
                    end else begin
                        rom_addr <= rom_addr + 8'd1;
                        state    <= ST_LOAD;
                    end
                end

                ST_SWRST_WAIT: begin
                    if (swrst_cnt == SWRST_WAIT) begin
                        rom_addr <= rom_addr + 8'd1;
                        state    <= ST_LOAD;
                    end else begin
                        swrst_cnt <= swrst_cnt + 12'd1;
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
