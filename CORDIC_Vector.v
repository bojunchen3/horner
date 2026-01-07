module CORDIC_Vector(
  input         clk,
  input         RST_N,
  input  [31:0] Input_x,
  input  [31:0] Input_y,
  input  [31:0] Input_z,
  output [31:0] Output_xn
);
  
  //---   Define the rotation base angle  ---
  // the rotation is processed in degrees; the values are magnified 2^16 times during processing; totally 16 rotations.
  wire signed [31:0] base [15:0];
  assign base[00] = 32'd2949120;         //45deg*2^16
  assign base[01] = 32'd1740992;         //26.5651deg*2^16
  assign base[02] = 32'd919872;          //14.0362deg*2^16
  assign base[03] = 32'd466944;          //7.1250deg*2^16
  assign base[04] = 32'd234368;          //3.5763deg*2^16
  assign base[05] = 32'd117312;          //1.7899deg*2^16
  assign base[06] = 32'd58688;           //0.8952deg*2^16
  assign base[07] = 32'd29312;           //0.4476deg*2^16
  assign base[08] = 32'd14656;           //0.2238deg*2^16
  assign base[09] = 32'd7360;            //0.1119deg*2^16
  assign base[10] = 32'd3648;            //0.0560deg*2^16
  assign base[11] = 32'd1856;            //0.0280deg*2^16
  assign base[12] = 32'd896;             //0.0140deg*2^16
  assign base[13] = 32'd448;             //0.0070deg*2^16
  assign base[14] = 32'd256;             //0.0035deg*2^16
  assign base[15] = 32'd128;             //0.0018deg*2^16
  
  
  parameter K = 32'h9b74;  //K=0.607253*2^16,32'h09b74
  parameter FRAC = 16;
  
  reg signed [31:0] Output_xn;
  
  reg signed [31:0] x_00,y_00,z_00;
  
  wire signed [31:0] x [32:1];
  wire signed [31:0] y [16:1];
  wire signed [31:0] z [32:1];
  wire signed [47:0] x_temp;
  wire signed [47:0] output_temp;
  
  // initialize the parameters for cosine and sine compute
  /*
  x_00=K; is the reciprocal of K_n
  y_00=0
  z_00=Input_x; is the aimed angles
  */
  always @ (posedge clk or negedge RST_N) begin
    if (!RST_N) begin
      x_00 <= 1'b0;
      y_00 <= 1'b0;
      z_00 <= 1'b0;
    end
    else begin
      //x_00 <= (Input_x[31])? ~Input_x+1: Input_x;
      //y_00 <= (Input_y[31])? ~Input_y+1: Input_y;
      //z_00 <= (Input_z[31])? ~Input_z+1: Input_z;
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
                  .Input_x_n_1(x_00), .Input_y_n_1(y_00), .Input_z_n_1(z_00), .Input_rote_base(base[i]),
                  .Output_x_n(x[i+1]), .Output_y_n(y[i+1]), .Output_z_n(z[i+1]));
      else if(i < 16) 
        CORDIC_Roter #(.SHIFT_BASE(i))
          rote01 (.clk(clk), .RST_N(RST_N),
                  .Input_x_n_1(x[i]), .Input_y_n_1(y[i]), .Input_z_n_1(z[i]), .Input_rote_base(base[i]),
                  .Output_x_n(x[i+1]), .Output_y_n(y[i+1]), .Output_z_n(z[i+1]));
      else if(i == 16) begin 
        CORDIC_Roter #(.SHIFT_BASE(i-16))
            rote02 (.clk(clk), .RST_N(RST_N),
                    .Input_x_n_1(x_temp[47:16]), .Input_y_n_1(z[i]), .Input_rote_base(base[i-16]),
                    .Output_x_n(x[i+1]),.Output_y_n(z[i+1]));
      end
      else 
        CORDIC_Roter #(.SHIFT_BASE(i-16))
          rote03 (.clk(clk), .RST_N(RST_N),
                  .Input_x_n_1(x[i]), .Input_y_n_1(z[i]), .Input_rote_base(base[i-16]),
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
