module CORDIC_Vector(
  input         clk,
  input  [31:0] Input_x,
  input  [31:0] Input_y,
  input  [31:0] Input_z,
  output [31:0] Output_xn
);
  
  parameter K = 32'h9b74;  //K=0.607253*2^16,32'h09b74
  
  reg signed [31:0] Output_xn;
  
  reg signed [31:0] x_00,y_00,z_00;
  
  // wire signed [31:0] x [1:32];
  // wire signed [31:0] y [1:16];
  // wire signed [31:0] z [1:32];
  wire signed [47:0] x_temp;
  wire signed [47:0] output_temp;
  
  always @ (posedge clk) begin
    x_00 <= Input_x;
    y_00 <= Input_y;
    z_00 <= Input_z;
  end
  
  reg  signed [31:0]      x[0:15];
  reg  signed [31:0]      y[0: 7];
  reg  signed [31:0]      z[0:15];
  wire signed [31:0]  x_mid[0:15];
  wire signed [31:0]  y_mid[0: 7];
  wire signed [31:0]  z_mid[0:15];
  wire signed [31:0] x_next[0:15];
  wire signed [31:0] y_next[0: 7];
  wire signed [31:0] z_next[0:15];

  assign x_temp = x[7] * K;

  //--- generate operation pipeline --- 
  generate
    genvar i;
    for (i = 0; i < 16; i = i + 1) begin: roter    
      if (i == 0) 
        CORDIC_Roter #(.SHIFT_BASE(i))
          rote00 ( .Input_x_n_1(x_00),      .Input_y_n_1(y_00),      .Input_z_n_1(z_00),
                   .Output_x_n(x_mid[i]), .Output_y_n(y_mid[i]), .Output_z_n(z_mid[i]));
      else if(i < 8) 
        CORDIC_Roter #(.SHIFT_BASE(i*2))
          rote01 ( .Input_x_n_1(x[i-1]),      .Input_y_n_1(y[i-1]),      .Input_z_n_1(z[i-1]),
                   .Output_x_n(x_mid[i]), .Output_y_n(y_mid[i]), .Output_z_n(z_mid[i]));
      else if(i == 8) begin 
        CORDIC_Roter #(.SHIFT_BASE((i-8)*2))
            rote02 ( .Input_x_n_1(x_temp[47:16]), .Input_y_n_1(z[i-1]),
                     .Output_x_n(x_mid[i]),     .Output_y_n(z_mid[i]));
      end
      else 
        CORDIC_Roter #(.SHIFT_BASE((i-8)*2))
          rote03 ( .Input_x_n_1(x[i-1]),      .Input_y_n_1(z[i-1]),
                   .Output_x_n(x_mid[i]), .Output_y_n(z_mid[i]));

      if(i < 8) 
        CORDIC_Roter #(.SHIFT_BASE(i*2+1))
          rote04 ( .Input_x_n_1(x_mid[i]), .Input_y_n_1(y_mid[i]), .Input_z_n_1(z_mid[i]),
                   .Output_x_n(x_next[i]), .Output_y_n(y_next[i]), .Output_z_n(z_next[i]));
      else if(i < 16) begin 
        CORDIC_Roter #(.SHIFT_BASE((i-8)*2+1))
          rote05 ( .Input_x_n_1(x_mid[i]),   .Input_y_n_1(z_mid[i]),
                   .Output_x_n(x_next[i]), .Output_y_n(z_next[i]));
      end
    end
  endgenerate

  integer j;
  always @(posedge clk) begin
    for ( j = 0; j < 16; j = j + 1) begin
      x[j] <= x_next[j];
      z[j] <= z_next[j];
    end
    for ( j = 0; j < 8; j = j + 1) begin
      y[j] <= y_next[j];
    end
  end
  
  ////--- generate operation pipeline --- 
  //generate
  //  genvar i;
  //  for (i = 0; i < 32 ; i = i + 1) begin: roter    
  //    if (i == 0) 
  //      CORDIC_Roter #(.SHIFT_BASE(i))
  //        rote00 ( .Input_x_n_1(x_00), .Input_y_n_1(y_00), .Input_z_n_1(z_00),
  //                 .Output_x_n(x[i]), .Output_y_n(y[i]), .Output_z_n(z[i]));
  //    else if(i < 16) 
  //      CORDIC_Roter #(.SHIFT_BASE(i))
  //        rote01 ( .Input_x_n_1(x[i-1]), .Input_y_n_1(y[i-1]), .Input_z_n_1(z[i-1]),
  //                 .Output_x_n(x[i]), .Output_y_n(y[i]), .Output_z_n(z[i]));
  //    else if(i == 16) begin 
  //      CORDIC_Roter #(.SHIFT_BASE(i-16))
  //          rote02 ( .Input_x_n_1(x_temp[47:16]), .Input_y_n_1(z[i-1]),
  //                   .Output_x_n(x[i]),.Output_y_n(z[i]));
  //    end
  //    else 
  //      CORDIC_Roter #(.SHIFT_BASE(i-16))
  //        rote03 ( .Input_x_n_1(x[i]), .Input_y_n_1(z[i]),
  //                 .Output_x_n(x[i]), .Output_y_n(z[i]));
  //  end
  //endgenerate
  
  assign output_temp = x[15] * K;
  always @ (posedge clk) begin
    Output_xn <= output_temp[47:16];
  end

endmodule
