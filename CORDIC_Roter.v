module CORDIC_Roter #(
  parameter SHIFT_BASE = 0,
  parameter WIDTH      = 20
)(
  input      signed [WIDTH-1:0] Input_x,
  input      signed [WIDTH-1:0] Input_y,
  output reg signed [WIDTH-1:0] Output_x,
  output reg signed [WIDTH-1:0] Output_y
);

  always @(*) begin
    if (!Input_y[WIDTH-1]) begin
      Output_x <= Input_x + (Input_y >>> SHIFT_BASE);
      Output_y <= Input_y - (Input_x >>> SHIFT_BASE);
    end
    else begin
      Output_x <= Input_x - (Input_y >>> SHIFT_BASE);
      Output_y <= Input_y + (Input_x >>> SHIFT_BASE);
    end
  end

endmodule
