module SystolicArray #(
    parameter DATA_WIDTH = 16,
    parameter OUT_WIDTH  = 16
)(
    input  wire                  clk,
    input  wire                  aresetn,
    input  wire                  load_matrix,
    // 3x4 matrix
    input  wire [DATA_WIDTH-1:0] a00, a01, a02, a03,
    input  wire [DATA_WIDTH-1:0] a10, a11, a12, a13,
    input  wire [DATA_WIDTH-1:0] a20, a21, a22, a23,
    // independent input
    input  wire [DATA_WIDTH-1:0] vec_in0,  // column 0
    input  wire [DATA_WIDTH-1:0] vec_in1,  // column 1
    input  wire [DATA_WIDTH-1:0] vec_in2,  // column 2
    input  wire [DATA_WIDTH-1:0] vec_in3,  // column 3
    output wire [OUT_WIDTH-1:0]  result0, result1, result2
);
    wire [DATA_WIDTH-1:0] mat_val [0:2][0:3];
    assign mat_val[0][0]=a00; assign mat_val[0][1]=a01; assign mat_val[0][2]=a02; assign mat_val[0][3]=a03;
    assign mat_val[1][0]=a10; assign mat_val[1][1]=a11; assign mat_val[1][2]=a12; assign mat_val[1][3]=a13;
    assign mat_val[2][0]=a20; assign mat_val[2][1]=a21; assign mat_val[2][2]=a22; assign mat_val[2][3]=a23;

    wire [OUT_WIDTH-1:0]  partial  [0:2][0:3];
    wire [DATA_WIDTH-1:0] down_val [0:2][0:3];
    wire [DATA_WIDTH-1:0] top_in_sig  [0:2][0:3];
    wire [OUT_WIDTH-1:0]  left_in_sig [0:2][0:3];

    genvar i, j;
    generate
        // first raw top in from input
        assign top_in_sig[0][0] = vec_in0;
        assign top_in_sig[0][1] = vec_in1;
        assign top_in_sig[0][2] = vec_in2;
        assign top_in_sig[0][3] = vec_in3;

        // other raw top in from above
        for (i = 1; i < 3; i = i + 1) begin : DOWN_FEED
            for (j = 0; j < 4; j = j + 1) begin : DOWN_FEED_COL
                assign top_in_sig[i][j] = down_val[i-1][j];
            end
        end

        // first column left in = 0
        for (i = 0; i < 3; i = i + 1) begin : LEFT_BOUNDARY
            assign left_in_sig[i][0] = {OUT_WIDTH{1'b0}};
        end

        //other column left in from right
        for (i = 0; i < 3; i = i + 1) begin : RIGHT_FEED_ROW
            for (j = 1; j < 4; j = j + 1) begin : RIGHT_FEED
                assign left_in_sig[i][j] = partial[i][j-1];
            end
        end

        // 3x4 PE
        for (i = 0; i < 3; i = i + 1) begin : ROW
            for (j = 0; j < 4; j = j + 1) begin : COL
                PE #(.DATA_WIDTH(DATA_WIDTH), .OUT_WIDTH(OUT_WIDTH)) pe_inst (
                    .clk        (clk),
                    .aresetn    (aresetn),
                    .load       (load_matrix),
                    .matrix_in  (mat_val[i][j]),
                    .top_in     (top_in_sig[i][j]),
                    .left_in    (left_in_sig[i][j]),
                    .down_out   (down_val[i][j]),
                    .partial_out(partial[i][j])
                );
            end
        end
    endgenerate

    assign result0 = partial[0][3];
    assign result1 = partial[1][3];
    assign result2 = partial[2][3];
endmodule

