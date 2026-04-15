module frame_buffer_dp(
    // write side (camera domain)
    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire [16:0] wr_addr,   // 320*240 = 76800 < 2^17
    input  wire [15:0] wr_data,

    // read side (VGA domain)
    input  wire        rd_clk,
    input  wire [16:0] rd_addr,
    output reg  [15:0] rd_data
);

    reg [15:0] mem [0:76799];

    // write
    always @(posedge wr_clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    // read
    always @(posedge rd_clk) begin
        rd_data <= mem[rd_addr];
    end

endmodule