module async_fifo #(
    parameter DATA_WIDTH       = 8
   , parameter ADDR_WIDTH       = 4
   , parameter ALMOST_FULL_VAL  = 12
   , parameter ALMOST_EMPTY_VAL = 4
)(
    input  wire                  wclk
   ,input  wire                  wrst_n
   ,input  wire                  winc
   ,input  wire [DATA_WIDTH-1:0] wdata
   ,output wire                  wfull
   ,output wire                  almost_full

   ,input  wire                  rclk
   ,input  wire                  rrst_n
   ,input  wire                  rinc
   ,output wire [DATA_WIDTH-1:0] rdata
   ,output wire                  rempty
   ,output wire                  almost_empty
);
    wire [ADDR_WIDTH-1:0] waddr;
    wire [ADDR_WIDTH-1:0] raddr;

    wire [ADDR_WIDTH:0]   wptr;
    wire [ADDR_WIDTH:0]   rptr;

    wire [ADDR_WIDTH:0]   wq2_rptr;
    wire [ADDR_WIDTH:0]   rq2_wptr;



    fifo_mem #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) fifo_mem_inst (
        .wclk   (wclk),
        .winc   (winc),
        .wfull  (wfull),
        .waddr  (waddr),
        .wdata  (wdata),

        .rrst_n (rrst_n),
        .rclk   (rclk),
        .rinc   (rinc),
        .rempty (rempty),
        .raddr  (raddr),
        .rdata  (rdata)
    );
    
    sync_ff #(
        .WIDTH(ADDR_WIDTH + 1)
    ) sync_r2w (
        .clk  (wclk),
        .rst_n(wrst_n),
        .din  (rptr),
        .dout (wq2_rptr)
    );

    sync_ff #(
        .WIDTH(ADDR_WIDTH + 1)
    ) sync_w2r (
        .clk  (rclk),
        .rst_n(rrst_n),
        .din  (wptr),
        .dout (rq2_wptr)
    );


    wptr_full #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ALMOST_FULL_VAL(ALMOST_FULL_VAL)
    ) wptr_inst (
        .wclk        (wclk),
        .wrst_n      (wrst_n),
        .winc        (winc),
        .wq2_rptr    (wq2_rptr),
        .wfull       (wfull),
        .almost_full (almost_full),
        .waddr       (waddr),
        .wptr        (wptr)
    );

    rptr_empty #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .ALMOST_EMPTY_VAL(ALMOST_EMPTY_VAL)
    ) rptr_inst (
        .rclk         (rclk),
        .rrst_n       (rrst_n),
        .rinc         (rinc),
        .rq2_wptr     (rq2_wptr),
        .rempty       (rempty),
        .almost_empty (almost_empty),
        .raddr        (raddr),
        .rptr         (rptr)
    );
endmodule