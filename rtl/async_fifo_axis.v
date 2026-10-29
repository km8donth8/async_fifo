module async_fifo_axis #(
    parameter DATA_WIDTH       = 32
   ,parameter KEEP_WIDTH       = DATA_WIDTH / 8
   ,parameter ADDR_WIDTH       = 4
   ,parameter ALMOST_FULL_VAL  = 12
   ,parameter ALMOST_EMPTY_VAL = 4
)(
    // write domain (slave)
    input  wire                    s_axis_aclk
   ,input  wire                    s_axis_aresetn
   ,input  wire                    s_axis_tvalid
   ,output wire                    s_axis_tready
   ,input  wire [DATA_WIDTH-1:0]   s_axis_tdata
   ,input  wire [KEEP_WIDTH-1:0]   s_axis_tkeep
   ,input  wire                    s_axis_tlast
   ,output wire                    s_axis_almost_full

    // read domain (master)
   ,input  wire                    m_axis_aclk
   ,input  wire                    m_axis_aresetn
   ,output wire                    m_axis_tvalid
   ,input  wire                    m_axis_tready
   ,output wire [DATA_WIDTH-1:0]   m_axis_tdata
   ,output wire [KEEP_WIDTH-1:0]   m_axis_tkeep
   ,output wire                    m_axis_tlast
   ,output wire                    m_axis_almost_empty
    // status flags
   ,output wire                    wfull
   ,output wire                    rempty
);

    // total payload width calculation
    localparam PAYLOAD_WIDTH = DATA_WIDTH + KEEP_WIDTH + 1;

    wire                     winc;
    wire                     rinc;
    wire [PAYLOAD_WIDTH-1:0] s_axis_payload;
    wire [PAYLOAD_WIDTH-1:0] fifo_rdata;
    wire                     out_free;

    reg                      m_axis_tvalid_reg;

    // pack into single vector
    assign s_axis_payload = {s_axis_tkeep, s_axis_tlast, s_axis_tdata};

    // AXI S handshakes
    assign winc          = s_axis_tvalid & s_axis_tready;
    assign s_axis_tready = ~wfull;

    // fifo_mem's registered read output is the AXI output register.
    // rdata only loads when rinc is high, so it holds still while stalled.
    assign {m_axis_tkeep, m_axis_tlast, m_axis_tdata} = fifo_rdata;
    assign m_axis_tvalid = m_axis_tvalid_reg;

    // output register can take a new beat if it is empty,
    // or if the current beat is being accepted this cycle
    assign out_free = ~m_axis_tvalid_reg | m_axis_tready;

    // read the next word whenever there is one and the output can take it
    // gives one beat per read clock
    assign rinc = ~rempty & out_free;

    always @(posedge m_axis_aclk or negedge m_axis_aresetn) begin
        if (!m_axis_aresetn) begin
            m_axis_tvalid_reg <= 1'b0;
        end else if (out_free) begin
            m_axis_tvalid_reg <= ~rempty;
        end
    end

    // instantiate async fifo with expanded payload width
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
        .rdata        (fifo_rdata),
        .rempty       (rempty),
        .almost_empty (m_axis_almost_empty)
    );

endmodule