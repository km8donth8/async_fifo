module uart_rx #(
    parameter CLK_FREQ  = 27000000
   ,parameter BAUD_RATE = 115200
)(
    input  wire       clk
   ,input  wire       rst_n
   ,input  wire       rx
   ,output reg  [7:0] data
   ,output reg        data_valid
   ,output reg        frame_error
);

    localparam CLKS_PER_BIT  = (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;
    localparam HALF_BIT_CLKS = CLKS_PER_BIT / 2;

    localparam STATE_IDLE  = 2'd0;
    localparam STATE_START = 2'd1;
    localparam STATE_DATA  = 2'd2;
    localparam STATE_STOP  = 2'd3;

    reg rx_sync_1;
    reg rx_sync_2;
    reg [15:0] clock_count;
    reg [2:0]  bit_index;
    reg [7:0]  data_reg;
    reg [1:0]  state;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;
        end else begin
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;
        end
    end

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data        <= 8'd0;
            data_valid  <= 1'b0;
            frame_error <= 1'b0;
            clock_count <= 16'd0;
            bit_index   <= 3'd0;
            data_reg    <= 8'd0;
            state       <= STATE_IDLE;
        end else begin
            data_valid  <= 1'b0;
            frame_error <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    clock_count <= 16'd0;
                    bit_index   <= 3'd0;
                    if (!rx_sync_2) begin
                        state <= STATE_START;
                    end
                end

                STATE_START: begin
                    if (clock_count == HALF_BIT_CLKS - 1) begin
                        clock_count <= 16'd0;
                        if (!rx_sync_2) begin
                            state <= STATE_DATA;
                        end else begin
                            state <= STATE_IDLE;
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STATE_DATA: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count         <= 16'd0;
                        data_reg[bit_index] <= rx_sync_2;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                STATE_STOP: begin
                    if (clock_count == CLKS_PER_BIT - 1) begin
                        clock_count <= 16'd0;
                        if (rx_sync_2) begin
                            data       <= data_reg;
                            data_valid <= 1'b1;
                        end else begin
                            frame_error <= 1'b1;
                        end
                        state <= STATE_IDLE;
                    end else begin
                        clock_count <= clock_count + 1'b1;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
