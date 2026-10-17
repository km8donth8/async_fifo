module sync_ff #(
    parameter WIDTH = 4
)(
    input wire              clk
   ,input wire              rst_n
   ,input wire [WIDTH-1:0]  din
   ,output reg [WIDTH-1:0]  dout
);

    reg [WIDTH-1:0] sync_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_reg <= {WIDTH{1'b0}};
            dout     <= {WIDTH{1'b0}};
        end else begin
            sync_reg <= din;
            dout     <= sync_reg;
        end
    end
endmodule