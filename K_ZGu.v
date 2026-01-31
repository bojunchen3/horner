module K_ZGu #(
  parameter integer DATA_WIDTH = 16
)(
  input  wire                        clk,
  input  wire                        rst_n,
  input  wire signed [DATA_WIDTH-1:0] ori_x,
  input  wire signed [DATA_WIDTH-1:0] ori_y,
  input  wire signed [DATA_WIDTH-1:0] ori_z,
  input  wire signed [DATA_WIDTH-1:0] normalize_x,
  input  wire signed [DATA_WIDTH-1:0] normalize_y,
  input  wire signed [DATA_WIDTH-1:0] normalize_z,
  
  output wire signed [31:0]          K_ZGx,
  output wire signed [31:0]          K_ZGy,
  output wire signed [31:0]          K_ZGz
);
  
  integer i;

  wire [DATA_WIDTH:0] diff_x = ori_x - normalize_x;
  wire [DATA_WIDTH:0] diff_y = ori_y - normalize_y;
  wire [DATA_WIDTH:0] diff_z = ori_z - normalize_z;

  reg  [DATA_WIDTH:0] diff_x_r [0:37];
  reg  [DATA_WIDTH:0] diff_y_r [0:37];
  reg  [DATA_WIDTH:0] diff_z_r [0:37];

  always @(posedge clk) begin
    diff_x_r[0] <= diff_x;
    diff_y_r[0] <= diff_y;
    diff_z_r[0] <= diff_z;
    for (i=1; i<38; i=i+1) begin
      diff_x_r[i] <= diff_x_r[i-1];
      diff_y_r[i] <= diff_y_r[i-1];
      diff_z_r[i] <= diff_z_r[i-1];
    end
  end

  wire [16:0] cordic_x = diff_x[16]? (~diff_x+1): diff_x; // q16
  wire [16:0] cordic_y = diff_y[16]? (~diff_y+1): diff_y; // q16
  wire [16:0] cordic_z = diff_z[16]? (~diff_z+1): diff_z; // q16

  wire [31: 0] ro;
  CORDIC_Vector cov (
    .clk       (clk),
    .RST_N     (rst_n),
    .Input_x   (cordic_x), // q16
    .Input_y   (cordic_y), // q16
    .Input_z   (cordic_z), // q16
    .Output_xn (ro) // q16
  );

  wire [31:0] d1_q16;
  cubic_cov_d1 ccd (
    .clk(clk),
    .rst_n(rst_n),
    .r_q16(ro), // q16
    .ans_q16(d1_q16) // q16
  );

  mul_q16 u_mul_x (.a($signed(d1_q16)), .b($signed(diff_x_r[37])), .y(K_ZGx));
  mul_q16 u_mul_y (.a($signed(d1_q16)), .b($signed(diff_y_r[37])), .y(K_ZGy));
  mul_q16 u_mul_z (.a($signed(d1_q16)), .b($signed(diff_z_r[37])), .y(K_ZGz));

endmodule