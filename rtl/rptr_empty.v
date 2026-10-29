module rptr_empty #(
    parameter ADDR_WIDTH       = 4
   ,parameter ALMOST_EMPTY_VAL = 4 // assert almost_empty when <= 4 entries left
)(
    input  wire                  rclk
   ,input  wire                  rrst_n
   ,input  wire                  rinc
   ,input  wire [ADDR_WIDTH:0]   rq2_wptr // synced wptr in rclk domain
   ,output reg                   rempty
   ,output reg                   almost_empty
   ,output wire [ADDR_WIDTH-1:0] raddr
   ,output reg  [ADDR_WIDTH:0]   rptr
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;
    wire                rempty_val;

    //gray 2 binary conversion for rq2 wptr
    reg  [ADDR_WIDTH:0] rq2_wptr_bin;
    wire [ADDR_WIDTH:0] r_occupancy;

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
        rq2_wptr_bin = gray2bin(rq2_wptr);
    end

    // fill level (how many items in the fifo currently from read perspective)
    assign r_occupancy   = rq2_wptr_bin - rbin;
    assign rbin_next     = rbin + (rinc & ~rempty);
    assign rgray_next    = (rbin_next >> 1) ^ rbin_next;
    assign raddr         = rbin[ADDR_WIDTH-1:0];
    assign rempty_val    = (rgray_next == rq2_wptr);

    // almost empty logic
    wire almost_empty_val = (r_occupancy <= ALMOST_EMPTY_VAL) || rempty;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin         <= {(ADDR_WIDTH+1){1'b0}};
            rptr         <= {(ADDR_WIDTH+1){1'b0}};
            rempty       <= 1'b1;
            almost_empty <= 1'b1;
        end else begin
            rbin         <= rbin_next;
            rptr         <= rgray_next;
            rempty       <= rempty_val;
            almost_empty <= almost_empty_val;
        end
    end
endmodule