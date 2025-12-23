module process #(
  parameter integer DATA_WIDTH = 16,
  parameter integer OUT_WIDTH  = 16,
  parameter integer LANES      = 4,
  parameter integer PIPE_LAT   = 46
)(
  input  wire                        aclk,
  input  wire                        aresetn,

  // AXIS Slave (from DMA MM2S)
  input  wire [LANES*DATA_WIDTH-1:0] s_tdata,
  input  wire                        s_tvalid,
  output wire                        s_tready,
  input  wire                        s_tlast,

  // AXIS Master (to DMA S2MM)
  output wire [LANES*OUT_WIDTH-1:0]  m_tdata,
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

  localparam [1:0] ST_IDLE   = 2'b00;
  localparam [1:0] ST_LOAD   = 2'b01;
  localparam [1:0] ST_STREAM = 2'b10;

  reg [1:0] state, next_state;

  reg [DATA_WIDTH-1:0] mat [0:11];
  reg [3:0]            mat_idx, next_mat_idx;
  reg                  ip_load_matrix;

  reg [PIPE_LAT-1:0] vld_sr;
  reg [PIPE_LAT-1:0] lst_sr;

  // -------------------------
  // next_state
  // -------------------------
  always @(*) begin
    next_state = state;
    case(state)
      ST_IDLE:   begin
                   // 等第一個輸入握手再進入 LOAD
                   if(s_hand) next_state = ST_LOAD;
                 end
      ST_LOAD:   begin
                   // 每拍固定 4 個元素，裝滿 16 個就進 STREAM
                   // 若本拍裝滿（mat_idx==12 且 s_hand），下拍轉 STREAM
                   if((mat_idx == 4'd8) && s_hand)
                     next_state = ST_STREAM;
                   else
                     next_state = ST_LOAD;
                 end
      ST_STREAM: begin
                   if(m_tlast)
                     next_state = ST_IDLE; // 簡單起見，永遠停在 STREAM
                 end
      default:   next_state = ST_IDLE;
    endcase
  end

  // -------------------------
  // next_mat_idx
  // -------------------------
  always @(*) begin
    if(next_state == ST_IDLE)
      next_mat_idx = 4'd0;
    else if(next_state == ST_LOAD && s_hand) begin
      if(mat_idx <= 4'd12)
        next_mat_idx = mat_idx + 4'd4;
    end
  end

  // -------------------------
  // state 
  // -------------------------
  integer i;
  always @(posedge aclk or negedge aresetn) begin
    if(!aresetn) begin
      state   <= ST_IDLE;
      mat_idx <= 4'd0;
      vld_sr  <= {PIPE_LAT{1'b0}};
      lst_sr  <= {PIPE_LAT{1'b0}};
    end else begin
      state   <= next_state;
      mat_idx <= next_mat_idx;
      if(state == ST_STREAM) begin
        vld_sr <= {vld_sr[PIPE_LAT-2:0], s_hand};
        lst_sr <= {lst_sr[PIPE_LAT-2:0], (s_hand & s_tlast)};
      end else begin
        vld_sr <= {PIPE_LAT{1'b0}};
        lst_sr <= {PIPE_LAT{1'b0}};
      end
    end
  end

  always @(negedge aclk or negedge aresetn) begin
    if(!aresetn)
      for(i=0; i<12; i=i+1)
        mat[i] <= {DATA_WIDTH{1'b0}};
    else begin
      if(ip_load_matrix) begin
        if(mat_idx <= 4'd8) begin
          mat[mat_idx+0] <= lane0;
          mat[mat_idx+1] <= lane1;
          mat[mat_idx+2] <= lane2;
          mat[mat_idx+3] <= lane3;
        end
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
  //   (state == ST_STREAM) ? s_tdata : {LANES*DATA_WIDTH{1'b0}};
  
  reg  [LANES*DATA_WIDTH-1:0] ip_vector;
  always @(*) begin
    if(state == ST_STREAM)
      ip_vector = s_tdata;
    else
      ip_vector = {LANES*DATA_WIDTH{1'b0}};
  end

  reg  [5:0] ori_count;
  always @(posedge aclk) begin
    if(state == ST_STREAM)
      ori_count <= ori_count + 1;
    else
      ori_count <= 0;
  end

  always @(*) begin
    if (!aresetn)
      ip_load_matrix = 0;
    else begin
      if (state == ST_STREAM)
        ip_load_matrix = 0;
      else if (s_hand)
        ip_load_matrix = 1;
      else
        ip_load_matrix = 0;
    end    
  end

  wire [OUT_WIDTH-1:0] normalize_x, normalize_y, normalize_z;
  reg  [OUT_WIDTH-1:0] ori_x [0: 2];
  reg  [OUT_WIDTH-1:0] ori_y [0: 2]; 
  reg  [OUT_WIDTH-1:0] ori_z [0: 2];

  always @(posedge aclk)begin
    if(ori_count > 5 && ori_count < 9) begin
      ori_x[ori_count - 6] = normalize_x;  
      ori_y[ori_count - 6] = normalize_y; 
      ori_z[ori_count - 6] = normalize_z; 
    end
  end

  SRT #(
    .DATA_WIDTH (DATA_WIDTH),
    .OUT_WIDTH  (OUT_WIDTH)
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

  ////////// 0[0] - xa //////////
  wire [OUT_WIDTH-1:0] diff_0_x = ori_x[0] - normalize_x;
  wire [OUT_WIDTH-1:0] diff_0_y = ori_y[0] - normalize_y;
  wire [OUT_WIDTH-1:0] diff_0_z = ori_z[0] - normalize_z;

  reg [OUT_WIDTH-1:0] diff_0_x_r[0:37];
  reg [OUT_WIDTH-1:0] diff_0_y_r[0:37];
  reg [OUT_WIDTH-1:0] diff_0_z_r[0:37];

  always @(posedge aclk) begin
    diff_0_x_r[0] <= diff_0_x;
    diff_0_y_r[0] <= diff_0_y;
    diff_0_z_r[0] <= diff_0_z;
    for (i=1; i<38; i=i+1) begin
      diff_0_x_r[i] <= diff_0_x_r[i-1];
      diff_0_y_r[i] <= diff_0_y_r[i-1];
      diff_0_z_r[i] <= diff_0_z_r[i-1];
    end
  end

  wire [15:0] cordic_0_x = diff_0_x[15]? (~diff_0_x+1): diff_0_x; // q16
  wire [15:0] cordic_0_y = diff_0_y[15]? (~diff_0_y+1): diff_0_y; // q16
  wire [15:0] cordic_0_z = diff_0_z[15]? (~diff_0_z+1): diff_0_z; // q16

  wire [31: 0] r0;
  CORDIC_Vector uut (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x0  (cordic_0_x), // q16
    .Input_y0  (cordic_0_y), // q16
    .Input_z0  (cordic_0_z), // q16
    .Output_xn (r0) // q16
  );

  ////////// 0[1] - xa //////////
  wire [OUT_WIDTH-1:0] diff_1_x = ori_x[1] - normalize_x;
  wire [OUT_WIDTH-1:0] diff_1_y = ori_y[1] - normalize_y;
  wire [OUT_WIDTH-1:0] diff_1_z = ori_z[1] - normalize_z;

  reg  [OUT_WIDTH-1:0] diff_1_x_r[0:37];
  reg  [OUT_WIDTH-1:0] diff_1_y_r[0:37];
  reg  [OUT_WIDTH-1:0] diff_1_z_r[0:37];

  always @(posedge aclk) begin
    diff_1_x_r[0] <= diff_1_x;
    diff_1_y_r[0] <= diff_1_y;
    diff_1_z_r[0] <= diff_1_z;
    for (i=1; i<38; i=i+1) begin
      diff_1_x_r[i] <= diff_1_x_r[i-1];
      diff_1_y_r[i] <= diff_1_y_r[i-1];
      diff_1_z_r[i] <= diff_1_z_r[i-1];
    end
  end

  wire [15:0] cordic_1_x = diff_1_x[15]? (~diff_1_x+1): diff_1_x; // q16
  wire [15:0] cordic_1_y = diff_1_y[15]? (~diff_1_y+1): diff_1_y; // q16
  wire [15:0] cordic_1_z = diff_1_z[15]? (~diff_1_z+1): diff_1_z; // q16

  wire [31: 0] r1;
  CORDIC_Vector uut1 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x0  (cordic_1_x), // q16
    .Input_y0  (cordic_1_y), // q16
    .Input_z0  (cordic_1_z), // q16
    .Output_xn (r1) // q16
  );

  ////////// 0[2] - xa //////////
  wire [OUT_WIDTH-1:0] diff_2_x = ori_x[2] - normalize_x;
  wire [OUT_WIDTH-1:0] diff_2_y = ori_y[2] - normalize_y;
  wire [OUT_WIDTH-1:0] diff_2_z = ori_z[2] - normalize_z;

  reg [OUT_WIDTH-1:0] diff_2_x_r[0:37];
  reg [OUT_WIDTH-1:0] diff_2_y_r[0:37];
  reg [OUT_WIDTH-1:0] diff_2_z_r[0:37];

  always @(posedge aclk) begin
    diff_2_x_r[0] <= diff_2_x;
    diff_2_y_r[0] <= diff_2_y;
    diff_2_z_r[0] <= diff_2_z;
    for (i=1; i<38; i=i+1) begin
      diff_2_x_r[i] <= diff_2_x_r[i-1];
      diff_2_y_r[i] <= diff_2_y_r[i-1];
      diff_2_z_r[i] <= diff_2_z_r[i-1];
    end
  end

  wire [15:0] cordic_2_x = diff_2_x[15]? (~diff_2_x+1): diff_2_x; // q16
  wire [15:0] cordic_2_y = diff_2_y[15]? (~diff_2_y+1): diff_2_y; // q16
  wire [15:0] cordic_2_z = diff_2_z[15]? (~diff_2_z+1): diff_2_z; // q16

  wire [31: 0] r2;
  CORDIC_Vector uut2 (
    .clk       (aclk),
    .RST_N     (aresetn),
    .Input_x0  (cordic_2_x), // q16
    .Input_y0  (cordic_2_y), // q16
    .Input_z0  (cordic_2_z), // q16
    .Output_xn (r2) // q16
  );

  /*
  wire [31:0] d0_q16;
  cubic_cov dut (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(Output_xn >>> 15),
    .ans_q16(d0_q16)
  );
  */

  wire [31:0] d1_0_q16;
  cubic_cov_d1 ccd0 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(r0), // q16
    .ans_q16(d1_0_q16) // q16
  );

  wire [31:0] d1_1_q16;
  cubic_cov_d1 ccd1 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(r1), // q16
    .ans_q16(d1_1_q16) // q16
  );

  wire [31:0] d1_2_q16;
  cubic_cov_d1 ccd2 (
    .clk(aclk),
    .rst_n(aresetn),
    .r_q16(r2), // q16
    .ans_q16(d1_2_q16) // q16
  );

  wire signed [31:0] K_ZGx [0:2];
  wire signed [31:0] K_ZGy [0:2];
  wire signed [31:0] K_ZGz [0:2];

  mul_q16 u_mul0 (.a(d1_0_q16), .b($signed(diff_0_x_r[37])), .y(K_ZGx[0]));
  mul_q16 u_mul1 (.a(d1_1_q16), .b($signed(diff_1_x_r[37])), .y(K_ZGx[1]));
  mul_q16 u_mul2 (.a(d1_2_q16), .b($signed(diff_2_x_r[37])), .y(K_ZGx[2]));
  mul_q16 u_mul3 (.a(d1_0_q16), .b($signed(diff_0_y_r[37])), .y(K_ZGy[0]));
  mul_q16 u_mul4 (.a(d1_1_q16), .b($signed(diff_1_y_r[37])), .y(K_ZGy[1]));
  mul_q16 u_mul5 (.a(d1_2_q16), .b($signed(diff_2_y_r[37])), .y(K_ZGy[2]));
  mul_q16 u_mul6 (.a(d1_0_q16), .b($signed(diff_0_z_r[37])), .y(K_ZGz[0]));
  mul_q16 u_mul7 (.a(d1_1_q16), .b($signed(diff_1_z_r[37])), .y(K_ZGz[1]));
  mul_q16 u_mul8 (.a(d1_2_q16), .b($signed(diff_2_z_r[37])), .y(K_ZGz[2]));
  
  /*
  assign K_ZGx[0] = ($signed(d1_0_q16) * $signed(diff_0_x_r[37])) >>> 16;
  assign K_ZGx[1] = ($signed(d1_1_q16) * $signed(diff_1_x_r[37])) >>> 16;
  assign K_ZGx[2] = ($signed(d1_2_q16) * $signed(diff_2_x_r[37])) >>> 16;
  assign K_ZGy[0] = ($signed(d1_0_q16) * $signed(diff_0_y_r[37])) >>> 16;
  assign K_ZGy[1] = ($signed(d1_1_q16) * $signed(diff_1_y_r[37])) >>> 16;
  assign K_ZGy[2] = ($signed(d1_2_q16) * $signed(diff_2_y_r[37])) >>> 16;
  assign K_ZGz[0] = ($signed(d1_0_q16) * $signed(diff_0_z_r[37])) >>> 16;
  assign K_ZGz[1] = ($signed(d1_1_q16) * $signed(diff_1_z_r[37])) >>> 16;
  assign K_ZGz[2] = ($signed(d1_2_q16) * $signed(diff_2_z_r[37])) >>> 16;
  */

  //assign m_tdata = {normalize_z, normalize_y, normalize_x};
  //assign m_tdata = ($signed(d1_q16) * $signed(diff_x_r[37]));
  assign m_tdata = K_ZGx[0]; 
  assign m_tvalid = vld_sr[PIPE_LAT-2];
  assign m_tlast  = lst_sr[PIPE_LAT-2];

endmodule
