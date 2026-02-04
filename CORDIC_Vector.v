module CORDIC_Vector(
  input         clk,
  input         RST_N,
  input  [31:0] Input_x,
  input  [31:0] Input_y,
  input  [31:0] Input_z,
  output [31:0] Output_xn
);
  
  parameter K = 32'h9b74;  //K=0.607253*2^16,32'h09b74
  
  reg signed [31:0] Output_xn;
  
  reg signed [31:0] x_00,y_00,z_00;
  
  wire signed [31:0] x [32:1];
  wire signed [31:0] y [16:1];
  wire signed [31:0] z [32:1];
  wire signed [47:0] x_temp;
  wire signed [47:0] output_temp;
  
  always @ (posedge clk or negedge RST_N) begin
    if (!RST_N) begin
      x_00 <= 1'b0;
      y_00 <= 1'b0;
      z_00 <= 1'b0;
    end
    else begin
      x_00 <= Input_x;
      y_00 <= Input_y;
      z_00 <= Input_z;
    end
  end
  
  assign x_temp = x[16] * K;
  //--- generate operation pipeline --- 
  generate
    genvar i;
    for (i = 0; i < 32 ; i = i + 1) begin: roter    
      if (i == 0) 
        CORDIC_Roter #(.SHIFT_BASE(i))
          rote00 (.clk(clk), .RST_N(RST_N),
                  .Input_x_n_1(x_00), .Input_y_n_1(y_00), .Input_z_n_1(z_00),
                  .Output_x_n(x[i+1]), .Output_y_n(y[i+1]), .Output_z_n(z[i+1]));
      else if(i < 16) 
        CORDIC_Roter #(.SHIFT_BASE(i))
          rote01 (.clk(clk), .RST_N(RST_N),
                  .Input_x_n_1(x[i]), .Input_y_n_1(y[i]), .Input_z_n_1(z[i]),
                  .Output_x_n(x[i+1]), .Output_y_n(y[i+1]), .Output_z_n(z[i+1]));
      else if(i == 16) begin 
        CORDIC_Roter #(.SHIFT_BASE(i-16))
            rote02 (.clk(clk), .RST_N(RST_N),
                    .Input_x_n_1(x_temp[47:16]), .Input_y_n_1(z[i]),
                    .Output_x_n(x[i+1]),.Output_y_n(z[i+1]));
      end
      else 
        CORDIC_Roter #(.SHIFT_BASE(i-16))
          rote03 (.clk(clk), .RST_N(RST_N),
                  .Input_x_n_1(x[i]), .Input_y_n_1(z[i]),
                  .Output_x_n(x[i+1]), .Output_y_n(z[i+1]));
    end
  endgenerate
  
  assign output_temp = x[32] * K;
  always @ (posedge clk or negedge RST_N) begin
    if (!RST_N) 
      Output_xn <= 1'b0;
    else 
      Output_xn <= output_temp[47:16];
  end

endmodule
