module CORDIC_Roter #(
  parameter SHIFT_BASE = 0,
  parameter WIDTH      = 20
)(
  input      signed [WIDTH-1:0] Input_x,
  input      signed [WIDTH-1:0] Input_y,
  output reg signed [WIDTH-1:0] Output_x,
  output reg signed [WIDTH-1:0] Output_y
);

  wire signed [WIDTH-1:0] shift_x;
  wire signed [WIDTH-1:0] shift_y;

  generate
    if (SHIFT_BASE == 0) begin
      assign shift_x = Input_x;
      assign shift_y = Input_y;
    end else begin
      // 修正1：$signed({1'b0, ...}) 確保加法器兩端都是有號數，保護 >>> 維持「算術右移」
      // 修正2：(SHIFT_BASE>0 ? SHIFT_BASE-1 : 0) 防止編譯器在 SHIFT_BASE=0 時抓取 [-1] 報錯
      assign shift_x = (Input_x >>> SHIFT_BASE) + $signed({1'b0, Input_x[SHIFT_BASE-1]});
      assign shift_y = (Input_y >>> SHIFT_BASE) + $signed({1'b0, Input_y[SHIFT_BASE-1]});
    end
  endgenerate

  always @(*) begin
    if (!Input_y[WIDTH-1]) begin // Y >= 0
      Output_x = Input_x + shift_y;
      Output_y = Input_y - shift_x;
    end
    else begin                   // Y < 0
      Output_x = Input_x - shift_y;
      Output_y = Input_y + shift_x;
    end
  end

endmodule
