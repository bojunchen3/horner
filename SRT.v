module SRT #(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 16
)(
    input  wire                  aclk,
    input  wire                  aresetn,
    input  wire                  load_matrix,
    input  wire [31:0] a00, a01, a02, a03,
    input  wire [31:0] a10, a11, a12, a13,
    input  wire [31:0] a20, a21, a22, a23,
    input  wire [4*DATA_WIDTH-1:0] vector,
    output wire [OUT_WIDTH-1:0]  result0, result1, result2
);

    // split vector into vec_in
    wire [DATA_WIDTH-1:0] vec_in0 = vector[DATA_WIDTH*1-1:DATA_WIDTH*0];
    wire [DATA_WIDTH-1:0] vec_in1 = vector[DATA_WIDTH*2-1:DATA_WIDTH*1];
    wire [DATA_WIDTH-1:0] vec_in2 = vector[DATA_WIDTH*3-1:DATA_WIDTH*2];
    wire [DATA_WIDTH-1:0] vec_in3 = vector[DATA_WIDTH*4-1:DATA_WIDTH*3];

    // buffer
    reg [DATA_WIDTH-1:0] in_01, in_02, in_03, in_12, in_13, in_23;
    reg [OUT_WIDTH-1:0] out_00, out_01, out_10;
    wire [OUT_WIDTH-1:0] temp0, temp1;
    
    always @(posedge aclk or negedge aresetn) begin
      if(!aresetn) begin
        in_01<=0; in_02<=0; in_03<=0; in_12<=0; in_13<=0; in_23<=0;
      end
      else begin
        in_01 <= vec_in1;
        in_12 <= vec_in2;
        in_02 <= in_12;
        in_23 <= vec_in3;
        in_13 <= in_23;
        in_03 <= in_13;
      end
    end

    always @(posedge aclk or negedge aresetn) begin
      if(!aresetn) begin
        out_00<=0; out_01<=0; out_10<=0;
      end
      else begin
        out_00 <= temp0;
        out_01 <= out_00; 
        out_10 <= temp1;
      end
    end

    assign result0 = out_01;
    assign result1 = out_10;

    // Systolic array
    SystolicArray #(.DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(OUT_WIDTH)) sa3x4 (
                    .clk        (aclk),
                    .aresetn      (aresetn),
                    .load_matrix(load_matrix),
                    .a00(a00), .a01(a01), .a02(a02), .a03(a03),
                    .a10(a10), .a11(a11), .a12(a12), .a13(a13),
                    .a20(a20), .a21(a21), .a22(a22), .a23(a23),
                    .vec_in0(vec_in0), .vec_in1(in_01), .vec_in2(in_02), .vec_in3(in_03),
                    .result0(temp0), .result1(temp1), .result2(result2)
    );
endmodule

