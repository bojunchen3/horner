module K_Z #(
  parameter integer WIDTH = 19,
  parameter integer CORDIC_ITER = 16
)(
  input  wire               clk,
  input  wire signed [15:0] int_x,
  input  wire signed [15:0] int_y,
  input  wire signed [15:0] int_z,
  input  wire signed [15:0] normalize_x,
  input  wire signed [15:0] normalize_y,
  input  wire signed [15:0] normalize_z,
  output wire signed [34:0] K_Z_out
);

  wire [16:0] diff_x = normalize_x - int_x;
  wire [16:0] diff_y = normalize_y - int_y;
  wire [16:0] diff_z = normalize_z - int_z;

  wire [16:0] cordic_x = diff_x[16]? (~diff_x+1): diff_x; // q16
  // wire [31:0] cordic_y =  { {15{diff_y[WIDTH]}}, diff_y }; // q16
  // wire [31:0] cordic_z =  { {15{diff_z[WIDTH]}}, diff_z }; // q16

  wire [15: 0] ri;
  CORDIC_Vector #( .WIDTH(WIDTH), .ITER(CORDIC_ITER)) cov(
    .clk       (clk),
    .Input_x   (cordic_x), // q16
    .Input_y   (diff_y),   // q16
    .Input_z   (diff_z),   // q16
    .Output_xn (ri)        // q16
  );

  cubic_cov cc (
    .clk(clk),
    .r_q16(ri),
    .ans_q16(K_Z_out) // q32
  );

endmodule
