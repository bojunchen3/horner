`timescale 1ns/1ps
module tb;
  localparam DATA_WIDTH = 16;
  localparam OUT_WIDTH  = 16;
  localparam LANES      = 4;

  parameter integer ORI_NUM    = 8;
  parameter integer INT_NUM    = 35;
  parameter integer LAY_NUM    = 5;
  parameter CAL_NUM       = 3;
  parameter WEIGHT_NUM    = 3*ORI_NUM + INT_NUM - LAY_NUM + 3;
  parameter VEC_NUM       = ORI_NUM + INT_NUM + LAY_NUM + CAL_NUM;
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
  reg [DATA_WIDTH*4-1:0]     weight_vals [0:WEIGHT_NUM-1];
  reg [63:0]       mat_vals [0:11];
  reg [LANES*DATA_WIDTH-1:0] vec_vals [0:VEC_NUM-1];

  initial begin
    // init
    aresetn  = 1'b0;
    s_tdata  = {LANES*DATA_WIDTH{1'b0}};
    s_tvalid = 1'b0;
    s_tlast  = 1'b0;
    m_tready = 1'b1; // forever = 1

    // weight data q16
    for (i=0; i<WEIGHT_NUM; i=i+1) begin
      weight_vals[i] = 0;
    end

    weight_vals[0]  = 223630;
    weight_vals[1]  = -280170;
    weight_vals[2]  = -224727;
    weight_vals[3]  = -178575;
    weight_vals[4]  = -253254;
    weight_vals[5]  = 218412;
    weight_vals[6]  = 91236;
    weight_vals[7]  = -41542;
    weight_vals[8]  = 49588;
    weight_vals[9]  = 32800;
    weight_vals[10] = -40370;
    weight_vals[11] = 68917;
    weight_vals[12] = -8619;
    weight_vals[13] = 52427;
    weight_vals[14] = -20063;
    weight_vals[15] = -28905;
    weight_vals[16] = 31289;
    weight_vals[17] = 102723;
    weight_vals[18] = 148733;
    weight_vals[19] = 102330;
    weight_vals[20] = 53781;
    weight_vals[21] = 42362;
    weight_vals[22] = 10315;
    weight_vals[23] = 31181;
    weight_vals[24] = 55713;
    weight_vals[25] = -1381873;
    weight_vals[26] = -1169632;
    weight_vals[27] = -430850;
    weight_vals[28] = 1678113;
    weight_vals[29] = 342978;
    weight_vals[30] = -2139972;
    weight_vals[31] = 241447;
    weight_vals[32] = 4054683;
    weight_vals[33] = -2941342;
    weight_vals[34] = 1005200;
    weight_vals[35] = 1491038;
    weight_vals[36] = -2299722;
    weight_vals[37] = 1579352;
    weight_vals[38] = -3478139;
    weight_vals[39] = 2970766;
    weight_vals[40] = -1283374;
    weight_vals[41] = -89444;
    weight_vals[42] = 1456157;
    weight_vals[43] = 1205270;
    weight_vals[44] = 1434798;
    weight_vals[45] = 454853;
    weight_vals[46] = -1946847;
    weight_vals[47] = -751262;
    weight_vals[48] = -1360790;
    weight_vals[49] = 19479;
    weight_vals[50] = -505014;
    weight_vals[51] = 565089;
    weight_vals[52] = -312332;
    weight_vals[53] = 102181;
    weight_vals[54] = 32700;
    weight_vals[55] = -16767;
    weight_vals[56] = 115236;

    // matrix data q32
    mat_vals[0]  = 2260509; 
    mat_vals[1]  = 0;
    mat_vals[2]  = 0;
    mat_vals[3]  = -1186767225;
    mat_vals[4]  = 0;
    mat_vals[5]  = 2260509;
    mat_vals[6]  = 0;
    mat_vals[7]  = -1017229050;
    mat_vals[8]  = 0;
    mat_vals[9]  = 0;
    mat_vals[10] = 2260509;
    mat_vals[11] = -1152859590;

    // test vector
    for (i=0; i<VEC_NUM; i=i+1) begin
      vec_vals[i] = 0;
    end
    for (i=0; i<VEC_NUM; i=i+1) begin
      vec_vals[i][4*DATA_WIDTH-1: 3*DATA_WIDTH] = 1;
    end

    vec_vals[0][  DATA_WIDTH-1:            0] = 300; // orientation
    vec_vals[0][2*DATA_WIDTH-1:   DATA_WIDTH] = 800;
    vec_vals[0][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 500;
    vec_vals[1][  DATA_WIDTH-1:            0] = 600;
    vec_vals[1][2*DATA_WIDTH-1:   DATA_WIDTH] =   0;
    vec_vals[1][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[2][  DATA_WIDTH-1:            0] = 800;
    vec_vals[2][2*DATA_WIDTH-1:   DATA_WIDTH] = 500;
    vec_vals[2][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[3][  DATA_WIDTH-1:            0] = 200;
    vec_vals[3][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[4][  DATA_WIDTH-1:            0] = 600;
    vec_vals[4][2*DATA_WIDTH-1:   DATA_WIDTH] = 300;
    vec_vals[4][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 700;
    vec_vals[5][  DATA_WIDTH-1:            0] = 100;
    vec_vals[5][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[5][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 700;
    vec_vals[6][  DATA_WIDTH-1:            0] = 900;
    vec_vals[6][2*DATA_WIDTH-1:   DATA_WIDTH] = 700;
    vec_vals[6][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 800;
    vec_vals[7][  DATA_WIDTH-1:            0] = 600;
    vec_vals[7][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[7][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 100;

    vec_vals[8][  DATA_WIDTH-1:            0] = 120; // interface layer 1
    vec_vals[8][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[8][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 140;
    vec_vals[9][  DATA_WIDTH-1:            0] = 800;
    vec_vals[9][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[9][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 100;
    vec_vals[10][  DATA_WIDTH-1:            0] = 450;
    vec_vals[10][2*DATA_WIDTH-1:   DATA_WIDTH] = 180;
    vec_vals[10][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 150;
    vec_vals[11][  DATA_WIDTH-1:            0] = 300;
    vec_vals[11][2*DATA_WIDTH-1:   DATA_WIDTH] = 300;
    vec_vals[11][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[12][  DATA_WIDTH-1:            0] = 700;
    vec_vals[12][2*DATA_WIDTH-1:   DATA_WIDTH] = 550;
    vec_vals[12][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 100;
    vec_vals[13][  DATA_WIDTH-1:            0] = 600;
    vec_vals[13][2*DATA_WIDTH-1:   DATA_WIDTH] = 430;
    vec_vals[13][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 130;
    vec_vals[14][  DATA_WIDTH-1:            0] = 950;
    vec_vals[14][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[14][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;

    vec_vals[15][  DATA_WIDTH-1:            0] = 120; // interface layer 2
    vec_vals[15][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[15][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 240;
    vec_vals[16][  DATA_WIDTH-1:            0] = 800;
    vec_vals[16][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[16][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[17][  DATA_WIDTH-1:            0] = 450;
    vec_vals[17][2*DATA_WIDTH-1:   DATA_WIDTH] = 180;
    vec_vals[17][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 250;
    vec_vals[18][  DATA_WIDTH-1:            0] = 300;
    vec_vals[18][2*DATA_WIDTH-1:   DATA_WIDTH] = 300;
    vec_vals[18][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 300;
    vec_vals[19][  DATA_WIDTH-1:            0] = 700;
    vec_vals[19][2*DATA_WIDTH-1:   DATA_WIDTH] = 550;
    vec_vals[19][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 200;
    vec_vals[20][  DATA_WIDTH-1:            0] = 600;
    vec_vals[20][2*DATA_WIDTH-1:   DATA_WIDTH] = 430;
    vec_vals[20][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 230;
    vec_vals[21][  DATA_WIDTH-1:            0] = 950;
    vec_vals[21][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[21][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 300;

    vec_vals[22][  DATA_WIDTH-1:            0] = 150; // interface layer 3
    vec_vals[22][2*DATA_WIDTH-1:   DATA_WIDTH] = 460;
    vec_vals[22][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 460;
    vec_vals[23][  DATA_WIDTH-1:            0] = 880;
    vec_vals[23][2*DATA_WIDTH-1:   DATA_WIDTH] = 120;
    vec_vals[23][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[24][  DATA_WIDTH-1:            0] = 500;
    vec_vals[24][2*DATA_WIDTH-1:   DATA_WIDTH] = 700;
    vec_vals[24][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 430;
    vec_vals[25][  DATA_WIDTH-1:            0] = 350;
    vec_vals[25][2*DATA_WIDTH-1:   DATA_WIDTH] = 400;
    vec_vals[25][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 400;
    vec_vals[26][  DATA_WIDTH-1:            0] = 700;
    vec_vals[26][2*DATA_WIDTH-1:   DATA_WIDTH] = 500;
    vec_vals[26][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 500;
    vec_vals[27][  DATA_WIDTH-1:            0] =  50;
    vec_vals[27][2*DATA_WIDTH-1:   DATA_WIDTH] = 600;
    vec_vals[27][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 500;
    vec_vals[28][  DATA_WIDTH-1:            0] =1000;
    vec_vals[28][2*DATA_WIDTH-1:   DATA_WIDTH] = 900;
    vec_vals[28][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 390;

    vec_vals[29][  DATA_WIDTH-1:            0] = 125; // interface layer 4
    vec_vals[29][2*DATA_WIDTH-1:   DATA_WIDTH] = 500;
    vec_vals[29][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[30][  DATA_WIDTH-1:            0] = 250;
    vec_vals[30][2*DATA_WIDTH-1:   DATA_WIDTH] = 660;
    vec_vals[30][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[31][  DATA_WIDTH-1:            0] = 375;
    vec_vals[31][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[31][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[32][  DATA_WIDTH-1:            0] = 500;
    vec_vals[32][2*DATA_WIDTH-1:   DATA_WIDTH] = 100;
    vec_vals[32][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[33][  DATA_WIDTH-1:            0] = 625;
    vec_vals[33][2*DATA_WIDTH-1:   DATA_WIDTH] = 800;
    vec_vals[33][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[34][  DATA_WIDTH-1:            0] = 750;
    vec_vals[34][2*DATA_WIDTH-1:   DATA_WIDTH] = 620;
    vec_vals[34][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;
    vec_vals[35][  DATA_WIDTH-1:            0] = 875;
    vec_vals[35][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[35][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 620;

    vec_vals[36][  DATA_WIDTH-1:            0] = 250; // interface layer 5
    vec_vals[36][2*DATA_WIDTH-1:   DATA_WIDTH] = 500;
    vec_vals[36][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 920;
    vec_vals[37][  DATA_WIDTH-1:            0] = 100;
    vec_vals[37][2*DATA_WIDTH-1:   DATA_WIDTH] = 660;
    vec_vals[37][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 850;
    vec_vals[38][  DATA_WIDTH-1:            0] = 330;
    vec_vals[38][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[38][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 860;
    vec_vals[39][  DATA_WIDTH-1:            0] = 450;
    vec_vals[39][2*DATA_WIDTH-1:   DATA_WIDTH] = 100;
    vec_vals[39][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 820;
    vec_vals[40][  DATA_WIDTH-1:            0] = 660;
    vec_vals[40][2*DATA_WIDTH-1:   DATA_WIDTH] = 800;
    vec_vals[40][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 910;
    vec_vals[41][  DATA_WIDTH-1:            0] = 780;
    vec_vals[41][2*DATA_WIDTH-1:   DATA_WIDTH] = 620;
    vec_vals[41][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 810;
    vec_vals[42][  DATA_WIDTH-1:            0] = 940;
    vec_vals[42][2*DATA_WIDTH-1:   DATA_WIDTH] = 200;
    vec_vals[42][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 760;

    vec_vals[ORI_NUM+INT_NUM+0][  DATA_WIDTH-1:            0] =  120; // interface again to get layer reference
    vec_vals[ORI_NUM+INT_NUM+0][2*DATA_WIDTH-1:   DATA_WIDTH] =  600;
    vec_vals[ORI_NUM+INT_NUM+0][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  140;

    vec_vals[ORI_NUM+INT_NUM+1][  DATA_WIDTH-1:            0] =  120;
    vec_vals[ORI_NUM+INT_NUM+1][2*DATA_WIDTH-1:   DATA_WIDTH] =  600;
    vec_vals[ORI_NUM+INT_NUM+1][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  240;
    vec_vals[ORI_NUM+INT_NUM+2][  DATA_WIDTH-1:            0] =  150;
    vec_vals[ORI_NUM+INT_NUM+2][2*DATA_WIDTH-1:   DATA_WIDTH] =  460;
    vec_vals[ORI_NUM+INT_NUM+2][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  460;
    vec_vals[ORI_NUM+INT_NUM+3][  DATA_WIDTH-1:            0] =  125;
    vec_vals[ORI_NUM+INT_NUM+3][2*DATA_WIDTH-1:   DATA_WIDTH] =  500;
    vec_vals[ORI_NUM+INT_NUM+3][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  620;
    vec_vals[ORI_NUM+INT_NUM+4][  DATA_WIDTH-1:            0] =  250;
    vec_vals[ORI_NUM+INT_NUM+4][2*DATA_WIDTH-1:   DATA_WIDTH] =  500;
    vec_vals[ORI_NUM+INT_NUM+4][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  920;

    vec_vals[VEC_NUM-3][  DATA_WIDTH-1:            0] =  25; // input 0
    vec_vals[VEC_NUM-3][2*DATA_WIDTH-1:   DATA_WIDTH] =  75;
    vec_vals[VEC_NUM-3][3*DATA_WIDTH-1: 2*DATA_WIDTH] = 925;
    vec_vals[VEC_NUM-2][  DATA_WIDTH-1:            0] =  25; // input 1
    vec_vals[VEC_NUM-2][2*DATA_WIDTH-1:   DATA_WIDTH] = 175;
    vec_vals[VEC_NUM-2][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  25;
    vec_vals[VEC_NUM-1][  DATA_WIDTH-1:            0] =  25; // input 2
    vec_vals[VEC_NUM-1][2*DATA_WIDTH-1:   DATA_WIDTH] = 225;
    vec_vals[VEC_NUM-1][3*DATA_WIDTH-1: 2*DATA_WIDTH] =  25;

    for (i=0; i < VEC_NUM; i=i+1) begin
      vec_vals[i] = vec_vals[i] <<< 6;
    end

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

    for (i=0; i<12; i=i+1) begin
      s_tdata <= mat_vals[i];
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

    for (i=0; i<12; i=i+1) begin
      s_tdata <= mat_vals[i];
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

    for (i=0; i<12; i=i+1) begin
      s_tdata <= mat_vals[i];
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
