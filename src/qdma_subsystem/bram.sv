module qid_packet_counter #(
    parameter ADDR_WIDTH = 11,
    parameter DATA_WIDTH = 32
  ) 
(clk, we,addr,dout);
    input clk;
    input we;
    input [ADDR_WIDTH-1:0] addr;
    output reg [DATA_WIDTH-1:0] dout;
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @(posedge clk) begin
        if (we)
            ram[addr] <= ram[addr] + 1;

        dout <= ram[addr];
    end

endmodule;

module qid_ram
(clk, we, addra, addrb, din, douta, doutb);

    input clk;
    input we;
    input [10:0] addrb;
    output reg [127:0] doutb;
    
    input [14:0] addra;
    input [31:0] din;
    output reg [31:0] douta;
    reg [31:0] ram3 [0:(1<<11)-1];
    reg [31:0] ram2 [0:(1<<11)-1];
    reg [31:0] ram1 [0:(1<<11)-1];
    reg [31:0] ram0 [0:(1<<11)-1];

    always @(posedge clk)  begin
        doutb = {ram3[addrb], ram2[addrb], ram1[addrb], ram0[addrb]};
        if (we) begin
            if (addra[3:2] == 2'b00)
                ram0[addra[14:4]] <= din;
            else if (addra[3:2] == 2'b01)
                ram1[addra[14:4]] <= din;
            else if (addra[3:2] == 2'b10)
                ram2[addra[14:4]] <= din;
            else 
                ram3[addra[14:4]] <= din;
        end
        if (addra[3:2] == 2'b00)
            douta <= ram0[addra[14:4]];
        else if (addra[3:2] == 2'b01)
            douta <= ram1[addra[14:4]];
        else if (addra[3:2] == 2'b10)
            douta <= ram2[addra[14:4]];
        else 
            douta <= ram3[addra[14:4]];
    end
endmodule
