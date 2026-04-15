module clock_divider(
    input  wire clk_in,
    input  wire reset,
    output reg  clk_25m
);

    reg [1:0] cnt;

    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            cnt     <= 2'd0;
            clk_25m <= 1'b0;
        end else begin
            cnt <= cnt + 2'd1;

            case (cnt)
                2'd1: clk_25m <= 1'b1;
                2'd3: clk_25m <= 1'b0;
            endcase
        end
    end

endmodule