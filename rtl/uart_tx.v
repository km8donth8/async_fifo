module uart_tx #(
    parameter CLK_FREQ  = 13500000
   ,parameter BAUD_RATE = 115200
)(
    input  wire       clk
   ,input  wire       rst_n
   ,input  wire [7:0] data
   ,input  wire       data_valid
   ,output wire       data_ready
   ,output reg        tx
   ,output reg        busy
);

    localparam CLKS_PER_BIT = (CLK_FREQ + (BAUD_RATE / 2)) / BAUD_RATE;

    reg [15:0] clock_count;
    reg [3:0]  bit_index;
    reg [7:0]  data_reg;

    assign data_ready = ~busy;

    // data valid sampled when data ready high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx          <= 1'b1;
            busy        <= 1'b0;
            clock_count <= 16'd0;
            bit_index   <= 4'd0;
            data_reg    <= 8'd0;
        end else begin
            if (!busy) begin
                tx          <= 1'b1;
                clock_count <= 16'd0;
                bit_index   <= 4'd0;

                if (data_valid) begin
                    data_reg <= data;
                    busy     <= 1'b1;
                    tx       <= 1'b0;
                end
            end else begin
                if (clock_count == CLKS_PER_BIT - 1) begin
                    clock_count <= 16'd0;

                    if (bit_index == 4'd0) begin
                        tx        <= data_reg[0];
                        bit_index <= 4'd1;
                    end else if (bit_index < 4'd8) begin
                        tx        <= data_reg[bit_index];
                        bit_index <= bit_index + 1'b1;
                    end else if (bit_index == 4'd8) begin
                        tx        <= 1'b1;
                        bit_index <= 4'd9;
                    end else begin
                        tx        <= 1'b1;
                        busy      <= 1'b0;
                        bit_index <= 4'd0;
                    end
                end else begin
                    clock_count <= clock_count + 1'b1;
                end
            end
        end
    end

endmodule
