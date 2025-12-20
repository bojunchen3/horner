module top #(
    parameter integer C_S00_AXIS_TDATA_WIDTH = 64,
    parameter integer C_M00_AXIS_TDATA_WIDTH = 64
)(
    // AXI-Stream Slave （DMA MM2S → IP）
    input  wire                                 s00_axis_aclk,    // asynchronous
    input  wire                                 s00_axis_aresetn, // asynchronous active low
    output wire                                 s00_axis_tready,
    input  wire [C_S00_AXIS_TDATA_WIDTH-1:0]    s00_axis_tdata,
    input  wire                                 s00_axis_tlast,
    input  wire                                 s00_axis_tvalid,

    // AXI-Stream Master （IP → DMA S2MM）
    input  wire                                 m00_axis_aclk,
    input  wire                                 m00_axis_aresetn,
    output wire                                 m00_axis_tvalid,
    output wire [C_M00_AXIS_TDATA_WIDTH-1:0]    m00_axis_tdata,
    output wire                                 m00_axis_tlast
);

    wire aclk    = s00_axis_aclk;
    wire aresetn = s00_axis_aresetn;

    process proc (
        .aclk     (aclk),
        .aresetn  (aresetn),
        // Slave AXI-Stream
        .s_tdata  (s00_axis_tdata),
        .s_tlast  (s00_axis_tlast),
        .s_tvalid (s00_axis_tvalid),
        .s_tready (s00_axis_tready),
        // Master AXI-Stream
        .m_tdata  (m00_axis_tdata),
        .m_tlast  (m00_axis_tlast),
        .m_tvalid (m00_axis_tvalid)
    );

endmodule
