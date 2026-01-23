module distram
#(
    parameter ADDR_WIDTH = 20,
    parameter DATA_WIDTH = 32,
)
(clk, we, addra, addrb, din, douta, doutb);

    input clk;
    input we;
    input [ADDR_WIDTH-1:0] addra;
    input [ADDR_WIDTH-1:0] addrb;
    input [DATA_WIDTH-1:0] din;
    output [DATA_WIDTH-1:0] douta;
    output [DATA_WIDTH-1:0] doutb;
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk)  begin
        if (we)
            ram[addra] <= din;
    end

    assign douta = ram[addra];
    assign doutb = ram[addrb];

endmodule
