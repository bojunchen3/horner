module process #(
  parameter integer DATA_WIDTH = 16,
  parameter integer OUT_WIDTH  = 8,
  parameter integer LANES      = 4,
  parameter integer PIPE_LAT   = 49,
  // parameter integer ORI_NUM    = 7,
  // parameter integer INT_NUM    = 45,
  // parameter integer LAY_NUM    = 5
  parameter integer ORI_NUM    = 4,
  parameter integer INT_NUM    = 6,
  parameter integer LAY_NUM    = 2
)(
  input  wire                        aclk,
  input  wire                        aresetn,

  // AXIS Slave (from DMA MM2S)
  input  wire [LANES*DATA_WIDTH-1:0] s_tdata,
  input  wire                        s_tvalid,
  output wire                        s_tready,

  // AXIS Master (to DMA S2MM)
  output wire [OUT_WIDTH-1:0]        m_tdata,
  output wire                        m_tvalid,
  output wire                        m_tlast
);

  parameter integer WEIGHT_NUM = 3*ORI_NUM + INT_NUM -LAY_NUM + 3;

  // lane0 LSB
  wire [DATA_WIDTH-1:0] lane0 = s_tdata[DATA_WIDTH*1-1:DATA_WIDTH*0];
  wire [DATA_WIDTH-1:0] lane1 = s_tdata[DATA_WIDTH*2-1:DATA_WIDTH*1];
  wire [DATA_WIDTH-1:0] lane2 = s_tdata[DATA_WIDTH*3-1:DATA_WIDTH*2];
  wire [DATA_WIDTH-1:0] lane3 = s_tdata[DATA_WIDTH*4-1:DATA_WIDTH*3];

  assign s_tready = 1'b1;
  wire   s_hand   = s_tvalid & s_tready;

  localparam [1:0] IDLE   = 2'b00;
  localparam [1:0] WEIGHT = 2'b01;
  localparam [1:0] LOAD   = 2'b10;
  localparam [1:0] STREAM = 2'b11;

  reg [1:0] state, next_state;

  reg [5:0]                  weight_idx, next_weight_idx;
  reg [DATA_WIDTH*LANES-1:0] weight [0:3*ORI_NUM+INT_NUM-LAY_NUM+2];
  reg [DATA_WIDTH-1:0]       mat [0:11];
  reg [3:0]                  mat_idx, next_mat_idx;
  reg                        ip_load_matrix;


  // -------------------------
  // next_state
  // -------------------------
  always @(*) begin
    case(state)
      IDLE:   begin
                   // 等第一個輸入握手再進入 LOAD
                   if(s_hand)
                     next_state = WEIGHT;
                   else
                     next_state = IDLE;
                 end
      WEIGHT: begin
                   if((weight_idx == WEIGHT_NUM + 1) && s_hand)
                     next_state = LOAD;
                   else
                     next_state = WEIGHT;
                 end
      LOAD:   begin
                   // 每拍固定 4 個元素，裝滿 16 個就進 STREAM
                   if((mat_idx == 4'd12) && s_hand)
                     next_state = STREAM;
                   else
                     next_state = LOAD;
                 end
      STREAM: begin
                   if(m_tlast)
                     next_state = IDLE; // 簡單起見，永遠停在 STREAM
                   else
                     next_state = STREAM;
                 end
      default:   next_state = IDLE;
    endcase
  end

  // -------------------------
  // next_weight_idx
  // -------------------------
  always @(*) begin
    if(next_state == IDLE)
      next_weight_idx = 5'd0;
    else if(next_state == WEIGHT && s_hand) begin
      if(weight_idx < WEIGHT_NUM + 1)
        next_weight_idx = weight_idx + 5'd1;
      else
        next_weight_idx = 5'd0;
    end else
      next_weight_idx = 5'd0;
  end

  // -------------------------
  // next_mat_idx
  // -------------------------
  always @(*) begin
    if(next_state == IDLE)
      next_mat_idx = 4'd0;
    else if(next_state == LOAD && s_hand) begin
      if(mat_idx < 4'd12)
        next_mat_idx = mat_idx + 4'd4;
      else
        next_mat_idx = 4'd0;
    end else
      next_mat_idx = 4'd0;
  end

  // -------------------------
  // state 
  // -------------------------
  integer i;
  always @(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin
      state      <= IDLE;
      weight_idx <= 5'd0;
      mat_idx    <= 4'd0;
    end else begin
      state      <= next_state;
      weight_idx <= next_weight_idx;
      mat_idx    <= next_mat_idx;
    end
  end

  reg [63:0] CAL_NUM;
  always @(posedge aclk) begin
    if(!aresetn)
      CAL_NUM <= 64'd0;
    else begin
      if(next_state == WEIGHT && weight_idx == 5'd0 && s_hand)
        CAL_NUM <= s_tdata;
    end
  end

  always @(posedge aclk) begin
    if(!aresetn)
      for(i=0; i<16; i=i+1)
        weight[i] <= {64{1'b0}};
    else begin
      if(next_state == WEIGHT && weight_idx > 5'd0 && s_hand)
        weight[weight_idx - 1] <= s_tdata;
    end
  end

  always @(*) begin
    if (!aresetn)
      ip_load_matrix = 0;
    else begin
      if ((next_state == LOAD || state == LOAD) && s_hand)
        ip_load_matrix = 1;
      else
        ip_load_matrix = 0;
    end    
  end

  always @(posedge aclk) begin
    if(!aresetn)
      for(i=0; i<12; i=i+1)
        mat[i] <= {DATA_WIDTH{1'b0}};
    else begin
      if(next_state == LOAD && s_hand) begin
        mat[mat_idx+0] <= lane0;
        mat[mat_idx+1] <= lane1;
        mat[mat_idx+2] <= lane2;
        mat[mat_idx+3] <= lane3;
      end
    end
  end

  // matrix value
  wire [DATA_WIDTH-1:0] a00, a01, a02, a03,
                        a10, a11, a12, a13,
                        a20, a21, a22, a23;

  assign a00 = mat[ 0]; assign a01 = mat[ 1]; assign a02 = mat[ 2]; assign a03 = mat[ 3];
  assign a10 = mat[ 4]; assign a11 = mat[ 5]; assign a12 = mat[ 6]; assign a13 = mat[ 7];
  assign a20 = mat[ 8]; assign a21 = mat[ 9]; assign a22 = mat[10]; assign a23 = mat[11];

  // only in STREAM state = s_tdata, others = 0
  // wire [LANES*DATA_WIDTH-1:0] ip_vector =
  //   (state == STREAM) ? s_tdata : {LANES*DATA_WIDTH{1'b0}};
  
  reg  [LANES*DATA_WIDTH-1:0] ip_vector;
  always @(*) begin
    if(next_state == STREAM)
      ip_vector = s_tdata;
    else
      ip_vector = {LANES*DATA_WIDTH{1'b0}};
  end

  reg  [15:0] input_count;
  always @(posedge aclk) begin
    if(state == STREAM)
      input_count <= input_count + 1;
    else
      input_count <= 0;
  end

  wire signed [DATA_WIDTH-1:0] normalize_x, normalize_y, normalize_z;
  reg  signed [DATA_WIDTH-1:0] normalize_x_r [0:39];
  reg  signed [DATA_WIDTH-1:0] normalize_y_r [0:39];
  reg  signed [DATA_WIDTH-1:0] normalize_z_r [0:39];

  reg  signed [DATA_WIDTH-1:0] ori_x [0: ORI_NUM-1];
  reg  signed [DATA_WIDTH-1:0] ori_y [0: ORI_NUM-1]; 
  reg  signed [DATA_WIDTH-1:0] ori_z [0: ORI_NUM-1];

  reg  signed [DATA_WIDTH-1:0] int_x [0: INT_NUM-1];
  reg  signed [DATA_WIDTH-1:0] int_y [0: INT_NUM-1]; 
  reg  signed [DATA_WIDTH-1:0] int_z [0: INT_NUM-1];

  SRT #(
    .DATA_WIDTH (DATA_WIDTH),
    .OUT_WIDTH  (DATA_WIDTH)
  ) srt (
    .aclk        (aclk),
    .aresetn     (aresetn),
    .load_matrix (ip_load_matrix),
    .a00(a00), .a01(a01), .a02(a02), .a03(a03), // q16
    .a10(a10), .a11(a11), .a12(a12), .a13(a13),
    .a20(a20), .a21(a21), .a22(a22), .a23(a23),
    .vector      (ip_vector),   // q0
    .result0     (normalize_x), // q16 
    .result1     (normalize_y), // q16
    .result2     (normalize_z)  // q16
  );

  always @(posedge aclk) begin
    normalize_x_r[0] <= normalize_x;
    normalize_y_r[0] <= normalize_y;
    normalize_z_r[0] <= normalize_z;
    for(i=0; i<39; i=i+1) begin
      normalize_x_r[i+1] <= normalize_x_r[i];
      normalize_y_r[i+1] <= normalize_y_r[i];
      normalize_z_r[i+1] <= normalize_z_r[i];
    end
  end

  always @(posedge aclk)begin
    if(input_count > 4 && input_count < ORI_NUM + 5) begin
      ori_x[input_count - 5] <= normalize_x;  
      ori_y[input_count - 5] <= normalize_y; 
      ori_z[input_count - 5] <= normalize_z; 
    end else begin
      int_x[input_count - 5 - ORI_NUM] <= normalize_x;  
      int_y[input_count - 5 - ORI_NUM] <= normalize_y; 
      int_z[input_count - 5 - ORI_NUM] <= normalize_z; 
    end
  end

  wire signed [31:0] K_ZGx_temp_0 [0:ORI_NUM-1];
  wire signed [31:0] K_ZGy_temp_0 [0:ORI_NUM-1];
  wire signed [31:0] K_ZGz_temp_0 [0:ORI_NUM-1];

  genvar j;
  generate
    for (j = 0; j < ORI_NUM; j = j + 1) begin : gen_kzgu
      K_ZGu #(.DATA_WIDTH(DATA_WIDTH)) u_kzgu (
        .clk(aclk), .rst_n(aresetn),
        .ori_x(ori_x[j]), .ori_y(ori_y[j]), .ori_z(ori_z[j]),
        .normalize_x(normalize_x), .normalize_y(normalize_y), .normalize_z(normalize_z),
        .K_ZGx(K_ZGx_temp_0[j]), .K_ZGy(K_ZGy_temp_0[j]), .K_ZGz(K_ZGz_temp_0[j])
      );
    end
  endgenerate

  reg  signed [31:0] K_ZGx_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGy_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGz_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGx        [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGy        [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGz        [0:ORI_NUM-1];

  // delay one clock wait for K_Z
  always @(posedge aclk) begin
    for(i=0; i<ORI_NUM; i=i+1) begin
      K_ZGx_temp_1[i] <= K_ZGx_temp_0[i];
      K_ZGy_temp_1[i] <= K_ZGy_temp_0[i];
      K_ZGz_temp_1[i] <= K_ZGz_temp_0[i];
      K_ZGx[i] <= K_ZGx_temp_1[i];
      K_ZGy[i] <= K_ZGy_temp_1[i];
      K_ZGz[i] <= K_ZGz_temp_1[i];
    end
  end
  
  wire signed [31:0] K_Z [0:INT_NUM-1];
  
  generate
    for (j = 0; j < INT_NUM; j = j + 1) begin : gen_kz
      K_Z #(.DATA_WIDTH(DATA_WIDTH)) u_kz (
        .clk(aclk),
        .rst_n(aresetn),
        .int_x(int_x[j]),
        .int_y(int_y[j]),
        .int_z(int_z[j]),
        .normalize_x(normalize_x),
        .normalize_y(normalize_y),
        .normalize_z(normalize_z),
        .K_Z_out(K_Z[j])
      );
    end
  endgenerate

  integer k;
  integer num_per_layer = INT_NUM / LAY_NUM;
  reg [31:0] diff_K_Z [0:INT_NUM-LAY_NUM-1];
  always @(posedge aclk) begin
    // diff_K_Z[0] <= K_Z[0] - K_Z[1];
    // diff_K_Z[1] <= K_Z[0] - K_Z[2];
    // diff_K_Z[2] <= K_Z[3] - K_Z[4];
    // diff_K_Z[3] <= K_Z[3] - K_Z[5];
    for(i=0; i<LAY_NUM; i=i+1) begin
      for(k=1; k<num_per_layer; k=k+1)
        diff_K_Z[(num_per_layer-1)*i+k-1] <= K_Z[num_per_layer*i] - K_Z[num_per_layer*i+k];
    end
  end

  wire [31:0] answer   [0:WEIGHT_NUM-1];

  generate
    for (j = 0; j < ORI_NUM; j = j + 1) begin : gen_answer_ori
      mul_q16 u_mul0  (.a($signed(weight[          j])), .b($signed(K_ZGx[j])), .y(answer[          j]));
      mul_q16 u_mul1  (.a($signed(weight[  ORI_NUM+j])), .b($signed(K_ZGy[j])), .y(answer[  ORI_NUM+j]));
      mul_q16 u_mul2  (.a($signed(weight[2*ORI_NUM+j])), .b($signed(K_ZGz[j])), .y(answer[2*ORI_NUM+j]));
    end
  endgenerate

  generate
    for (j = 0; j < INT_NUM - LAY_NUM; j = j + 1) begin : gen_answer_int
      mul_q16 u_muli3 (.a($signed(weight[3*ORI_NUM + j])), .b($signed(diff_K_Z[j])), .y(answer[3*ORI_NUM + j]));
    end
  endgenerate

  mul_q16 u_mul14 (.a($signed(weight[WEIGHT_NUM - 3])), .b($signed(normalize_x_r[39])), .y(answer[WEIGHT_NUM - 3]));
  mul_q16 u_mul15 (.a($signed(weight[WEIGHT_NUM - 2])), .b($signed(normalize_y_r[39])), .y(answer[WEIGHT_NUM - 2]));
  mul_q16 u_mul16 (.a($signed(weight[WEIGHT_NUM - 1])), .b($signed(normalize_z_r[39])), .y(answer[WEIGHT_NUM - 1]));

  // mul_q16 u_mul0  (.a($signed(weight[ 0])), .b($signed(        K_ZGx[ 0])), .y(answer[ 0]));
  // mul_q16 u_mul1  (.a($signed(weight[ 1])), .b($signed(        K_ZGx[ 1])), .y(answer[ 1]));
  // mul_q16 u_mul2  (.a($signed(weight[ 2])), .b($signed(        K_ZGx[ 2])), .y(answer[ 2]));
  // mul_q16 u_mul3  (.a($signed(weight[ 3])), .b($signed(        K_ZGy[ 0])), .y(answer[ 3]));
  // mul_q16 u_mul4  (.a($signed(weight[ 4])), .b($signed(        K_ZGy[ 1])), .y(answer[ 4]));
  // mul_q16 u_mul5  (.a($signed(weight[ 5])), .b($signed(        K_ZGy[ 2])), .y(answer[ 5]));
  // mul_q16 u_mul6  (.a($signed(weight[ 6])), .b($signed(        K_ZGz[ 0])), .y(answer[ 6]));
  // mul_q16 u_mul7  (.a($signed(weight[ 7])), .b($signed(        K_ZGz[ 1])), .y(answer[ 7]));
  // mul_q16 u_mul8  (.a($signed(weight[ 8])), .b($signed(        K_ZGz[ 2])), .y(answer[ 8]));
  // mul_q16 u_mul9  (.a($signed(weight[ 9])), .b($signed(     diff_K_Z[ 0])), .y(answer[ 9]));
  // mul_q16 u_mul10 (.a($signed(weight[10])), .b($signed(     diff_K_Z[ 1])), .y(answer[10]));
  // mul_q16 u_mul11 (.a($signed(weight[11])), .b($signed(     diff_K_Z[ 2])), .y(answer[11]));
  // mul_q16 u_mul12 (.a($signed(weight[12])), .b($signed(     diff_K_Z[ 3])), .y(answer[12]));
  // mul_q16 u_mul13 (.a($signed(weight[13])), .b($signed(normalize_x_r[39])), .y(answer[13]));
  // mul_q16 u_mul14 (.a($signed(weight[14])), .b($signed(normalize_y_r[39])), .y(answer[14]));
  // mul_q16 u_mul15 (.a($signed(weight[15])), .b($signed(normalize_z_r[39])), .y(answer[15]));

  reg [31:0] answer_r [0:63];
  reg [31:0] add_temp [0:19];
  reg [31:0] field;

  always @(posedge aclk) begin
    if(!aresetn)
      for(i=0; i<64; i=i+1)
        answer_r[i] <= 32'd0;
    else
      for(i=0; i<WEIGHT_NUM; i=i+1)
        answer_r[i] <= answer[i];
  end

  always @(posedge aclk) begin
    if(!aresetn)
      for(i=0; i<20; i=i+1)
        add_temp[i] <= 32'd0;
    else begin
      add_temp[ 0] <= (answer_r[ 0] + answer_r[ 1]) + (answer_r[ 2] + answer_r[ 3]);
      add_temp[ 1] <= (answer_r[ 4] + answer_r[ 5]) + (answer_r[ 6] + answer_r[ 7]);
      add_temp[ 2] <= (answer_r[ 8] + answer_r[ 9]) + (answer_r[10] + answer_r[11]);
      add_temp[ 3] <= (answer_r[12] + answer_r[13]) + (answer_r[14] + answer_r[15]);
      add_temp[ 4] <= (answer_r[16] + answer_r[17]) + (answer_r[18] + answer_r[19]);
      add_temp[ 5] <= (answer_r[20] + answer_r[21]) + (answer_r[22] + answer_r[23]);
      add_temp[ 6] <= (answer_r[24] + answer_r[25]) + (answer_r[26] + answer_r[27]);
      add_temp[ 7] <= (answer_r[28] + answer_r[29]) + (answer_r[30] + answer_r[31]);
      add_temp[ 8] <= (answer_r[32] + answer_r[33]) + (answer_r[34] + answer_r[35]);
      add_temp[ 9] <= (answer_r[36] + answer_r[37]) + (answer_r[38] + answer_r[39]);
      add_temp[10] <= (answer_r[40] + answer_r[41]) + (answer_r[42] + answer_r[43]);
      add_temp[11] <= (answer_r[44] + answer_r[45]) + (answer_r[46] + answer_r[47]);
      add_temp[12] <= (answer_r[48] + answer_r[49]) + (answer_r[50] + answer_r[51]);
      add_temp[13] <= (answer_r[52] + answer_r[53]) + (answer_r[54] + answer_r[55]);
      add_temp[14] <= (answer_r[56] + answer_r[57]) + (answer_r[58] + answer_r[59]);
      add_temp[15] <= (answer_r[60] + answer_r[61]) + (answer_r[62] + answer_r[63]);

      add_temp[16] <= (add_temp[ 0] + add_temp[ 1]) + (add_temp[ 2] + add_temp[ 3]);
      add_temp[17] <= (add_temp[ 4] + add_temp[ 5]) + (add_temp[ 6] + add_temp[ 7]);
      add_temp[18] <= (add_temp[ 8] + add_temp[ 9]) + (add_temp[10] + add_temp[11]);
      add_temp[19] <= (add_temp[12] + add_temp[13]) + (add_temp[14] + add_temp[15]);

      field <= (add_temp[16] + add_temp[17]) + (add_temp[18] + add_temp[19]);
    end
  end

  reg [31:0] layer1, layer2;
  always @(posedge aclk) begin
    if (input_count == PIPE_LAT + ORI_NUM + INT_NUM + LAY_NUM - 2)
      layer1 <= field;
    if (input_count == PIPE_LAT + ORI_NUM + INT_NUM + LAY_NUM - 1)
      layer2 <= field;
  end
  
  reg [7:0] label;
  always @(posedge aclk) begin
    if ($signed(field) <= $signed(layer1))
      label <= 3;
    else if ($signed(field) <= $signed(layer2))
      label <= 2;
    else
      label <= 1;
  end

  assign m_tdata =  label;
  assign m_tvalid = (input_count  > PIPE_LAT + ORI_NUM + INT_NUM + LAY_NUM && input_count <= PIPE_LAT + ORI_NUM + INT_NUM + LAY_NUM + CAL_NUM)? 1: 0;
  assign m_tlast  = (input_count == PIPE_LAT + ORI_NUM + INT_NUM + LAY_NUM + CAL_NUM)? 1: 0;

endmodule
