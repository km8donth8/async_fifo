module wptr_full #(
    parameter ADDR_WIDTH = 4
   ,parameter ALMOST_FULL_VAL = 12 // assert almost_full when >= 12 entries
)(
    input wire                      wclk
   ,input wire                      wrst_n
   ,input wire                      winc
   ,input wire  [ADDR_WIDTH:0]      wq2_rptr //synced rptr in wclk domain
   ,output reg                      wfull
   ,output reg                      almost_full
   ,output wire [ADDR_WIDTH-1:0]    waddr
   ,output reg  [ADDR_WIDTH:0]      wptr

);

    reg  [ADDR_WIDTH:0] wbin;
    wire [ADDR_WIDTH:0] wbin_next;
    wire [ADDR_WIDTH:0] wgray_next;
    wire                wfull_val;

    // gray to binary conversion for wq2_rptr
    reg  [ADDR_WIDTH:0] wq2_rptr_bin;
    wire [ADDR_WIDTH:0] w_occupancy;

   function [ADDR_WIDTH:0] gray2bin;
        input [ADDR_WIDTH:0] gray;
        integer i;
        begin
            gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
            end
        end
    endfunction

    always @(*) begin
        wq2_rptr_bin = gray2bin(wq2_rptr);
    end

    // fill level (how many items in the fifo currently from wr perspective)
    assign w_occupancy  = wbin - wq2_rptr_bin;
    assign wbin_next    = wbin + (winc & ~wfull);
    assign wgray_next   = (wbin_next >> 1) ^ wbin_next;
    assign waddr        = wbin[ADDR_WIDTH-1:0];
    assign wfull_val    = (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]});
    
    // almost full logic (combinational)
    wire almost_full_val = (w_occupancy >= ALMOST_FULL_VAL) || wfull;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin        <= {(ADDR_WIDTH+1){1'b0}};
            wptr        <= {(ADDR_WIDTH+1){1'b0}};
            wfull       <= 1'b0;
            almost_full <= 1'b0;
        end else begin
            wbin        <= wbin_next;
            wptr        <= wgray_next;
            wfull       <= wfull_val;
            almost_full <= almost_full_val;
        end
    end
endmodule
