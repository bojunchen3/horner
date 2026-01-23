module process #(
  parameter integer DATA_WIDTH = 16,
  parameter integer OUT_WIDTH  = 8,
  parameter integer LANES      = 4,
  parameter integer PIPE_LAT   = 47,
  parameter integer ORI_NUM    = 3,
  parameter integer INT_NUM    = 6,
  parameter integer LAY_NUM    = 2
)(
  input  wire                        aclk,
  input  wire                        aresetn,

  // AXIS Slave (from DMA MM2S)
  input  wire [LANES*DATA_WIDTH-1:0] s_tdata,
  input  wire                        s_tvalid,
  output wire                        s_tready,
  input  wire                        s_tlast,

  // AXIS Master (to DMA S2MM)
  output wire [OUT_WIDTH-1:0]        m_tdata,
  output wire                        m_tvalid,
  output wire                        m_tlast
);

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

  reg [4:0]                  weight_idx, next_weight_idx;
  reg [DATA_WIDTH*LANES-1:0] weight [0:15];
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
                   if((weight_idx == 5'd17) && s_hand)
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
      if(weight_idx < 5'd17)
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

  ////////// o[0] - xa //////////
  wire [DATA_WIDTH:0] diff_o0_x = ori_x[0] - normalize_x;
  wire [DATA_WIDTH:0] diff_o0_y = ori_y[0] - normalize_y;
  wire [DATA_WIDTH:0] diff_o0_z = ori_z[0] - normalize_z;

  reg  [DATA_WIDTH:0] diff_o0_x_r[0:37];
  reg  [DATA_WIDTH:0] diff_o0_y_r[0:37];
  reg  [DATA_WIDTH:0] diff_o0_z_r[0:37];

  always @(posedge aclk) begin
    diff_o0_x_r[0] <= diff_o0_x;
    diff_o0_y_r[0] <= diff_o0_y;
    diff_o0_z_r[0] <= diff_o0_z;
    for (i=1; i<38; i=i+1) begin
      diff_o0_x_r[i] <= diff_o0_x_r[i-1];
      diff_o0_y_r[i] <= diff_o0_y_r[i-1];
      diff_o0_z_r[i] <= diff_o0_z_r[i-1];
    end
  end

  wire [16:0] cordic_o0_x = diff_o0_x[16]? (~diff_o0_x+1): diff_o0_x; // q16
  wire [16:0] cordic_o0_y = diff_o0_y[16]? (~diff_o0_y+1): diff_o0_y; // q16
  wire [16:0] cordic_o0_z = diff_o0_z[16]? (~diff_o0_z+1): diff_o0_z; // q16

  wire [31: 0] ro0;
  CORDIC_Vector cov_o0 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_o0_x), // q16
    .Input_y   (cordic_o0_y), // q16
    .Input_z   (cordic_o0_z), // q16
    .Output_xn (ro0) // q16
  );

  wire [31:0] d1_0_q16;
  cubic_cov_d1 ccd0 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ro0), // q16
    .ans_q16(d1_0_q16) // q16
  );

  ////////// o[1] - xa //////////
  wire [DATA_WIDTH:0] diff_o1_x = ori_x[1] - normalize_x;
  wire [DATA_WIDTH:0] diff_o1_y = ori_y[1] - normalize_y;
  wire [DATA_WIDTH:0] diff_o1_z = ori_z[1] - normalize_z;

  reg  [DATA_WIDTH:0] diff_o1_x_r[0:37];
  reg  [DATA_WIDTH:0] diff_o1_y_r[0:37];
  reg  [DATA_WIDTH:0] diff_o1_z_r[0:37];

  always @(posedge aclk) begin
    diff_o1_x_r[0] <= diff_o1_x;
    diff_o1_y_r[0] <= diff_o1_y;
    diff_o1_z_r[0] <= diff_o1_z;
    for (i=1; i<38; i=i+1) begin
      diff_o1_x_r[i] <= diff_o1_x_r[i-1];
      diff_o1_y_r[i] <= diff_o1_y_r[i-1];
      diff_o1_z_r[i] <= diff_o1_z_r[i-1];
    end
  end

  wire [16:0] cordic_o1_x = diff_o1_x[16]? (~diff_o1_x+1): diff_o1_x; // q16
  wire [16:0] cordic_o1_y = diff_o1_y[16]? (~diff_o1_y+1): diff_o1_y; // q16
  wire [16:0] cordic_o1_z = diff_o1_z[16]? (~diff_o1_z+1): diff_o1_z; // q16

  wire [31: 0] ro1;
  CORDIC_Vector cov_o1 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_o1_x), // q16
    .Input_y   (cordic_o1_y), // q16
    .Input_z   (cordic_o1_z), // q16
    .Output_xn (ro1) // q16
  );

  wire [31:0] d1_1_q16;
  cubic_cov_d1 ccd1 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ro1), // q16
    .ans_q16(d1_1_q16) // q16
  );

  ////////// o[2] - xa //////////
  wire [DATA_WIDTH:0] diff_o2_x = ori_x[2] - normalize_x;
  wire [DATA_WIDTH:0] diff_o2_y = ori_y[2] - normalize_y;
  wire [DATA_WIDTH:0] diff_o2_z = ori_z[2] - normalize_z;

  reg  [DATA_WIDTH:0] diff_o2_x_r[0:37];
  reg  [DATA_WIDTH:0] diff_o2_y_r[0:37];
  reg  [DATA_WIDTH:0] diff_o2_z_r[0:37];

  always @(posedge aclk) begin
    diff_o2_x_r[0] <= diff_o2_x;
    diff_o2_y_r[0] <= diff_o2_y;
    diff_o2_z_r[0] <= diff_o2_z;
    for (i=1; i<38; i=i+1) begin
      diff_o2_x_r[i] <= diff_o2_x_r[i-1];
      diff_o2_y_r[i] <= diff_o2_y_r[i-1];
      diff_o2_z_r[i] <= diff_o2_z_r[i-1];
    end
  end

  wire [16:0] cordic_o2_x = diff_o2_x[16]? (~diff_o2_x+1): diff_o2_x; // q16
  wire [16:0] cordic_o2_y = diff_o2_y[16]? (~diff_o2_y+1): diff_o2_y; // q16
  wire [16:0] cordic_o2_z = diff_o2_z[16]? (~diff_o2_z+1): diff_o2_z; // q16

  wire [31: 0] ro2;
  CORDIC_Vector cov_o2 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_o2_x), // q16
    .Input_y   (cordic_o2_y), // q16
    .Input_z   (cordic_o2_z), // q16
    .Output_xn (ro2) // q16
  );

  wire [31:0] d1_2_q16;
  cubic_cov_d1 ccd2 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ro2), // q16
    .ans_q16(d1_2_q16) // q16
  );

  // delay one clock wait for K_Z
  wire signed [31:0] K_ZGx_temp_0 [0:ORI_NUM-1];
  wire signed [31:0] K_ZGy_temp_0 [0:ORI_NUM-1];
  wire signed [31:0] K_ZGz_temp_0 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGx_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGy_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGz_temp_1 [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGx        [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGy        [0:ORI_NUM-1];
  reg  signed [31:0] K_ZGz        [0:ORI_NUM-1];

  mul_q16 u_mul0 (.a($signed(d1_0_q16)), .b($signed(diff_o0_x_r[37])), .y(K_ZGx_temp_0[0]));
  mul_q16 u_mul1 (.a($signed(d1_1_q16)), .b($signed(diff_o1_x_r[37])), .y(K_ZGx_temp_0[1]));
  mul_q16 u_mul2 (.a($signed(d1_2_q16)), .b($signed(diff_o2_x_r[37])), .y(K_ZGx_temp_0[2]));
  mul_q16 u_mul3 (.a($signed(d1_0_q16)), .b($signed(diff_o0_y_r[37])), .y(K_ZGy_temp_0[0]));
  mul_q16 u_mul4 (.a($signed(d1_1_q16)), .b($signed(diff_o1_y_r[37])), .y(K_ZGy_temp_0[1]));
  mul_q16 u_mul5 (.a($signed(d1_2_q16)), .b($signed(diff_o2_y_r[37])), .y(K_ZGy_temp_0[2]));
  mul_q16 u_mul6 (.a($signed(d1_0_q16)), .b($signed(diff_o0_z_r[37])), .y(K_ZGz_temp_0[0]));
  mul_q16 u_mul7 (.a($signed(d1_1_q16)), .b($signed(diff_o1_z_r[37])), .y(K_ZGz_temp_0[1]));
  mul_q16 u_mul8 (.a($signed(d1_2_q16)), .b($signed(diff_o2_z_r[37])), .y(K_ZGz_temp_0[2]));

  always @(posedge aclk) begin
    for(i=0; i<3; i=i+1) begin
      K_ZGx_temp_1[i] <= K_ZGx_temp_0[i];
      K_ZGy_temp_1[i] <= K_ZGy_temp_0[i];
      K_ZGz_temp_1[i] <= K_ZGz_temp_0[i];
      K_ZGx[i] <= K_ZGx_temp_1[i];
      K_ZGy[i] <= K_ZGy_temp_1[i];
      K_ZGz[i] <= K_ZGz_temp_1[i];
    end
  end
  
  wire signed [31:0] K_Z [0:INT_NUM-1];
  ////////// xa - i[0] //////////
  wire [DATA_WIDTH:0] diff_x_i0 = normalize_x - int_x[0];
  wire [DATA_WIDTH:0] diff_y_i0 = normalize_y - int_y[0];
  wire [DATA_WIDTH:0] diff_z_i0 = normalize_z - int_z[0];

  wire [16:0] cordic_x_i0 = diff_x_i0[16]? (~diff_x_i0+1): diff_x_i0; // q16
  wire [16:0] cordic_y_i0 = diff_y_i0[16]? (~diff_y_i0+1): diff_y_i0; // q16
  wire [16:0] cordic_z_i0 = diff_z_i0[16]? (~diff_z_i0+1): diff_z_i0; // q16

  wire [31: 0] ri0;
  CORDIC_Vector cov_i0 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i0), // q16
    .Input_y   (cordic_y_i0), // q16
    .Input_z   (cordic_z_i0), // q16
    .Output_xn (ri0) // q16
  );

  cubic_cov cc0 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri0),
    .ans_q16(K_Z[0])
  );

  ////////// xa - i[1] //////////
  wire [DATA_WIDTH:0] diff_x_i1 = normalize_x - int_x[1];
  wire [DATA_WIDTH:0] diff_y_i1 = normalize_y - int_y[1];
  wire [DATA_WIDTH:0] diff_z_i1 = normalize_z - int_z[1];

  wire [16:0] cordic_x_i1 = diff_x_i1[16]? (~diff_x_i1+1): diff_x_i1; // q16
  wire [16:0] cordic_y_i1 = diff_y_i1[16]? (~diff_y_i1+1): diff_y_i1; // q16
  wire [16:0] cordic_z_i1 = diff_z_i1[16]? (~diff_z_i1+1): diff_z_i1; // q16

  wire [31: 0] ri1;
  CORDIC_Vector cov_i1 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i1), // q16
    .Input_y   (cordic_y_i1), // q16
    .Input_z   (cordic_z_i1), // q16
    .Output_xn (ri1) // q16
  );

  cubic_cov cc1 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri1),
    .ans_q16(K_Z[1])
  );

  ////////// xa - i[2] //////////
  wire [DATA_WIDTH:0] diff_x_i2 = normalize_x - int_x[2];
  wire [DATA_WIDTH:0] diff_y_i2 = normalize_y - int_y[2];
  wire [DATA_WIDTH:0] diff_z_i2 = normalize_z - int_z[2];

  wire [16:0] cordic_x_i2 = diff_x_i2[16]? (~diff_x_i2+1): diff_x_i2; // q16
  wire [16:0] cordic_y_i2 = diff_y_i2[16]? (~diff_y_i2+1): diff_y_i2; // q16
  wire [16:0] cordic_z_i2 = diff_z_i2[16]? (~diff_z_i2+1): diff_z_i2; // q16

  wire [31: 0] ri2;
  CORDIC_Vector cov_i2 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i2), // q16
    .Input_y   (cordic_y_i2), // q16
    .Input_z   (cordic_z_i2), // q16
    .Output_xn (ri2) // q16
  );

  cubic_cov cc2 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri2),
    .ans_q16(K_Z[2])
  );

  ////////// xa - i[3] //////////
  wire [DATA_WIDTH:0] diff_x_i3 = normalize_x - int_x[3];
  wire [DATA_WIDTH:0] diff_y_i3 = normalize_y - int_y[3];
  wire [DATA_WIDTH:0] diff_z_i3 = normalize_z - int_z[3];

  wire [16:0] cordic_x_i3 = diff_x_i3[16]? (~diff_x_i3+1): diff_x_i3; // q16
  wire [16:0] cordic_y_i3 = diff_y_i3[16]? (~diff_y_i3+1): diff_y_i3; // q16
  wire [16:0] cordic_z_i3 = diff_z_i3[16]? (~diff_z_i3+1): diff_z_i3; // q16

  wire [31: 0] ri3;
  CORDIC_Vector cov_i3 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i3), // q16
    .Input_y   (cordic_y_i3), // q16
    .Input_z   (cordic_z_i3), // q16
    .Output_xn (ri3) // q16
  );

  cubic_cov cc3 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri3),
    .ans_q16(K_Z[3])
  );

  ////////// xa - i[4] //////////
  wire [DATA_WIDTH:0] diff_x_i4 = normalize_x - int_x[4]; // overflow
  wire [DATA_WIDTH:0] diff_y_i4 = normalize_y - int_y[4];
  wire [DATA_WIDTH:0] diff_z_i4 = normalize_z - int_z[4];

  wire [16:0] cordic_x_i4 = diff_x_i4[16]? (~diff_x_i4+1): diff_x_i4; // q16
  wire [16:0] cordic_y_i4 = diff_y_i4[16]? (~diff_y_i4+1): diff_y_i4; // q16
  wire [16:0] cordic_z_i4 = diff_z_i4[16]? (~diff_z_i4+1): diff_z_i4; // q16

  wire [31: 0] ri4;
  CORDIC_Vector cov_i4 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i4), // q16
    .Input_y   (cordic_y_i4), // q16
    .Input_z   (cordic_z_i4), // q16
    .Output_xn (ri4) // q16
  );

  cubic_cov cc4 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri4),
    .ans_q16(K_Z[4])
  );

  ////////// xa - i[5] //////////
  wire [DATA_WIDTH:0] diff_x_i5 = normalize_x - int_x[5];
  wire [DATA_WIDTH:0] diff_y_i5 = normalize_y - int_y[5];
  wire [DATA_WIDTH:0] diff_z_i5 = normalize_z - int_z[5];

  wire [16:0] cordic_x_i5 = diff_x_i5[16]? (~diff_x_i5+1): diff_x_i5; // q16
  wire [16:0] cordic_y_i5 = diff_y_i5[16]? (~diff_y_i5+1): diff_y_i5; // q16
  wire [16:0] cordic_z_i5 = diff_z_i5[16]? (~diff_z_i5+1): diff_z_i5; // q16

  wire [31: 0] ri5;
  CORDIC_Vector cov_i5 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x   (cordic_x_i5), // q16
    .Input_y   (cordic_y_i5), // q16
    .Input_z   (cordic_z_i5), // q16
    .Output_xn (ri5) // q16
  );

  cubic_cov cc5 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(ri5),
    .ans_q16(K_Z[5])
  );

  //wire [31:0] diff_K_Z [0:INT_NUM-3];
  //assign diff_K_Z[0] = K_Z[0] - K_Z[1];
  //assign diff_K_Z[1] = K_Z[0] - K_Z[2];
  //assign diff_K_Z[2] = K_Z[3] - K_Z[4];
  //assign diff_K_Z[3] = K_Z[3] - K_Z[5];

  reg [31:0] diff_K_Z [0:INT_NUM-3];
  always @(posedge aclk) begin
    diff_K_Z[0] <= K_Z[0] - K_Z[1];
    diff_K_Z[1] <= K_Z[0] - K_Z[2];
    diff_K_Z[2] <= K_Z[3] - K_Z[4];
    diff_K_Z[3] <= K_Z[3] - K_Z[5];
  end

  wire [31:0] answer [0:3*ORI_NUM+INT_NUM];
  mul_q16 u_mul9  (.a($signed(weight[ 0])), .b($signed(        K_ZGx[ 0])), .y(answer[ 0]));
  mul_q16 u_mul10 (.a($signed(weight[ 1])), .b($signed(        K_ZGx[ 1])), .y(answer[ 1]));
  mul_q16 u_mul11 (.a($signed(weight[ 2])), .b($signed(        K_ZGx[ 2])), .y(answer[ 2]));
  mul_q16 u_mul12 (.a($signed(weight[ 3])), .b($signed(        K_ZGy[ 0])), .y(answer[ 3]));
  mul_q16 u_mul13 (.a($signed(weight[ 4])), .b($signed(        K_ZGy[ 1])), .y(answer[ 4]));
  mul_q16 u_mul14 (.a($signed(weight[ 5])), .b($signed(        K_ZGy[ 2])), .y(answer[ 5]));
  mul_q16 u_mul15 (.a($signed(weight[ 6])), .b($signed(        K_ZGz[ 0])), .y(answer[ 6]));
  mul_q16 u_mul16 (.a($signed(weight[ 7])), .b($signed(        K_ZGz[ 1])), .y(answer[ 7]));
  mul_q16 u_mul17 (.a($signed(weight[ 8])), .b($signed(        K_ZGz[ 2])), .y(answer[ 8]));
  mul_q16 u_mul18 (.a($signed(weight[ 9])), .b($signed(     diff_K_Z[ 0])), .y(answer[ 9]));
  mul_q16 u_mul19 (.a($signed(weight[10])), .b($signed(     diff_K_Z[ 1])), .y(answer[10]));
  mul_q16 u_mul20 (.a($signed(weight[11])), .b($signed(     diff_K_Z[ 2])), .y(answer[11]));
  mul_q16 u_mul21 (.a($signed(weight[12])), .b($signed(     diff_K_Z[ 3])), .y(answer[12]));
  mul_q16 u_mul22 (.a($signed(weight[13])), .b($signed(normalize_x_r[39])), .y(answer[13]));
  mul_q16 u_mul23 (.a($signed(weight[14])), .b($signed(normalize_y_r[39])), .y(answer[14]));
  mul_q16 u_mul24 (.a($signed(weight[15])), .b($signed(normalize_z_r[39])), .y(answer[15]));

  reg [31:0] add_temp1, add_temp2, add_temp3, add_temp4, add_temp5, add_temp6, add_temp7, add_temp8; 
  reg [31:0] field;
  always @(posedge aclk) begin
    add_temp1 <= answer[ 0] + answer[ 1];
    add_temp2 <= answer[ 2] + answer[ 3];
    add_temp3 <= answer[ 4] + answer[ 5];
    add_temp4 <= answer[ 6] + answer[ 7];
    add_temp5 <= answer[ 8] + answer[ 9];
    add_temp6 <= answer[10] + answer[11];
    add_temp7 <= answer[12] + answer[13];
    add_temp8 <= answer[14] + answer[15];
    field <= (add_temp1 + add_temp2) + 
             (add_temp3 + add_temp4) +
             (add_temp5 + add_temp6) +
             (add_temp7 + add_temp8);
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
