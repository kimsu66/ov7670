module rgb565_to_rgb444(
    input  [15:0] rgb565,
    output [3:0]  r,
    output [3:0]  g,
    output [3:0]  b
);

assign r = rgb565[15:12];
assign g = rgb565[10:7];
assign b = rgb565[4:1];

endmodule