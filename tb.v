`timescale 1ns/1ps
module tb;
  localparam DATA_WIDTH = 16;
  localparam OUT_WIDTH  = 16;
  localparam LANES      = 4;
  
  reg                        aclk;
  reg                        aresetn;
  
  // AXIS in
  reg  [LANES*DATA_WIDTH-1:0] s_tdata;
  reg                         s_tvalid;
  wire                        s_tready;
  reg                         s_tlast;
  
  // AXIS out
  wire [LANES*OUT_WIDTH-1:0]  m_tdata;
  wire                        m_tvalid;
  reg                         m_tready;
  wire                        m_tlast;
  
  top dut(
    .s00_axis_aclk    (aclk),
    .s00_axis_aresetn (aresetn),
    .s00_axis_tdata   (s_tdata),
    .s00_axis_tvalid  (s_tvalid),
    .s00_axis_tready  (s_tready),
    .s00_axis_tlast   (s_tlast),
    .m00_axis_aclk    (aclk),
    .m00_axis_aresetn (aresetn),
    .m00_axis_tdata   (m_tdata),
    .m00_axis_tvalid  (m_tvalid),
    .m00_axis_tlast   (m_tlast)
  );
  
  initial begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpMDA;
    $fsdbDumpvars;
  end
  
  // clock
  initial aclk = 1'b0;
  always #5 aclk = ~aclk; // 100MHz
  
  integer i;
  reg [DATA_WIDTH-1:0] mat_vals [0:11];
  reg [LANES*DATA_WIDTH-1:0] vec_vals [0:11];

  initial begin
    // init
    aresetn  = 1'b0;
    s_tdata  = {LANES*DATA_WIDTH{1'b0}};
    s_tvalid = 1'b0;
    s_tlast  = 1'b0;
    m_tready = 1'b1; // forever = 1

    // matrix data q16
    mat_vals[0]  = 41; 
    mat_vals[1]  =  0;
    mat_vals[2]  =  0;
    mat_vals[3]  = -20480;
    mat_vals[4]  =  0;
    mat_vals[5]  = 41;
    mat_vals[6]  =  0;
    mat_vals[7]  = -16384;
    mat_vals[8]  =  0;
    mat_vals[9]  =  0;
    mat_vals[10] = 41;
    mat_vals[11] = -17613;
    //for (i=8; i<12; i=i+1) mat_vals[i] = i[DATA_WIDTH-1:0];
    // test vector q16
    vec_vals[0][  DATA_WIDTH-1:            0] = 25; 
    vec_vals[0][2*DATA_WIDTH-1:   DATA_WIDTH] = 25;
    vec_vals[0][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 25;
    vec_vals[0][4*DATA_WIDTH-1: 3*DATA_WIDTH] =  1;
    vec_vals[1][  DATA_WIDTH-1:            0] = 25; 
    vec_vals[1][2*DATA_WIDTH-1:   DATA_WIDTH] = 25;
    vec_vals[1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 75;
    vec_vals[1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =  1;
    vec_vals[2][  DATA_WIDTH-1:            0] = 25; 
    vec_vals[2][2*DATA_WIDTH-1:   DATA_WIDTH] = 25;
    vec_vals[2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 125;
    vec_vals[2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =  1;
    vec_vals[3][  DATA_WIDTH-1:            0] = 65456;
    vec_vals[3][2*DATA_WIDTH-1:   DATA_WIDTH] = 65523;
    vec_vals[3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 20;
    vec_vals[3][4*DATA_WIDTH-1: 3*DATA_WIDTH] = 65478;
    vec_vals[4][  DATA_WIDTH-1:            0] = 76; 
    vec_vals[4][2*DATA_WIDTH-1:   DATA_WIDTH] = 65469;
    vec_vals[4][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 65535;
    vec_vals[4][4*DATA_WIDTH-1: 3*DATA_WIDTH] = 83;
    for (i=5; i<12; i=i+1) begin
      vec_vals[i][  DATA_WIDTH-1:            0]  = (4*i + 0 + 512);  // 低8位，自然截斷
      vec_vals[i][2*DATA_WIDTH-1:   DATA_WIDTH]  = (4*i + 1 + 512);
      vec_vals[i][3*DATA_WIDTH-1: 2*DATA_WIDTH]  = (4*i + 2 + 512);
      vec_vals[i][4*DATA_WIDTH-1: 3*DATA_WIDTH]  = (4*i + 3 + 512);
    end

    // release reset
    #30 aresetn = 1'b1;

    @(posedge aclk);
    s_tvalid <= 1'b1;
    for (i=0; i<3; i=i+1) begin
      s_tdata <= {mat_vals[i*4+3], mat_vals[i*4+2], mat_vals[i*4+1], mat_vals[i*4+0]};
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<12; i=i+1) begin
      s_tdata <= vec_vals[i];
      s_tlast <= (i==11) ? 1'b1 : 1'b0;
      @(posedge aclk);
    end
    s_tvalid <= 1'b0;
    s_tlast  <= 1'b0;

    repeat (50) @(posedge aclk);

    // run again
    @(posedge aclk);
    s_tvalid <= 1'b1;
    for (i=0; i<3; i=i+1) begin
      s_tdata <= {mat_vals[i*4+3], mat_vals[i*4+2], mat_vals[i*4+1], mat_vals[i*4+0]};
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<12; i=i+1) begin
      s_tdata <= vec_vals[i];
      s_tlast <= (i==11) ? 1'b1 : 1'b0;
      @(posedge aclk);
    end
    s_tvalid <= 1'b0;
    s_tlast  <= 1'b0;

    repeat (50) @(posedge aclk);
    $finish;
  end

  always @(posedge aclk) begin
    if (m_tvalid && m_tready) begin
      $display("%0t ns : OUT vld=1 last=%0d data=%h",
        $time, m_tlast, m_tdata);
    end
  end

endmodule
