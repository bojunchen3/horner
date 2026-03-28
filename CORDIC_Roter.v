module CORDIC_Roter #(
  parameter SHIFT_BASE = 0,
  parameter WIDTH      = 18
)(
  input      signed [WIDTH-1:0] Input_x_n_1,
  input      signed [WIDTH-1:0] Input_y_n_1,
  input      signed [WIDTH-1:0] Input_z_n_1,
  output reg signed [WIDTH-1:0] Output_x_n,
  output reg signed [WIDTH-1:0] Output_y_n,
  output reg signed [WIDTH-1:0] Output_z_n
);

  always @(*) begin
    if (!Input_y_n_1[WIDTH-1]) begin
      Output_x_n <= Input_x_n_1 + (Input_y_n_1 >>> SHIFT_BASE);
      Output_y_n <= Input_y_n_1 - (Input_x_n_1 >>> SHIFT_BASE);
    end
    else begin
      Output_x_n <= Input_x_n_1 - (Input_y_n_1 >>> SHIFT_BASE);
      Output_y_n <= Input_y_n_1 + (Input_x_n_1 >>> SHIFT_BASE);
    end
    Output_z_n <= Input_z_n_1;
  end
endmodule
