module fifo_mem #(
    parameter DATA_WIDTH = 8
   ,parameter ADDR_WIDTH = 4
)(
    input wire                  wclk
   ,input wire                  winc //increment
   ,input wire                  wfull
   ,input wire [ADDR_WIDTH-1:0] waddr
   ,input wire [DATA_WIDTH-1:0] wdata

   ,input wire                  rclk
   ,input wire                  rrst_n
   ,input wire                  rinc //increment
   ,input wire                  rempty
   ,input wire [ADDR_WIDTH-1:0] raddr
   ,output reg [DATA_WIDTH-1:0] rdata
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    


    // write
    always @(posedge wclk) begin
        if (winc && !wfull) begin
            mem[waddr] <= wdata;
        end
    end

    // read
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
        end else if (rinc && !rempty) begin
            rdata <= mem[raddr];
        end
    end

    // add initial value for rdata for simulation startup
   // initial begin
    //    rdata = {DATA_WIDTH{1'b0}};
    //end

endmodule