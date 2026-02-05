`timescale 1ns/1ps
module tb;
  localparam DATA_WIDTH = 16;
  localparam OUT_WIDTH  = 8;
  localparam LANES      = 4;

  parameter integer ORI_NUM    = 8;
  parameter integer INT_NUM    = 35;
  parameter integer LAY_NUM    = 5;
  parameter WEIGHT_NUM    = 3*ORI_NUM + INT_NUM - LAY_NUM + 3;
  parameter VEC_NUM       = ORI_NUM + INT_NUM + LAY_NUM + 3;
  parameter NUM_PER_LAYER = INT_NUM / LAY_NUM;
  
  reg                        aclk;
  reg                        aresetn;
  
  // AXIS in
  reg  [LANES*DATA_WIDTH-1:0] s_tdata;
  reg                         s_tvalid;
  wire                        s_tready;
  reg                         s_tlast;
  
  // AXIS out
  wire [OUT_WIDTH-1:0]  m_tdata;
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
  reg [64:0]                 CAL_NUM;
  reg [DATA_WIDTH*4-1:0]     weight_vals [0:WEIGHT_NUM-1];
  reg [DATA_WIDTH-1:0]       mat_vals [0:11];
  reg [LANES*DATA_WIDTH-1:0] vec_vals [0:VEC_NUM-1];

  initial begin
    // init
    aresetn  = 1'b0;
    s_tdata  = {LANES*DATA_WIDTH{1'b0}};
    s_tvalid = 1'b0;
    s_tlast  = 1'b0;
    m_tready = 1'b1; // forever = 1

    // CAL_NUM
    CAL_NUM = 3;

    // // weight data q16
    // weight_vals[ 0] =   90764;
    // weight_vals[ 1] = -156769;
    // weight_vals[ 2] = -102156;
    // weight_vals[ 3] =   21288;
    // weight_vals[ 4] =   10942;
    // weight_vals[ 5] =    1842;
    // weight_vals[ 6] =   62610;
    // weight_vals[ 7] =  -30465;
    // weight_vals[ 8] =   29427;
    // weight_vals[ 9] = -792988;
    // weight_vals[10] = 1132107;
    // weight_vals[11] = -337532;
    // weight_vals[12] =  408508;
    // weight_vals[13] =  -36278;
    // weight_vals[14] =  -37493;
    // weight_vals[15] =   88212;

    // weight data q16
    for (i=0; i<WEIGHT_NUM; i=i+1) begin
      weight_vals[i] = 0;
    end
    weight_vals[0]                         =   90816; // orientation
    weight_vals[1]                         = -156904;
    weight_vals[2]                         = -107387;
    weight_vals[3]                         =  -59197;
    weight_vals[ORI_NUM+0]                 =   28982; 
    weight_vals[ORI_NUM+1]                 =    6608;
    weight_vals[ORI_NUM+2]                 =    -329;
    weight_vals[ORI_NUM+3]                 =   35656;
    weight_vals[2*ORI_NUM+0]               =   56328;
    weight_vals[2*ORI_NUM+1]               =  -43784;
    weight_vals[2*ORI_NUM+2]               =   18735;
    weight_vals[2*ORI_NUM+3]               =   18413;
    weight_vals[3*ORI_NUM+0]               = -803416; // interface layer 1
    weight_vals[3*ORI_NUM+1]               =  985578;
    weight_vals[3*ORI_NUM+NUM_PER_LAYER-1] = -368464; // layer 2
    weight_vals[3*ORI_NUM+NUM_PER_LAYER+0] =  336526;
    weight_vals[WEIGHT_NUM-3]              =  -41799; // input
    weight_vals[WEIGHT_NUM-2]              =  -45310;
    weight_vals[WEIGHT_NUM-1]              =  101872;

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

    // test vector
    for (i=0; i<VEC_NUM; i=i+1) begin
      vec_vals[i] = 0;
    end
    vec_vals[0][  DATA_WIDTH-1:            0] = 300; // orientation
    vec_vals[0][2*DATA_WIDTH-1:   DATA_WIDTH] = 800;
    vec_vals[0][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 500;
    vec_vals[0][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[1][  DATA_WIDTH-1:            0] = 600;
    vec_vals[1][2*DATA_WIDTH-1:   DATA_WIDTH] =   0;
    vec_vals[1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[2][  DATA_WIDTH-1:            0] = 800;
    vec_vals[2][2*DATA_WIDTH-1:   DATA_WIDTH] = 500;
    vec_vals[2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[3][  DATA_WIDTH-1:            0] = 200;
    vec_vals[3][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[3][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;

    vec_vals[ORI_NUM+0][  DATA_WIDTH-1:            0] = 120; // interface layer 1
    vec_vals[ORI_NUM+0][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[ORI_NUM+0][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 100;
    vec_vals[ORI_NUM+0][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[ORI_NUM+1][  DATA_WIDTH-1:            0] = 800;
    vec_vals[ORI_NUM+1][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[ORI_NUM+1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[ORI_NUM+1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[ORI_NUM+2][  DATA_WIDTH-1:            0] = 450;
    vec_vals[ORI_NUM+2][2*DATA_WIDTH-1:   DATA_WIDTH] = 180;
    vec_vals[ORI_NUM+2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 250;
    vec_vals[ORI_NUM+2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;

    vec_vals[ORI_NUM+NUM_PER_LAYER+0][  DATA_WIDTH-1:            0] = 150; // layer 2
    vec_vals[ORI_NUM+NUM_PER_LAYER+0][2*DATA_WIDTH-1:   DATA_WIDTH] = 460;
    vec_vals[ORI_NUM+NUM_PER_LAYER+0][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 760;
    vec_vals[ORI_NUM+NUM_PER_LAYER+0][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[ORI_NUM+NUM_PER_LAYER+1][  DATA_WIDTH-1:            0] = 880;
    vec_vals[ORI_NUM+NUM_PER_LAYER+1][2*DATA_WIDTH-1:   DATA_WIDTH] = 120;
    vec_vals[ORI_NUM+NUM_PER_LAYER+1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 700;
    vec_vals[ORI_NUM+NUM_PER_LAYER+1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[ORI_NUM+NUM_PER_LAYER+2][  DATA_WIDTH-1:            0] = 500;
    vec_vals[ORI_NUM+NUM_PER_LAYER+2][2*DATA_WIDTH-1:   DATA_WIDTH] = 700;
    vec_vals[ORI_NUM+NUM_PER_LAYER+2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 730;
    vec_vals[ORI_NUM+NUM_PER_LAYER+2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;

    vec_vals[ORI_NUM+INT_NUM+0][  DATA_WIDTH-1:            0] =  120; // interface again to get layer reference
    vec_vals[ORI_NUM+INT_NUM+0][2*DATA_WIDTH-1:   DATA_WIDTH] =  600;
    vec_vals[ORI_NUM+INT_NUM+0][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  100;
    vec_vals[ORI_NUM+INT_NUM+0][4*DATA_WIDTH-1: 3*DATA_WIDTH] =    1;
    vec_vals[ORI_NUM+INT_NUM+1][  DATA_WIDTH-1:            0] =  150;
    vec_vals[ORI_NUM+INT_NUM+1][2*DATA_WIDTH-1:   DATA_WIDTH] =  460;
    vec_vals[ORI_NUM+INT_NUM+1][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  760;
    vec_vals[ORI_NUM+INT_NUM+1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =    1;
    vec_vals[ORI_NUM+INT_NUM+2][  DATA_WIDTH-1:            0] = 1200; // unuse layer
    vec_vals[ORI_NUM+INT_NUM+2][2*DATA_WIDTH-1:   DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =    1;
    vec_vals[ORI_NUM+INT_NUM+3][  DATA_WIDTH-1:            0] = 1200;
    vec_vals[ORI_NUM+INT_NUM+3][2*DATA_WIDTH-1:   DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+3][4*DATA_WIDTH-1: 3*DATA_WIDTH] =    1;
    vec_vals[ORI_NUM+INT_NUM+4][  DATA_WIDTH-1:            0] = 1200;
    vec_vals[ORI_NUM+INT_NUM+4][2*DATA_WIDTH-1:   DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+4][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 1200;
    vec_vals[ORI_NUM+INT_NUM+4][4*DATA_WIDTH-1: 3*DATA_WIDTH] =    1;

    // vec_vals[VEC_NUM-3][  DATA_WIDTH-1:            0] =  25; // input
    // vec_vals[VEC_NUM-3][2*DATA_WIDTH-1:   DATA_WIDTH] =  25;
    // vec_vals[VEC_NUM-3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 825;
    // vec_vals[VEC_NUM-3][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    // vec_vals[VEC_NUM-2][  DATA_WIDTH-1:            0] =  25;
    // vec_vals[VEC_NUM-2][2*DATA_WIDTH-1:   DATA_WIDTH] =  25;
    // vec_vals[VEC_NUM-2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 875;
    // vec_vals[VEC_NUM-2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    // vec_vals[VEC_NUM-1][  DATA_WIDTH-1:            0] =  25;
    // vec_vals[VEC_NUM-1][2*DATA_WIDTH-1:   DATA_WIDTH] =  25;
    // vec_vals[VEC_NUM-1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 925;
    // vec_vals[VEC_NUM-1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;

    vec_vals[VEC_NUM-3][  DATA_WIDTH-1:            0] = 200; // input
    vec_vals[VEC_NUM-3][2*DATA_WIDTH-1:   DATA_WIDTH] =   0;
    vec_vals[VEC_NUM-3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 600;
    vec_vals[VEC_NUM-3][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[VEC_NUM-2][  DATA_WIDTH-1:            0] = 800;
    vec_vals[VEC_NUM-2][2*DATA_WIDTH-1:   DATA_WIDTH] =   0;
    vec_vals[VEC_NUM-2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[VEC_NUM-2][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;
    vec_vals[VEC_NUM-1][  DATA_WIDTH-1:            0] = 800;
    vec_vals[VEC_NUM-1][2*DATA_WIDTH-1:   DATA_WIDTH] =   0;
    vec_vals[VEC_NUM-1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[VEC_NUM-1][4*DATA_WIDTH-1: 3*DATA_WIDTH] =   1;

    /*
    for (i=7; i<12; i=i+1) begin
      vec_vals[i][  DATA_WIDTH-1:            0]  = (4*i + 0 + 512);  // 低8位，自然截斷
      vec_vals[i][2*DATA_WIDTH-1:   DATA_WIDTH]  = (4*i + 1 + 512);
      vec_vals[i][3*DATA_WIDTH-1: 2*DATA_WIDTH]  = (4*i + 2 + 512);
      vec_vals[i][4*DATA_WIDTH-1: 3*DATA_WIDTH]  = (4*i + 3 + 512);
    end
    */

    // release reset
    #30 aresetn = 1'b1;

    @(posedge aclk);
    s_tvalid <= 1'b1;
    s_tdata  <= CAL_NUM;
    @(posedge aclk);

    for (i=0; i<WEIGHT_NUM; i=i+1) begin
      s_tdata <= weight_vals[i];
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<3; i=i+1) begin
      s_tdata <= {mat_vals[i*4+3], mat_vals[i*4+2], mat_vals[i*4+1], mat_vals[i*4+0]};
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<VEC_NUM; i=i+1) begin
      s_tdata <= vec_vals[i];
      s_tlast <= (i==VEC_NUM) ? 1'b1 : 1'b0;
      @(posedge aclk);
    end
    s_tvalid <= 1'b0;
    s_tlast  <= 1'b0;

    repeat (50) @(posedge aclk);

    // run again
    @(posedge aclk);
    s_tvalid <= 1'b1;
    s_tdata  <= CAL_NUM;
    @(posedge aclk);

    for (i=0; i<WEIGHT_NUM; i=i+1) begin
      s_tdata <= weight_vals[i];
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<3; i=i+1) begin
      s_tdata <= {mat_vals[i*4+3], mat_vals[i*4+2], mat_vals[i*4+1], mat_vals[i*4+0]};
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<VEC_NUM; i=i+1) begin
      s_tdata <= vec_vals[i];
      s_tlast <= (i==VEC_NUM) ? 1'b1 : 1'b0;
      @(posedge aclk);
    end
    s_tvalid <= 1'b0;
    s_tlast  <= 1'b0;

    repeat (50) @(posedge aclk);

    // run again
    @(posedge aclk);
    s_tvalid <= 1'b1;
    s_tdata  <= CAL_NUM;
    @(posedge aclk);

    for (i=0; i<WEIGHT_NUM; i=i+1) begin
      s_tdata <= weight_vals[i];
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<3; i=i+1) begin
      s_tdata <= {mat_vals[i*4+3], mat_vals[i*4+2], mat_vals[i*4+1], mat_vals[i*4+0]};
      s_tlast <= 1'b0;
      @(posedge aclk);
    end

    for (i=0; i<VEC_NUM; i=i+1) begin
      s_tdata <= vec_vals[i];
      s_tlast <= (i==VEC_NUM) ? 1'b1 : 1'b0;
      @(posedge aclk);
    end
    s_tvalid <= 1'b0;
    s_tlast  <= 1'b0;

    repeat (60) @(posedge aclk);
    $finish;
  end

  always @(posedge aclk) begin
    if (m_tvalid && m_tready) begin
      $display("%0t ns : OUT vld=1 last=%0d data=%h",
        $time, m_tlast, m_tdata);
    end
  end

endmodule
