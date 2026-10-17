module async_fifo #(
    parameter DATA_WIDTH = 8
   ,parameter ADDR_WIDTH = 4
)(

    // write domain
    input wire                   wclk
   ,input wire                   wrst_n
   ,input wire                   winc
   ,input wire [DATA_WIDTH-1:0]  wdata
   ,output wire                  wfull

   // read domain
   ,input wire                   rclk
   ,input wire                   rrst_n
   ,input wire                   rinc
   ,output wire [DATA_WIDTH-1:0] rdata
   ,output wire                  rempty
);

    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr, rptr;
    wire [ADDR_WIDTH:0]   wq2_rptr, rq2_wptr;

    //sync read ptr into wr clk domain

    sync_ff #(.WIDTH(ADDR_WIDTH + 1)) sync_r2w (
        .clk    (wclk),
        .rst_n  (wrst_n),
        .din    (rptr),
        .dout   (wq2_rptr)
    );

    //dual port memory
    fifo_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) mem_inst (
        .wclk   (wclk),
        .winc   (winc),
        .wfull  (wfull),
        .waddr  (waddr),
        .rclk   (rclk),
        .rinc   (rinc),
        .rempty (rempty),
        .raddr  (raddr),
        .rdata  (rdata)
    );

    //wr ptr and empty generation
    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) wptr_inst (
        .wclk    (wclk),
        .wrst_n  (wrst_n),
        .winc    (winc),
        .wq2_rptr(wq2_rptr),
        .wfull   (wfull),
        .waddr   (waddr),
        .wptr    (wptr)
    );   

    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) rptr_inst (
        .rclk    (rclk),
        .rrst_n  (rrst_n),
        .rinc    (rinc),
        .rq2_wptr(rq2_wptr),
        .rempty  (rempty),
        .raddr   (raddr),
        .rptr    (rptr)
    );

endmodule