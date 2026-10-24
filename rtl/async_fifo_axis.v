module async_fifo_axis #(
    parameter DATA_WIDTH       = 32
   , parameter KEEP_WIDTH       = DATA_WIDTH / 8
   , parameter ADDR_WIDTH       = 4
   , parameter ALMOST_FULL_VAL  = 12
   , parameter ALMOST_EMPTY_VAL = 4
)(
    // write doman (slave)
    input  wire                    s_axis_aclk
   , input  wire                    s_axis_aresetn
   , input  wire                    s_axis_tvalid
   , output wire                    s_axis_tready
   , input  wire [DATA_WIDTH-1:0]   s_axis_tdata
   , input  wire [KEEP_WIDTH-1:0]   s_axis_tkeep
   , input  wire                    s_axis_tlast
   , output wire                    s_axis_almost_full

    // read domain (master)
   , input  wire                    m_axis_aclk
   , input  wire                    m_axis_aresetn
   , output wire                    m_axis_tvalid
   , input  wire                    m_axis_tready
   , output wire [DATA_WIDTH-1:0]   m_axis_tdata
   , output wire [KEEP_WIDTH-1:0]   m_axis_tkeep
   , output wire                    m_axis_tlast
   , output wire                    m_axis_almost_empty
    // status flags
   , output wire                    wfull
   , output wire                    rempty
);

    // total payload width calculation
    localparam PAYLOAD_WIDTH = DATA_WIDTH + KEEP_WIDTH + 1;

    wire                     winc;
    wire                     rinc;
    wire [PAYLOAD_WIDTH-1:0] s_axis_payload;
    wire [PAYLOAD_WIDTH-1:0] m_axis_payload;

    // pack into single vector
    assign s_axis_payload = {s_axis_tkeep, s_axis_tlast, s_axis_tdata};

    // unpack 
    assign {m_axis_tkeep, m_axis_tlast, m_axis_tdata} = m_axis_payload;

    // AXI S handshakes
    assign winc          = s_axis_tvalid & s_axis_tready;
    assign s_axis_tready = ~wfull;

    assign rinc          = m_axis_tvalid & m_axis_tready;
    assign m_axis_tvalid = ~rempty;

    // instantiate async fifo with expanded paylaod width
    async_fifo #(
        .DATA_WIDTH       (PAYLOAD_WIDTH),
        .ADDR_WIDTH       (ADDR_WIDTH),
        .ALMOST_FULL_VAL  (ALMOST_FULL_VAL),
        .ALMOST_EMPTY_VAL (ALMOST_EMPTY_VAL)
    ) fifo_core (
        .wclk         (s_axis_aclk),
        .wrst_n       (s_axis_aresetn),
        .winc         (winc),
        .wdata        (s_axis_payload),
        .wfull        (wfull),
        .almost_full  (s_axis_almost_full),

        .rclk         (m_axis_aclk),
        .rrst_n       (m_axis_aresetn),
        .rinc         (rinc),
        .rdata        (m_axis_payload),
        .rempty       (rempty),
        .almost_empty (m_axis_almost_empty)
    );

endmodule