module tang_nano_20k_fifo_top #(
    parameter TARGET_BEATS = 100000
)(
    input  wire       sys_clk
   ,input  wire       key_reset
   ,output wire [5:0] led
);


    wire write_clk;
    wire read_clk;
    wire pll_lock;

    wire global_reset_n;
    wire write_reset_n;
    wire read_reset_n;

    assign write_clk = sys_clk;

    //gowin pll
    //input 27 MHz
    //output 13.5 MHz
    Gowin_rPLL Gowin_rPLL_inst (
        .clkin  (sys_clk),
        .clkout (read_clk),
        .lock   (pll_lock)
    );

    //hold reset until pll is locked
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

    //master 
    wire        s_axis_tvalid;
    wire        s_axis_tready;
    wire [31:0] s_axis_tdata;
    wire [3:0]  s_axis_tkeep;
    wire        s_axis_tlast;
    wire        s_axis_almost_full;

    //slave
    wire        m_axis_tvalid;
    wire        m_axis_tready;
    wire [31:0] m_axis_tdata;
    wire [3:0]  m_axis_tkeep;
    wire        m_axis_tlast;
    wire        m_axis_almost_empty;

    wire        wfull;
    wire        rempty;

    // source data generator
    //tx count is number of input beats
    reg [31:0] tx_count;
    reg        source_done;
    reg        full_seen;

    assign s_axis_tvalid = ~source_done;
    assign s_axis_tdata  = tx_count;
    assign s_axis_tkeep  = 4'b1111;

   //packet every 16 beats
    assign s_axis_tlast = (tx_count[3:0] == 4'hF);

    always @(posedge write_clk or negedge write_reset_n) begin
        if (!write_reset_n) begin
            tx_count    <= 32'd0;
            source_done <= 1'b0;
            full_seen   <= 1'b0;
        end else begin
            if (wfull) begin
                full_seen <= 1'b1;
            end

            
            if (s_axis_tvalid && s_axis_tready) begin
                if (tx_count == TARGET_BEATS - 1) begin
                    tx_count    <= tx_count;
                    source_done <= 1'b1;
                end else begin
                    tx_count <= tx_count + 1'b1;
                end
            end
        end
    end

    //backpressure generator for testing
    reg [15:0] ready_lfsr;

    always @(posedge read_clk or negedge read_reset_n) begin
        if (!read_reset_n) begin
            ready_lfsr <= 16'h0001;
        end else begin
            ready_lfsr <= {
                ready_lfsr[14:0],
                ready_lfsr[15] ^
                ready_lfsr[13] ^
                ready_lfsr[12] ^
                ready_lfsr[10]
            };
        end
    end

    assign m_axis_tready = ready_lfsr[0] | ready_lfsr[2];

    // read scoreboard
    reg [31:0] expected_count;
    reg [31:0] received_count;
    reg [31:0] error_count;

    reg        any_received;
    reg        empty_seen;
    reg        backpressure_seen;
    reg        error_seen;
    reg        test_complete;
    reg        test_pass;

    wire       output_handshake;
    wire       output_matches;

    assign output_handshake =
        m_axis_tvalid &&
        m_axis_tready;

    assign output_matches =
        (m_axis_tdata == expected_count) &&
        (m_axis_tkeep == 4'b1111) &&
        (m_axis_tlast == (expected_count[3:0] == 4'hF));

    always @(posedge read_clk or negedge read_reset_n) begin
        if (!read_reset_n) begin
            expected_count    <= 32'd0;
            received_count    <= 32'd0;
            error_count       <= 32'd0;
            any_received      <= 1'b0;
            empty_seen        <= 1'b0;
            backpressure_seen <= 1'b0;
            error_seen        <= 1'b0;
            test_complete     <= 1'b0;
            test_pass         <= 1'b0;
        end else begin
            
            if (m_axis_tvalid && !m_axis_tready) begin
                backpressure_seen <= 1'b1;
            end

            
            if (any_received && rempty) begin
                empty_seen <= 1'b1;
            end

            
            if (output_handshake) begin
                any_received   <= 1'b1;
                received_count <= received_count + 1'b1;

                if (!output_matches) begin
                    error_count <= error_count + 1'b1;
                    error_seen  <= 1'b1;
                end

                if (expected_count == TARGET_BEATS - 1) begin
                    test_complete <= 1'b1;

                    
                    if (!error_seen && output_matches) begin
                        test_pass <= 1'b1;
                    end else begin
                        test_pass <= 1'b0;
                    end
                end else begin
                    expected_count <= expected_count + 1'b1;
                end
            end
        end
    end

    //inst
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

    //sticky read domain status bits
    // updates from 0 to 1 only during testing
    reg test_complete_sync_1;
    reg test_complete_sync_2;

    reg test_pass_sync_1;
    reg test_pass_sync_2;

    reg error_seen_sync_1;
    reg error_seen_sync_2;

    reg empty_seen_sync_1;
    reg empty_seen_sync_2;

    reg backpressure_sync_1;
    reg backpressure_sync_2;

    always @(posedge write_clk or negedge write_reset_n) begin
        if (!write_reset_n) begin
            test_complete_sync_1 <= 1'b0;
            test_complete_sync_2 <= 1'b0;

            test_pass_sync_1 <= 1'b0;
            test_pass_sync_2 <= 1'b0;

            error_seen_sync_1 <= 1'b0;
            error_seen_sync_2 <= 1'b0;

            empty_seen_sync_1 <= 1'b0;
            empty_seen_sync_2 <= 1'b0;

            backpressure_sync_1 <= 1'b0;
            backpressure_sync_2 <= 1'b0;
        end else begin
            test_complete_sync_1 <= test_complete;
            test_complete_sync_2 <= test_complete_sync_1;

            test_pass_sync_1 <= test_pass;
            test_pass_sync_2 <= test_pass_sync_1;

            error_seen_sync_1 <= error_seen;
            error_seen_sync_2 <= error_seen_sync_1;

            empty_seen_sync_1 <= empty_seen;
            empty_seen_sync_2 <= empty_seen_sync_1;

            backpressure_sync_1 <= backpressure_seen;
            backpressure_sync_2 <= backpressure_sync_1;
        end
    end

    
    wire test_running;

    assign test_running =
        ~source_done ||
        ~test_complete_sync_2;

    
    assign led[0] = ~test_running;
    assign led[1] = ~full_seen;
    assign led[2] = ~empty_seen_sync_2;
    assign led[3] = ~backpressure_sync_2;
    assign led[4] = ~test_pass_sync_2;
    assign led[5] = ~error_seen_sync_2;

endmodule