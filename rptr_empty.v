module rptr_empty #(
    parameter ADDR_WIDTH = 4
)(
    input wire                      rclk
   ,input wire                      rrst_n
   ,input wire                      rinc
   ,input wire    [ADDR_WIDTH:0]    rq2_wptr
   ,output reg                      rempty
   ,output wire   [ADDR_WIDTH-1:0]  raddr
   ,output reg    [ADDR_WIDTH:0]    rptr
);

    reg   [ADDR_WIDTH:0]   rbin
   ;wire  [ADDR_WIDTH:0]   rbin_next
   ;wire  [ADDR_WIDTH:0]   rgray_next
   ;wire                   rempty_val
   ;

    assign rbin_next    = rbin + (rinc & ~rempty);
    assign rgray_next   = (rbin_next >> 1) ^ rbin_next;
    assign raddr        = rbin[ADDR_WIDTH-1:0];


    // rprt = synced wptr
    assign rempty_val   = (rgray_next == rq2_wptr);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin    <= {(ADDR_WIDTH+1){1'b0}};
            rptr    <= {(ADDR_WIDTH+!){1'b0}};
            rempty  <= 1'b1;
        end else begin
            rbin    <= rbin_next;
            rptr    <= rgray_next;
            rempty  <= rempty_val;
        end
    end
endmodule