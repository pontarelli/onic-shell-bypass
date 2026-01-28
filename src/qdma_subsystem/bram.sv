module qid_packet_counter #(
    parameter ADDR_WIDTH = 11,
    parameter DATA_WIDTH = 32
  ) 
(rstn,clka,clkb, wea,web,addra,addrb,din,douta,doutb);
    
    input [ADDR_WIDTH-1:0] addra;
    input clka;
    input wea;
    input [DATA_WIDTH-1:0] din;
    output reg [DATA_WIDTH-1:0] douta;
    
    input clkb;
    input rstn;
    input web;
    input [ADDR_WIDTH-1:0] addrb;
    output reg [DATA_WIDTH-1:0] doutb;
    wire [ADDR_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];
    reg clear;
    reg [ADDR_WIDTH-1:0] internal_counter;
    
    
    always @(posedge clka) begin
        douta = ram[addra];    
    end
    
    always @(posedge clka) begin
        if (~rstn)
            clear = 0;
        else 
            if (wea)
                clear = din[0];    
    end
    
    always @(posedge clkb) begin
        if (~rstn)
            internal_counter = 0;
        else
            internal_counter = internal_counter +1;                 
    end
    
    assign addr= (clear) ? internal_counter : addrb; 
    
    always @(posedge clkb) begin
        if (web | clear)
            ram[addr] = (clear)? 0 : ram[addr] + 1;
        doutb = ram[addrb];
    end

endmodule

module qid_ram
(clka, clkb, we, addra, addrb, din, douta, doutb);

    input clka;
    input clkb;
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

    
    always @(posedge clkb)
        doutb = {ram3[addrb], ram2[addrb], ram1[addrb], ram0[addrb]};
        
    always @(posedge clka)  begin
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
