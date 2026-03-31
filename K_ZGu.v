module K_ZGu #(
  parameter integer WIDTH = 20,
  parameter integer CORDIC_ITER = 16,
  parameter integer DIFF_DELAY = CORDIC_ITER + 8
)(
  input  wire                         clk,
  input  wire signed [15:0] ori_x,
  input  wire signed [15:0] ori_y,
  input  wire signed [15:0] ori_z,
  input  wire signed [15:0] normalize_x,
  input  wire signed [15:0] normalize_y,
  input  wire signed [15:0] normalize_z,
  
  output wire signed [34:0]   K_ZGx,
  output wire signed [34:0]   K_ZGy,
  output wire signed [34:0]   K_ZGz
);
  
  integer i;

  wire [16:0] diff_x = ori_x - normalize_x;
  wire [16:0] diff_y = ori_y - normalize_y;
  wire [16:0] diff_z = ori_z - normalize_z;

  reg  [16:0] diff_x_r [0:DIFF_DELAY-1];
  reg  [16:0] diff_y_r [0:DIFF_DELAY-1];
  reg  [16:0] diff_z_r [0:DIFF_DELAY-1];

  always @(posedge clk) begin
    diff_x_r[0] <= diff_x;
    diff_y_r[0] <= diff_y;
    diff_z_r[0] <= diff_z;
    for (i=1; i<DIFF_DELAY; i=i+1) begin
      diff_x_r[i] <= diff_x_r[i-1];
      diff_y_r[i] <= diff_y_r[i-1];
      diff_z_r[i] <= diff_z_r[i-1];
    end
  end

  wire [16:0] cordic_x = diff_x[16]? (~diff_x+1): diff_x; // q16
  // wire [31:0] cordic_y =  { {15{diff_y[WIDTH]}}, diff_y }; // q16
  // wire [31:0] cordic_z =  { {15{diff_z[WIDTH]}}, diff_z }; // q16

  wire [31: 0] ro;
  CORDIC_Vector #( .WIDTH(WIDTH), .ITER(CORDIC_ITER)) cov(
    .clk       (clk),
    .Input_x   (cordic_x), // q16
    .Input_y   (diff_y),   // q16
    .Input_z   (diff_z),   // q16
    .Output_xn (ro)        // q16
  );

  wire signed [35:0] d1_q16;
  cubic_cov_d1 ccd (
    .clk(clk),
    .r_q32(ro),      // q16
    .ans_q32(d1_q16) // q32
  );
  
  wire signed [51:0] K_ZGx_temp;
  wire signed [51:0] K_ZGy_temp;
  wire signed [51:0] K_ZGz_temp;

  assign K_ZGx_temp = $signed(d1_q16) * $signed(diff_x_r[DIFF_DELAY-1]) >>> 16;
  assign K_ZGy_temp = $signed(d1_q16) * $signed(diff_y_r[DIFF_DELAY-1]) >>> 16;
  assign K_ZGz_temp = $signed(d1_q16) * $signed(diff_z_r[DIFF_DELAY-1]) >>> 16;

  assign K_ZGx = K_ZGx_temp;
  assign K_ZGy = K_ZGy_temp;
  assign K_ZGz = K_ZGz_temp;

endmodule

