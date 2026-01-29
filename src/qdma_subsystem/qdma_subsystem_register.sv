// *************************************************************************
//
// Copyright 2020 Xilinx, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// *************************************************************************
// Address range: 0x0000 - 0x0FFF
// Address width: 12-bit
//
// Subsystem register description (0x4000 - 0x4FFF)
// -----------------------------------------------------------------------------
//  Address | Mode |          Description
// -----------------------------------------------------------------------------
//   0x4110 |  RW  |  REG_ADDR_LOWER
//   0x4114 |  RW  |  REG_ADDR_UPPER
//   0x4118 |  RW  |  REG_PORT_ID
//   0x411C |  RW  |  REG_QID
//   0x4120 |  RW  |  REG_FUNC
//   0x4124 |  RW  |  REG_PFCH_TAG
//   0x4128 |  RW  |  REG_BYPASS_ENABLE
//   0x412C |  RO  |  REG_PKT_COUNTER
//   0x4130 |  RO  |  REG_DST_ADDR_LOWER
//   0x4134 |  RO  |  REG_DST_ADDR_UPPER
//   0x4138 |  RO  |  REG_MULT_LOWER
//   0x413C |  RO  |  REG_MULT_UPPER
//   0x4140 |  RW  |  REG_NUM_DESC
//   0x4144 |  RO  |  REG_MODULE_ID
//   0x4148 |  RO  |  REG_DEBUG
// -----------------------------------------------------------------------------
//  Address | Mode |          Description
// 0x4400 - 0x44FE |  RW  | BRAM to hold per QID data - Each QID has 16 words (256B) of space:  
//     00 -     07 |  RW  | qdma_c2h_pkt_addr
//     08 -     0B |  RW  | reg_num_desc
//     0C -     0F |  RW  | {qdma_c2h_bypass_enable,qdma_c2h_pfch_tag}
//     10 -     13 |  RW  | qid_packet_counter
//     14 -     FF |   -  | RESERVED
// 0x4FF0          |  RW  | REG_RAM_INDIR_ADDR (QID)
// -----------------------------------------------------------------------------




