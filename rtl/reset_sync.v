module reset_sync (
    input  wire clk
   ,input  wire arst_n
   ,output wire srst_n
);

    reg reset_ff_1;
    reg reset_ff_2;

   // rst assert is async
   // rst release synced to destination clock
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            reset_ff_1 <= 1'b0;
            reset_ff_2 <= 1'b0;
        end else begin
            reset_ff_1 <= 1'b1;
            reset_ff_2 <= reset_ff_1;
        end
    end

    assign srst_n = reset_ff_2;

endmodule