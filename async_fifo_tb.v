
`timescale 1ns / 1ps

module async_fifo_tb;

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam DEPTH      = 1 << ADDR_WIDTH;

    //wclk = 100 MHz
    //rclk = ~40 MHz

    localparam WCLK_PERIOD = 10;
    localparam RCLK_PERIOD = 25;

    // DUT signals
    reg                     wclk;
    reg                     wrst_n;
    reg                     winc;
    reg [DATA_WIDTH-1:0]    wdata;
    wire                    wfull;

    reg                     rclk;
    reg                     rrst_n;
    reg                     rinc;
    reg [DATA_WIDTH-1:0]    rdata;
    wire                    rempty;     

    //verification
    reg [DATA_WIDTH-1:0] exp_queue [0:1023];
    integer q_wr_ptr = 0;
    integer q_rd_ptr = 0;
    integer error = 0;      

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wclk  (wclk),
        .wrst_n(wrst_n),
        .winc  (winc),
        .wdata (wdata),
        .wfull (wfull),

        .rclk  (rclk),
        .rrst_n(rrst_n),
        .rinc  (rinc),
        .rdata (rdata),
        .rempty(rempty)
    );


        // clk gen
        initial begin
            wclk = 0;
            forever #(WCLK_PERIOD / 2) wclk = ~wclk;
        end

        initial begin
            rclk = 0;
            forever #(RCLK_PERIOD / 2) rclk = ~rclk;
        end

        // write and read operation tests
        task write_byte(input [DATA_WIDTH-1:0] data);
        begin
            @(posedge wclk);
            winc  <= 1'b1;
            wdata <= data;
            if (!wfull) begin
                exp_queue[q_wr_ptr] = data;
                q_wr_ptr = q_wr_ptr + 1;
            end
            @(posedge wclk);
            winc  <= 1'b0;
            wdata <= {DATA_WIDTH{1'bx}};
        end
    endtask


        task read_byte();
        reg [DATA_WIDTH-1:0] expected_data;
        begin
            @(posedge rclk);
            if (!rempty) begin
                rinc <= 1'b1;
                exp_data = exp_queue[q_rd_ptr];
                q_rd_ptr = q_rd_ptr + 1;

                @(posedge rclk);
                rinc <= 1'b0;

                // check rdata output
                if (rdata !== exp_data) begin
                    $display("[ERROR] Time %0t: Data mismatch! Expected: 0x%02h, Got: 0x%02h", 
                             $time, exp_data, rdata);
                    error = error + 1;
                end
            end else begin
                $display("[WARN] Time %0t: Read attempted while FIFO is empty.", $time);
                rinc <= 1'b0;
            end
        end
    endtask

    integer i;

    