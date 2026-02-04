module cubic_cov #(
  // a 的 Q16 表示，預設 a = 1.0
  // parameter signed [31:0] A_Q16 = 32'sd111411,
  parameter integer DATA_WIDTH = 16
  )(
    input wire clk,
    input wire [DATA_WIDTH-1:0] r_q16,

    output reg signed [31:0] ans_q16
  );

  // 係數皆為 Q16 = round(coef * 65536)
  localparam signed [31:0] C7 =  32'sd1198;   // 0.01828
  localparam signed [31:0] C5 = -32'sd16155;  // -0.2465
  localparam signed [31:0] C3 =  32'sd116719; // 1.78099
  localparam signed [31:0] C2 = -32'sd158738; // -2.42215
  localparam signed [31:0] C0 =  32'sd65536;  // 1.0

  // -------------------------
  // Signal Declarations
  // -------------------------

  // Stage 1 signals
  wire [DATA_WIDTH-1:0] r2_w;
  // wire [31:0] mul1_temp;
  reg  [DATA_WIDTH-1:0] r_s1, r2_s1;

  // Stage 2 signals
  wire signed [31:0] add2_w;
  wire signed [31:0] mul2_w;
  // wire signed [31:0] mul2_temp;
  reg  signed [31:0] add2_q;
  reg  [DATA_WIDTH-1:0] r_s2, r2_s2;

  // Stage 3 signals
  wire signed [31:0] add3_w;
  wire signed [31:0] mul3_w;
  reg  signed [31:0] add3_q;
  reg  [DATA_WIDTH-1:0] r_s3, r2_s3;

  // Stage 4 signals
  wire signed [31:0] add4_w;
  wire signed [31:0] mul4_w;
  reg  signed [31:0] add4_q;
  reg  [DATA_WIDTH-1:0] r2_s4;

  // Stage 5 signals
  wire signed [31:0] add5_w;
  wire signed [31:0] mul5_w;

  // reg  gt_s1; // (r > a)
  // reg                gt_s2;
  // reg                gt_s3;
  // reg                gt_s4;

  // -------------------------
  // Stage 1: r2 = r*r
  // -------------------------
  mul_q16 u_mul_r2 (.a(r_q16), .b(r_q16), .y(r2_w));
  // assign mul1_temp = r_q16 * r_q16;
  // assign r2_w = mul1_temp >>> 16;

  // -------------------------
  // Stage 2: s1 = C7*r2 + C5
  // -------------------------
  mul_q16 u_mul_t1 (.a(C7), .b(r2_s1), .y(mul2_w));
  assign add2_w = mul2_w + C5;

  // -------------------------
  // Stage 3: s2 = s1*r2 + C3
  // -------------------------
  mul_q16 u_mul_t2 (.a(add2_q), .b(r2_s2), .y(mul3_w));
  assign add3_w = mul3_w + C3;

  // -------------------------
  // Stage 4: s3 = s2*r + C2
  // -------------------------
  mul_q16 u_mul_t3 (.a(add3_q), .b(r_s3), .y(mul4_w));
  assign add4_w = mul4_w + C2;

  // -------------------------
  // Stage 5: s4 = s3*r2 + C0, then gate by gt
  // -------------------------
  mul_q16 u_mul_t4 (.a(add4_q), .b(r2_s4), .y(mul5_w));
  assign add5_w = mul5_w + C0;

  // -------------------------
  // Pipeline Registers
  // -------------------------
  always @(posedge clk) begin
    // Stage1 regs
    r_s1  <= r_q16;
    r2_s1 <= r2_w;
    // gt_s1 <= (r_q16 > A_Q16);

    // Stage2 regs
    r_s2  <= r_s1;
    r2_s2 <= r2_s1;
    add2_q <= add2_w;
    // gt_s2 <= gt_s1;

    // Stage3 regs
    r_s3  <= r_s2;
    r2_s3 <= r2_s2;
    add3_q <= add3_w;
    // gt_s3 <= gt_s2;

    // Stage4 regs
    r2_s4 <= r2_s3;
    add4_q <= add4_w;
    // gt_s4 <= gt_s3;

    // Stage5 regs
    // ans_q16 <= gt_s4 ? 32'sd0 : add5_w;
    ans_q16 <= add5_w;
  end

endmodule
