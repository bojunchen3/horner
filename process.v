module process #(
  parameter integer DATA_WIDTH = 16,
  parameter integer OUT_WIDTH  = 16,
  parameter integer LANES      = 4,
  parameter integer PIPE_LAT   = 45
)(
  input  wire                          aclk,
  input  wire                          aresetn,

  // AXIS Slave (from DMA MM2S)
  input  wire [LANES*DATA_WIDTH-1:0]   s_tdata,
  input  wire                          s_tvalid,
  output wire                          s_tready,
  input  wire                          s_tlast,

  // AXIS Master (to DMA S2MM)
  output wire [LANES*OUT_WIDTH-1:0]    m_tdata,
    output wire                          m_tvalid,
    output wire                          m_tlast
  );

  // lane0 LSB
  wire [DATA_WIDTH-1:0] lane0 = s_tdata[DATA_WIDTH*1-1:DATA_WIDTH*0];
  wire [DATA_WIDTH-1:0] lane1 = s_tdata[DATA_WIDTH*2-1:DATA_WIDTH*1];
  wire [DATA_WIDTH-1:0] lane2 = s_tdata[DATA_WIDTH*3-1:DATA_WIDTH*2];
  wire [DATA_WIDTH-1:0] lane3 = s_tdata[DATA_WIDTH*4-1:DATA_WIDTH*3];

  assign s_tready = 1'b1;
  wire   s_hand        = s_tvalid & s_tready;

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
  always @* begin
    next_state = state;
    case (state)
      ST_IDLE: begin
        // 等第一個輸入握手再進入 LOAD
        if (s_hand) next_state = ST_LOAD;
      end
      ST_LOAD: begin
        // 每拍固定 4 個元素，裝滿 16 個就進 STREAM
        // 若本拍裝滿（mat_idx==12 且 s_hand），下拍轉 STREAM
        if ((mat_idx == 4'd8) && s_hand)
          next_state = ST_STREAM;
        else
          next_state = ST_LOAD;
      end
      ST_STREAM: begin
        if (m_tlast)
          next_state = ST_IDLE; // 簡單起見，永遠停在 STREAM
      end
      default: next_state = ST_IDLE;
    endcase
  end

  // -------------------------
  // next_mat_idx
  // -------------------------
  always @* begin
    if (next_state == ST_IDLE)
      next_mat_idx = 4'd0;
    else if (next_state == ST_LOAD && s_hand) begin
      if (mat_idx <= 4'd12)
        next_mat_idx = mat_idx + 4'd4;
    end
  end

  // -------------------------
  // state 
  // -------------------------
  integer i;
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      state     <= ST_IDLE;
      mat_idx   <= 4'd0;
      vld_sr    <= {PIPE_LAT{1'b0}};
      lst_sr    <= {PIPE_LAT{1'b0}};
    end else begin
      state   <= next_state;
      mat_idx <= next_mat_idx;
      if (state == ST_STREAM) begin
        vld_sr <= {vld_sr[PIPE_LAT-2:0], s_hand};
        lst_sr <= {lst_sr[PIPE_LAT-2:0], (s_hand & s_tlast)};
      end else begin
        vld_sr <= {PIPE_LAT{1'b0}};
        lst_sr <= {PIPE_LAT{1'b0}};
      end
    end
  end

  always @(negedge aclk or negedge aresetn) begin
    if (!aresetn)
      for (i=0; i<12; i=i+1) mat[i] <= {DATA_WIDTH{1'b0}};
      else begin
        if (ip_load_matrix) begin
          if (mat_idx <= 4'd8) begin
            mat[mat_idx+0] <= lane0;
            mat[mat_idx+1] <= lane1;
            mat[mat_idx+2] <= lane2;
            mat[mat_idx+3] <= lane3;
          end
        end
      end
    end

    // matrix value
    wire [DATA_WIDTH-1:0]  a00,a01,a02,a03,
                           a10,a11,a12,a13,
                           a20,a21,a22,a23;

    assign a00 = mat[ 0]; assign a01 = mat[ 1]; assign a02 = mat[ 2]; assign a03 = mat[ 3];
    assign a10 = mat[ 4]; assign a11 = mat[ 5]; assign a12 = mat[ 6]; assign a13 = mat[ 7];
    assign a20 = mat[ 8]; assign a21 = mat[ 9]; assign a22 = mat[10]; assign a23 = mat[11];

    // only in STREAM state = s_tdata, others = 0
    wire [LANES*DATA_WIDTH-1:0] ip_vector =
      (state == ST_STREAM) ? s_tdata : {LANES*DATA_WIDTH{1'b0}};

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

    wire [OUT_WIDTH-1:0] result0, result1, result2;
    SRT #(
      .DATA_WIDTH (DATA_WIDTH),
      .OUT_WIDTH  (OUT_WIDTH)
    ) srt (
      .aclk        (aclk),
      .aresetn     (aresetn),
      .load_matrix (ip_load_matrix),
      .a00(a00), .a01(a01), .a02(a02), .a03(a03),
      .a10(a10), .a11(a11), .a12(a12), .a13(a13),
      .a20(a20), .a21(a21), .a22(a22), .a23(a23),
      .vector      (ip_vector),
      .result0     (result0), // q16 
      .result1     (result1), // q16
      .result2     (result2)  // q16
    );

    wire [15:0] cordic_x0 = result0[15]? (~result0+1): result0; // q16
    wire [15:0] cordic_y0 = result1[15]? (~result1+1): result1; // q16
    wire [15:0] cordic_z0 = result2[15]? (~result2+1): result2; // q16

    wire [31: 0] Output_xn;
    CORDIC_Vector uut (
      .clk       (aclk),
      .RST_N     (aresetn),
      .Input_x0  (cordic_x0 <<< 15), // q31 (q16+q15)
      .Input_y0  (cordic_y0 <<< 15), // q31
      .Input_z0  (cordic_z0 <<< 15), // q31
      .Output_xn (Output_xn) // q31
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

    wire [31:0] d1_q16;
    cubic_cov_d1 dut1 (
      .clk(aclk),
      .rst_n(aresetn),
      .r_q16(Output_xn >>> 15), // q16
      .ans_q16(d1_q16) // q16
    );

    //assign m_tdata = {result2, result1, result0};
    assign m_tdata = d1_q16;
    assign m_tvalid = vld_sr[PIPE_LAT-1];
    assign m_tlast  = lst_sr[PIPE_LAT-1];

endmodule
