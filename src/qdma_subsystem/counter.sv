module counter #(
    parameter WIDTH = 32,
) (
    input logic clk,
    input logic rst_n,
    input logic enable,
    input logic [WIDTH-1:0] max_value,
    output logic [WIDTH-1:0] count
);

    logic [WIDTH-1:0] count_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= '0;
        end else if (enable) begin
            count <= count_next;
        end
    end

    always_comb begin
        if (count ==  max_value- 1) begin
            count_next = '0;
        end else begin
            count_next = count + 1;
        end
    end

endmodule