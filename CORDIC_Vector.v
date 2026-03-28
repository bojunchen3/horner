module CORDIC_Vector #(
  parameter WIDTH = 18,
  parameter ITER = 12
)(
  input              clk,
  input  [16:0] Input_x,
  input  [16:0] Input_y,
  input  [16:0] Input_z,
  output [15:0] Output_xn
);
  
  parameter K = 16'h9b75;  //K=0.607253*2^16,32'h09b74
  
  reg signed [15:0] Output_xn;
  
  reg signed [16:0] x_00,y_00,z_00;
  
  always @ (posedge clk) begin
    x_00 <= Input_x;
    y_00 <= Input_y;
    z_00 <= Input_z;
  end
  
  reg  signed [WIDTH-1:0]       x[0: ITER-1];
  reg  signed [WIDTH-1:0]       y[0: ITER/2-1];
  reg  signed [WIDTH-1:0]       z[0: ITER-1];
  wire signed [WIDTH-1:0]   x_mid[0: ITER-1];
  wire signed [WIDTH-1:0]   y_mid[0: ITER/2-1];
  wire signed [WIDTH-1:0]   z_mid[0: ITER-1];
  wire signed [WIDTH-1:0]  x_next[0: ITER-1];
  wire signed [WIDTH-1:0]  y_next[0: ITER/2-1];
  wire signed [WIDTH-1:0]  z_next[0: ITER-1];
  reg  signed [WIDTH-1:0]  z_7_delay;
  reg  signed [WIDTH+15:0] x_temp;
  reg  signed [WIDTH+15:0] output_temp;

  //--- generate operation pipeline --- 
  generate
    genvar i;
    for (i = 0; i < ITER; i = i + 1) begin: roter    
      if (i == 0) 
        CORDIC_Roter #(.SHIFT_BASE(i), .WIDTH(WIDTH))
          rote00 ( .Input_x_n_1(x_00),      .Input_y_n_1(y_00),      .Input_z_n_1(z_00),
                   .Output_x_n(x_mid[i]), .Output_y_n(y_mid[i]), .Output_z_n(z_mid[i]));
      else if(i < (ITER/2)) 
        CORDIC_Roter #(.SHIFT_BASE(i*2), .WIDTH(WIDTH))
          rote01 ( .Input_x_n_1(x[i-1]),      .Input_y_n_1(y[i-1]),      .Input_z_n_1(z[i-1]),
                   .Output_x_n(x_mid[i]), .Output_y_n(y_mid[i]), .Output_z_n(z_mid[i]));
      else if(i == (ITER/2)) begin 
        CORDIC_Roter #(.SHIFT_BASE((i-ITER/2)*2), .WIDTH(WIDTH))
            rote02 ( .Input_x_n_1(x_temp[WIDTH+15:16]), .Input_y_n_1(z_7_delay),
                     .Output_x_n(x_mid[i]),     .Output_y_n(z_mid[i]));
      end
      else 
        CORDIC_Roter #(.SHIFT_BASE((i-ITER/2)*2), .WIDTH(WIDTH))
          rote03 ( .Input_x_n_1(x[i-1]),      .Input_y_n_1(z[i-1]),
                   .Output_x_n(x_mid[i]), .Output_y_n(z_mid[i]));

      if(i < (ITER/2))
        CORDIC_Roter #(.SHIFT_BASE(i*2+1), .WIDTH(WIDTH))
          rote04 ( .Input_x_n_1(x_mid[i]), .Input_y_n_1(y_mid[i]), .Input_z_n_1(z_mid[i]),
                   .Output_x_n(x_next[i]), .Output_y_n(y_next[i]), .Output_z_n(z_next[i]));
      else if(i < ITER) begin 
        CORDIC_Roter #(.SHIFT_BASE((i-ITER/2)*2+1), .WIDTH(WIDTH))
          rote05 ( .Input_x_n_1(x_mid[i]),   .Input_y_n_1(z_mid[i]),
                   .Output_x_n(x_next[i]), .Output_y_n(z_next[i]));
      end
    end
  endgenerate

  integer j;
  always @(posedge clk) begin
    for (j = 0; j < ITER; j = j + 1) begin
      x[j] <= x_next[j];
      z[j] <= z_next[j];
    end

    for (j = 0; j < ITER/2; j = j + 1) begin
      y[j] <= y_next[j];
      end
  end

  always @(posedge clk) begin
    x_temp <= x[ITER/2-1] * K;
  end

  always @(posedge clk) begin
    z_7_delay <= z[ITER/2-1];
  end
  
  always @(posedge clk) begin
    output_temp <= x[ITER-1] * K;
    Output_xn <= output_temp[WIDTH+15:16];
  end

endmodule
