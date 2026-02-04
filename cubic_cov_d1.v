module cubic_cov_d1 #(
  // a 的 Q16 表示，預設 a = 1.0
  // parameter signed  [31:0] A_Q16 = 32'sd111411,
  parameter integer DATA_WIDTH = 16
)(
    input wire                  clk,
    input wire [DATA_WIDTH-1:0] r_q16,

    output reg [31:0]           ans_q16
);

  // 係數皆為 Q16 = round(coef * 65536)
  localparam signed [31:0] C5 =  32'sd8385;   //  0.12794
  localparam signed [31:0] C3 = -32'sd80774;  // -1.23252
  localparam signed [31:0] C1 =  32'sd350157; //  5.34297
  localparam signed [31:0] C0 = -32'sd317475; // -4.84429

  // -------------------------
  // Signal Declarations
  // -------------------------

  // Stage 1 signals
  wire [DATA_WIDTH-1:0] r2_w;
  reg  [DATA_WIDTH-1:0] r_s1, r2_s1;

  // Stage 2 signals
  wire signed [31:0] mul2_w, add2_w;
  reg  signed [31:0] add2_q;
  reg  [DATA_WIDTH-1:0] r_s2, r2_s2;

  // Stage 3 signals
  wire signed [31:0] mul3_w, add3_w;
  reg  signed [31:0] add3_q;
  reg  [DATA_WIDTH-1:0] r_s3;

  // Stage 4 signals
  wire signed [31:0] mul4_w, add4_w;

  // reg                gt_s1; // (r > a)
  // reg                gt_s2;
  // reg                gt_s3;

  // -------------------------
  // Stage 1: r2 = r*r
  // -------------------------
  mul_q16 u_mul_r2 (.a(r_q16), .b(r_q16), .y(r2_w));

  // -------------------------
  // Stage 2: s1 = C7*r2 + C5
  // -------------------------
  mul_q16 u_mul_t1 (.a(C5), .b(r2_s1), .y(mul2_w));
  assign add2_w = mul2_w + C3;

  // -------------------------
  // Stage 3: s2 = s1*r2 + C3
  // -------------------------
  mul_q16 u_mul_t2 (.a(add2_q), .b(r2_s2), .y(mul3_w));
  assign add3_w = mul3_w + C1;

  // -------------------------
  // Stage 4: s3 = s2*r + C2
  // -------------------------
  mul_q16 u_mul_t3 (.a(add3_q), .b(r_s3), .y(mul4_w));
  assign add4_w = mul4_w + C0;

  // -------------------------
  // Pipeline Registers
  // -------------------------
  always @(posedge clk) begin
    // Stage1 regs
    r_s1  <= r_q16;
    r2_s1 <= r2_w;
    // gt_s1 <= (r_q16 > A_Q16);

    // Stage2 regs
    r_s2   <= r_s1;
    r2_s2  <= r2_s1;
    add2_q <= add2_w;
    // gt_s2  <= gt_s1;

    // Stage3 regs
    r_s3   <= r_s2;
    add3_q <= add3_w;
    // gt_s3  <= gt_s2;

    // Stage4 regs
    // ans_q16 <= gt_s3 ? 32'sd0 : add4_w;
    ans_q16 <= add4_w;
  end

endmodule
