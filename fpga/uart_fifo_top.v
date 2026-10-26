module uart_fifo_top (
    input  wire       sys_clk
   ,input  wire       key_reset
   ,input  wire       uart_rx
   ,output wire       uart_tx
   ,output wire [5:0] led
);

    wire write_clk;
    wire read_clk;
    wire pll_lock;
    wire global_reset_n;
    wire write_reset_n;
    wire read_reset_n;

    assign write_clk = sys_clk;

    //  27 MHz input 13.5 MHz output
    Gowin_rPLL Gowin_rPLL_inst (
        .clkout (read_clk),
        .lock   (pll_lock),
        .clkin  (sys_clk)
    );

    // button active high
    assign global_reset_n = ~key_reset & pll_lock;

    reset_sync write_reset_sync_inst (
        .clk    (write_clk),
        .arst_n (global_reset_n),
        .srst_n (write_reset_n)
    );

    reset_sync read_reset_sync_inst (
        .clk    (read_clk),
        .arst_n (global_reset_n),
        .srst_n (read_reset_n)
    );

    
    wire [7:0] rx_data;
    wire       rx_data_valid;
    wire       rx_frame_error;

    uart_rx #(
        .CLK_FREQ  (27000000),
        .BAUD_RATE (115200)
    ) uart_rx_inst (
        .clk         (write_clk),
        .rst_n       (write_reset_n),
        .rx          (uart_rx),
        .data        (rx_data),
        .data_valid  (rx_data_valid),
        .frame_error (rx_frame_error)
    );

    // FIFO write side, 27Mhz domain
    reg  [7:0] rx_pending_data;
    reg        rx_pending_valid;
    reg        rx_overrun;

    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire [31:0] s_axis_tdata;
    wire [3:0]  s_axis_tkeep;
    wire        s_axis_tlast;
    wire        s_axis_almost_full;
    wire        input_handshake;

    assign s_axis_tvalid = rx_pending_valid;
    assign s_axis_tdata  = {24'd0, rx_pending_data};
    assign s_axis_tkeep  = 4'b0001;
    assign s_axis_tlast  = 1'b1;
    assign input_handshake = s_axis_tvalid & s_axis_tready;

    always @(posedge write_clk or negedge write_reset_n) begin
        if (!write_reset_n) begin
            rx_pending_data  <= 8'd0;
            rx_pending_valid <= 1'b0;
            rx_overrun       <= 1'b0;
        end else begin
            case ({rx_data_valid, input_handshake})
                2'b00: begin
                    rx_pending_valid <= rx_pending_valid;
                end

                2'b01: begin
                    rx_pending_valid <= 1'b0;
                end

                2'b10: begin
                    if (!rx_pending_valid) begin
                        rx_pending_data  <= rx_data;
                        rx_pending_valid <= 1'b1;
                    end else begin
                        rx_overrun <= 1'b1;
                    end
                end

                2'b11: begin
                    rx_pending_data  <= rx_data;
                    rx_pending_valid <= 1'b1;
                end
            endcase
        end
    end

    // FIFO read side, 13.5Mhz domain
    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire [31:0] m_axis_tdata;
    wire [3:0]  m_axis_tkeep;
    wire        m_axis_tlast;
    wire        m_axis_almost_empty;
    wire        wfull;
    wire        rempty;
    wire        tx_data_ready;
    wire        tx_busy;

    uart_tx #(
        .CLK_FREQ  (13500000),
        .BAUD_RATE (115200)
    ) uart_tx_inst (
        .clk        (read_clk),
        .rst_n      (read_reset_n),
        .data       (m_axis_tdata[7:0]),
        .data_valid (m_axis_tvalid),
        .data_ready (tx_data_ready),
        .tx         (uart_tx),
        .busy       (tx_busy)
    );

    // backpressure
    assign m_axis_tready = tx_data_ready;

    async_fifo_axis #(
        .DATA_WIDTH       (32),
        .KEEP_WIDTH       (4),
        .ADDR_WIDTH       (4),
        .ALMOST_FULL_VAL  (12),
        .ALMOST_EMPTY_VAL (4)
    ) async_fifo_axis_inst (
        .s_axis_aclk         (write_clk),
        .s_axis_aresetn      (write_reset_n),
        .s_axis_tvalid       (s_axis_tvalid),
        .s_axis_tready       (s_axis_tready),
        .s_axis_tdata        (s_axis_tdata),
        .s_axis_tkeep        (s_axis_tkeep),
        .s_axis_tlast        (s_axis_tlast),
        .s_axis_almost_full  (s_axis_almost_full),

        .m_axis_aclk         (read_clk),
        .m_axis_aresetn      (read_reset_n),
        .m_axis_tvalid       (m_axis_tvalid),
        .m_axis_tready       (m_axis_tready),
        .m_axis_tdata        (m_axis_tdata),
        .m_axis_tkeep        (m_axis_tkeep),
        .m_axis_tlast        (m_axis_tlast),
        .m_axis_almost_empty (m_axis_almost_empty),

        .wfull               (wfull),
        .rempty              (rempty)
    );

    reg rx_seen;
    reg tx_seen;
    reg full_seen;
    reg frame_error_seen;

    always @(posedge write_clk or negedge write_reset_n) begin
        if (!write_reset_n) begin
            rx_seen          <= 1'b0;
            full_seen        <= 1'b0;
            frame_error_seen <= 1'b0;
        end else begin
            if (rx_data_valid) begin
                rx_seen <= 1'b1;
            end
            if (wfull) begin
                full_seen <= 1'b1;
            end
            if (rx_frame_error) begin
                frame_error_seen <= 1'b1;
            end
        end
    end

    always @(posedge read_clk or negedge read_reset_n) begin
        if (!read_reset_n) begin
            tx_seen <= 1'b0;
        end else if (m_axis_tvalid && m_axis_tready) begin
            tx_seen <= 1'b1;
        end
    end
    //LEds active low...
    assign led[0] = ~pll_lock;
    assign led[1] = ~rx_seen;
    assign led[2] = ~rx_pending_valid;
    assign led[3] = ~tx_seen;
    assign led[4] = ~full_seen;
    assign led[5] = ~(frame_error_seen | rx_overrun);

endmodule
