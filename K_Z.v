module K_Z #(
  parameter integer DATA_WIDTH = 16
)(
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire signed [DATA_WIDTH-1:0] int_x,
  input  wire signed [DATA_WIDTH-1:0] int_y,
  input  wire signed [DATA_WIDTH-1:0] int_z,
  input  wire signed [DATA_WIDTH-1:0] normalize_x,
  input  wire signed [DATA_WIDTH-1:0] normalize_y,
  input  wire signed [DATA_WIDTH-1:0] normalize_z,
  output wire signed [31:0]           K_Z_out
);

  wire [DATA_WIDTH:0] diff_x = normalize_x - int_x;
  wire [DATA_WIDTH:0] diff_y = normalize_y - int_y;
  wire [DATA_WIDTH:0] diff_z = normalize_z - int_z;

  wire [16:0] cordic_x = diff_x[16]? (~diff_x+1): diff_x; // q16
  wire [16:0] cordic_y = diff_y[16]? (~diff_y+1): diff_y; // q16
  wire [16:0] cordic_z = diff_z[16]? (~diff_z+1): diff_z; // q16

  wire [31: 0] ri;
  CORDIC_Vector cov (
    .clk       (clk),
    .RST_N     (rst_n),
    .Input_x   (cordic_x), // q16
    .Input_y   (cordic_y), // q16
    .Input_z   (cordic_z), // q16
    .Output_xn (ri) // q16
  );

  cubic_cov cc (
    .clk(clk),
    .rst_n(rst_n),
    .r_q16(ri),
    .ans_q16(K_Z_out)
  );

endmodule