`timescale 1ns/1ps
module qdma_subsystem_register (
  input         s_axil_awvalid,
  input  [31:0] s_axil_awaddr,
  output        s_axil_awready,
  input         s_axil_wvalid,
  input  [31:0] s_axil_wdata,
  output        s_axil_wready,
  output        s_axil_bvalid,
  output  [1:0] s_axil_bresp,
  input         s_axil_bready,
  input         s_axil_arvalid,
  input  [31:0] s_axil_araddr,
  output        s_axil_arready,
  output        s_axil_rvalid,
  output [31:0] s_axil_rdata,
  output  [1:0] s_axil_rresp,
  input         s_axil_rready,

  output reg [63:0] reg_pkt_addr,
  output reg [31:0] reg_num_desc,
  output reg  [2:0] reg_port_id,
  output reg [10:0] reg_qid,
  output reg [7:0] reg_func,
  output reg [6:0] reg_pfch_tag,
  output reg       reg_bypass_enable,
  output reg       reg_debug,


  input     [10:0] external_qid,
  output   [127:0] external_qid_data,
  
  input            external_packet_counter_ram_we,
  output    [31:0] external_packet_counter_data,
  
  
  input      [31:0] pkt_counter,
  input      [63:0] dst_addr,
  input      [63:0] mult_result,


  input         axil_aclk,
  input         axis_aclk,
  input         axil_aresetn
);

  localparam C_ADDR_W = 12;
  localparam MODULE_ID = 32'hA9DBEA;
  
  localparam REG_ADDR_LOWER     = 12'h110;
  localparam REG_ADDR_UPPER     = 12'h114;
  localparam REG_PORT_ID        = 12'h118;
  localparam REG_QID            = 12'h11C;
  localparam REG_FUNC           = 12'h120;
  localparam REG_PFCH_TAG       = 12'h124;
  localparam REG_BYPASS_ENABLE  = 12'h128;
  localparam REG_PKT_COUNTER    = 12'h12C;
  localparam REG_DST_ADDR_LOWER = 12'h130;
  localparam REG_DST_ADDR_UPPER = 12'h134;
  localparam REG_MULT_LOWER     = 12'h138;
  localparam REG_MULT_UPPER     = 12'h13C;
  localparam REG_NUM_DESC       = 12'h140;
  localparam REG_MODULE_ID      = 12'h144;
  localparam REG_DEBUG          = 12'h148;
  // From this point onwards, registers are reserved accessing bram
  localparam REG_RAM_BASE  = 12'h400;
  // Last register to access indirect address for dist ram
  localparam REG_RAM_INDIR_ADDR = 12'hFF0;


  reg [31:0] qid_page_index;

  wire [31:0] qid_ram_douta;
  wire [14:0] qid_ram_addr;
  wire [10:0] packet_counter_ram_addr;
  wire [31:0] packet_counter_ram_douta;

  wire address_in_qid_ram_range;
  wire address_in_packet_counter_ram_range;
  wire qid_ram_we;
  
  wire                reg_en;
  wire                reg_we;
  wire [C_ADDR_W-1:0] reg_addr;
  wire         [31:0] reg_din;
  reg          [31:0] reg_dout;
  wire         [31:0] register_dout;
  wire [31:0] packet_counter_ram_rdata;

  
  // Check if the input address is in the range of the "queue" ram or "packet counter" ram 
  assign address_in_qid_ram_range = (reg_addr[C_ADDR_W-1:0] >= 12'h400 && reg_addr[C_ADDR_W-1:0] < 12'h410);
  assign address_in_packet_counter_ram_range = (reg_addr[C_ADDR_W-1:0] >= 12'h410 && reg_addr[C_ADDR_W-1:0] < 12'h414);

  // Enable write if address in range && register write enable is set
  assign qid_ram_we = reg_we && address_in_qid_ram_range;
  assign packet_counter_ram_we = reg_we && address_in_packet_counter_ram_range;
  // For qid ram, address is qid + last 4 bits of reg addr (16 bytes)
  assign qid_ram_addr = {qid_page_index[10:0], reg_addr[3:0]};
  // For packet counter ram, we have just one entry per queue -> address is only qid
  assign packet_counter_ram_addr = qid_page_index[10:0]; 


  // If address is in one of the rams' ranges, assign register_dout to rams' value
  // else, use register file output
  assign register_dout = address_in_qid_ram_range ? qid_ram_douta :
                        address_in_packet_counter_ram_range ? packet_counter_ram_douta :  
                        reg_dout;
  // Port A R/W for AXI-Lite usage, Port B RO for external read
  qid_ram qid_ram_inst (
    .clka  (axil_aclk),
    .we   (qid_ram_we),
    .addra (qid_ram_addr),
    .din  (reg_din),
    .douta (qid_ram_douta),
    .clkb  (axis_aclk),
    .addrb (external_qid),
    .doutb (external_qid_data)
  );

  // Both port A and B R/W
  // Port A for AXI-Lite usage (counters reset)
  // Port B for external usage (counter increase)
  qid_packet_counter #(
    .ADDR_WIDTH (11),
    .DATA_WIDTH (32)
  ) qid_packet_counter_inst (
    .rstn  (axil_aresetn), 
    .clka  (axil_aclk),
    .wea   (packet_counter_ram_we),
    .addra (packet_counter_ram_addr),
    .din   (reg_din),
    .douta (packet_counter_ram_douta),
    .clkb  (axis_aclk),
    .web   (external_packet_counter_ram_we),
    .addrb (external_qid),
    .doutb (external_packet_counter_data)
  );
  
//  reg  [31:0] reg_addr_lower;
//  reg  [31:0] reg_addr_higher;
//  reg   [2:0] reg_port_id;
//  reg  [10:0] reg_qid;
//  reg   [7:0] reg_func;
//  reg   [6:0] reg_pfch_tag;



  axi_lite_register #(
    .CLOCKING_MODE ("common_clock"),
    .ADDR_W        (C_ADDR_W),
    .DATA_W        (32)
  ) axil_reg_inst (
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awaddr  (s_axil_awaddr),
    .s_axil_awready (s_axil_awready),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bready  (s_axil_bready),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_araddr  (s_axil_araddr),
    .s_axil_arready (s_axil_arready),
    .s_axil_rvalid  (s_axil_rvalid),
    .s_axil_rdata   (s_axil_rdata),
    .s_axil_rresp   (s_axil_rresp),
    .s_axil_rready  (s_axil_rready),

    .reg_en         (reg_en),
    .reg_we         (reg_we),
    .reg_addr       (reg_addr),
    .reg_din        (reg_din),
    .reg_dout       (register_dout),

    .axil_aclk      (axil_aclk),
    .axil_aresetn   (axil_aresetn),
    .reg_clk        (axil_aclk),
    .reg_rstn       (axil_aresetn)
  );



  always @(posedge axil_aclk) begin
    if (~axil_aresetn) begin
      reg_dout <= 0;
    end
    else if (reg_en && ~reg_we) begin
      case (reg_addr)
        REG_ADDR_LOWER: begin
            reg_dout <= reg_pkt_addr[31:0];
        end
        REG_ADDR_UPPER: begin
            reg_dout <= reg_pkt_addr[63:32];
        end
        REG_PORT_ID: begin
            reg_dout <= reg_port_id;
        end
        REG_QID: begin
            reg_dout <= reg_qid;
        end
        REG_FUNC: begin
            reg_dout <= reg_func;
        end
        REG_PFCH_TAG: begin
            reg_dout <= reg_pfch_tag;
        end
        REG_BYPASS_ENABLE: begin
            reg_dout <= reg_bypass_enable;
        end
        REG_PKT_COUNTER: begin
            reg_dout <= pkt_counter;
        end
        REG_MULT_LOWER: begin
            reg_dout <= mult_result[31:0];
        end
        REG_MULT_UPPER: begin
            reg_dout <= mult_result[63:32];
        end
        REG_NUM_DESC: begin
            reg_dout <= reg_num_desc;
        end
        REG_MODULE_ID: begin
            reg_dout <= MODULE_ID;
        end
        REG_DEBUG: begin
            reg_dout <= reg_debug;
        end
        REG_RAM_INDIR_ADDR: begin
            reg_dout <= qid_page_index;
        end
        default: begin
                reg_dout <= 32'hDEADBEEF;
            end
      endcase
    end
  end
  
  always @(posedge axil_aclk) begin
    if (~axil_aresetn) begin
        reg_pkt_addr <= 0;    
        reg_port_id <= 0;
        reg_qid <= 0;     
        reg_func <= 0;    
        reg_pfch_tag <= 0;
        reg_bypass_enable <= 0;
        reg_debug <= 0;
    end else begin
        if (reg_en && reg_we) begin
            case (reg_addr)
                REG_ADDR_LOWER: begin
                    reg_pkt_addr[31:0] <= reg_din;
                end
                REG_ADDR_UPPER: begin
                    reg_pkt_addr[63:32] <= reg_din;
                end
                REG_PORT_ID: begin
                    reg_port_id <= reg_din;
                end
                REG_QID: begin
                    reg_qid <= reg_din;
                end
                REG_FUNC: begin
                    reg_func <= reg_din;
                end
                REG_PFCH_TAG: begin
                    reg_pfch_tag <= reg_din;
                end
                REG_BYPASS_ENABLE: begin
                    reg_bypass_enable <= reg_din;
                end
                REG_NUM_DESC: begin
                    reg_num_desc <= reg_din;
                end
                REG_DEBUG: begin
                    reg_debug <= reg_din;
                end
                REG_RAM_INDIR_ADDR: begin
                    qid_page_index <= reg_din;
                end
                default: begin
                end
            endcase
        end
    end
  end

endmodule: qdma_subsystem_register

