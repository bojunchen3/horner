module CORDIC_Roter(
  clk,
  RST_N,
  Input_x_n_1,
  Input_y_n_1,
  Input_z_n_1,
  Input_angle_n_1,
  Input_sign_n_1,
  Input_rote_base,
  Output_x_n,
  Output_y_n,
  Output_z_n,
  Output_angle_n,
  Output_sign_n
);
  parameter ROTE_BASE = 0;
  parameter SHIFT_BASE =0;
  parameter MODE = 0;
  
  input clk;
  input RST_N;
  input wire signed [31:0] Input_x_n_1;
  input wire signed [31:0] Input_y_n_1;
  input wire signed [31:0] Input_z_n_1;
  input wire signed [31:0] Input_angle_n_1;
  input wire        [31:0] Input_sign_n_1;
  input wire signed [31:0] Input_rote_base;
  
  output reg signed [31:0] Output_x_n;
  output reg signed [31:0] Output_y_n;
  output reg signed [31:0] Output_z_n;
  output reg signed [31:0] Output_angle_n;
  output reg        [31:0] Output_sign_n;
  always @ (posedge clk or negedge RST_N) begin
    if (!RST_N) begin
      Output_x_n<=1'b0;
      Output_y_n<=1'b0;
      Output_z_n<=1'b0;
      Output_angle_n<=1'b0;
      Output_sign_n<=1'b0;
    end
    else
      if (!MODE) // Rotation Mode
        if (Input_angle_n_1[31]) begin
          Output_x_n<=Input_x_n_1+(Input_y_n_1>>>SHIFT_BASE);
          Output_y_n<=Input_y_n_1-(Input_x_n_1>>>SHIFT_BASE);
          Output_angle_n<=Input_angle_n_1+Input_rote_base;
          Output_sign_n<=Input_sign_n_1;
        end
        else begin
          Output_x_n<=Input_x_n_1-(Input_y_n_1>>>SHIFT_BASE);
          Output_y_n<=Input_y_n_1+(Input_x_n_1>>>SHIFT_BASE);
          Output_angle_n<=Input_angle_n_1-Input_rote_base;
          Output_sign_n<=Input_sign_n_1;
        end
      else // Vector Mode
        if (!Input_y_n_1[31]) begin
          Output_x_n<=Input_x_n_1+(Input_y_n_1>>>SHIFT_BASE);
          Output_y_n<=Input_y_n_1-(Input_x_n_1>>>SHIFT_BASE);
          //Output_angle_n<=Input_angle_n_1+Input_rote_base;
          //Output_sign_n<=Input_sign_n_1;
        end
        else begin
          Output_x_n<=Input_x_n_1-(Input_y_n_1>>>SHIFT_BASE);
          Output_y_n<=Input_y_n_1+(Input_x_n_1>>>SHIFT_BASE);
          //Output_angle_n<=Input_angle_n_1-Input_rote_base;
          //Output_sign_n<=Input_sign_n_1;
        end
        Output_z_n <= Input_z_n_1;
  end
endmodule
