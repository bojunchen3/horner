module mul_q16(
  input  wire signed [31:0] a,
  input  wire signed [31:0] b,  // Q16
  output wire signed [31:0] y   // Q16
);

  //localparam signed [63:0] HALF = 64'sd32768; // 2^15

  wire signed [63:0] prod = $signed(a) * $signed(b);
  
  // wire [31:0] round = (prod < 0)? 32767: 32768;

  // assign y = (prod + round) >>> 16;

  assign y = prod >>> 16;

  /*
  wire signed [63:0] abs_prod = (prod < 0) ? -prod : prod;

  // round-to-nearest (symmetric): (|prod| + 2^15) >> 16
  wire signed [63:0] q_abs = (abs_prod + HALF) >>> 16;

  assign y = (prod < 0) ? -$signed(q_abs[31:0]) : $signed(q_abs[31:0]);
  */

endmodule
