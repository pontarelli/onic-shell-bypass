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
        doutb = ram[addr]; //Read first
        if (web | clear)
            ram[addr] = (clear)? 0 : ram[addr] + 1;
    end

    

endmodule

module qid_ram
(clka, clkb, we, addra, addrb, din, douta, doutb);

    input clka;
    input clkb;
    input we;
    input [10:0] addrb;
    output [127:0] doutb;
    
    input [14:0] addra;
    input [31:0] din;
    output reg [31:0] douta;
    reg [31:0] ram3 [0:(1<<11)-1];
    reg [31:0] ram2 [0:(1<<11)-1];
    reg [31:0] ram1 [0:(1<<11)-1];
    reg [31:0] ram0 [0:(1<<11)-1];
    reg [31:0] doutb3;
    reg [31:0] doutb2;
    reg [31:0] doutb1;
    reg [31:0] doutb0;
    reg [31:0] douta3;
    reg [31:0] douta2;
    reg [31:0] douta1;
    reg [31:0] douta0;
    wire we3,we2,we1,we0;
    
    //always @(posedge clkb)
    assign doutb = {doutb3,doutb2,doutb1,doutb0};
        
    always @(posedge clkb) 
         doutb3=ram3[addrb];
    always @(posedge clkb) 
         doutb2=ram2[addrb];
    always @(posedge clkb) 
         doutb1=ram1[addrb];
    always @(posedge clkb) 
         doutb0=ram0[addrb];
    
    assign we3 = (addra[3:2] == 2'b11)? we: 0;
    assign we2 = (addra[3:2] == 2'b10)? we: 0;
    assign we1 = (addra[3:2] == 2'b01)? we: 0;
    assign we0 = (addra[3:2] == 2'b00)? we: 0;
    
    always @* begin 
        case (addra[3:2])
        2'b11:
            douta = douta3;
        2'b10:
            douta = douta2;
        2'b01:
            douta = douta1;
        2'b00:
            douta = douta0;           
        endcase;
    end    
    
    always @(posedge clka)  begin
        if (we3)
           ram3[addra[14:4]] <= din;
        douta3 = ram3[addra[14:4]];
    end
    always @(posedge clka)  begin
        if (we2)
           ram2[addra[14:4]] <= din;
        douta2 = ram2[addra[14:4]];
    end
    always @(posedge clka)  begin
        if (we1)
           ram1[addra[14:4]] <= din;
        douta1 = ram1[addra[14:4]];
    end
    always @(posedge clka)  begin
        if (we0)
           ram0[addra[14:4]] <= din;
        douta0 = ram0[addra[14:4]];
    end
    
endmodule

