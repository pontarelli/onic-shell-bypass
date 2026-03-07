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
//   0x5110 |  RW  |  UNUSED
//   0x5114 |  RW  |  UNUSED
//   0x5118 |  RW  |  UNUSED
//   0x511C |  RW  |  UNUSED
//   0x5120 |  RW  |  UNUSED
//   0x5124 |  RW  |  UNUSED
//   0x5128 |  RW  |  UNUSED
//   0x512C |  RO  |  REG_PKT_COUNTER
//   0x5130 |  RO  |  UNUSED
//   0x5134 |  RO  |  UNUSED
//   0x5138 |  RO  |  UNUSED
//   0x513C |  RO  |  UNUSED
//   0x5140 |  RW  |  UNUSED
//   0x5144 |  RO  |  REG_MODULE_ID
//   0x5148 |  RW  |  REG_DEBUG
//   0x514C |  RO  |  REG_FULL_COUNTER
//   0x5150 |  RW  |  REG_QMASK
//   0x5154 |  RW  |  REG_FENCE
// -----------------------------------------------------------------------------
//  Address | Mode |          Description
// 0x5400 - 0x54FE |  RW  | BRAM to hold per QID data - Each QID has 16 words (256B) of space:  
//     00 -     07 |  RW  | qdma_c2h_pkt_addr
//     08 -     0B |  RW  | reg_num_desc
//     0C -     0F |  RW  | {qid_cidx,qdma_c2h_bypass_enable,qdma_c2h_pfch_tag}
//     10 -     13 |  RW  | qid_packet_counter
//     14 -     FF |   -  | RESERVED
// 0x5FF0          |  RW  | REG_RAM_INDIR_ADDR (QID)
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

  input     [10:0] external_qid_index,
  input     [10:0] external_qid_index_update,
  output   [127:0] external_qid_data,
  
  input            external_packet_counter_ram_we,
  input            external_packet_counter_ram_we256,
  input            external_packet_counter_ram_we512,
  output    [31:0] external_qid_packet_counter,
  
  output reg [31:0] reg_debug,
  output reg        reg_fence,
  output reg [10:0] reg_qmask,

  
  input      [31:0] pkt_counter,
  input      [31:0] full_counter,
  

  input         axil_aclk,
  input         axis_aclk,
  input         axil_aresetn
);

  localparam C_ADDR_W = 12;
  localparam MODULE_ID = 32'hA9DBEA;
  
  localparam REG_PKT_COUNTER    = 12'h12C;
  localparam REG_MODULE_ID      = 12'h144;
  localparam REG_DEBUG          = 12'h148;
  localparam REG_FULL_COUNTER   = 12'h14C;
  localparam REG_QMASK          = 12'h150;
  localparam REG_FENCE          = 12'h154;
  // From this point onwards, registers are reserved accessing bram
  localparam REG_RAM_BASE  = 12'h400;
  // Last register to access indirect address for dist ram
  localparam REG_RAM_INDIR_ADDR = 12'hFF0;


  reg [31:0] qid_page_index;
  reg        reg_fence_axil;
  reg        reg_fence_axis_ff1;
  reg [31:0] reg_debug_axil;
  reg [31:0] reg_debug_axis_ff1;
  reg [10:0] reg_qmask_axil;
  reg [10:0] reg_qmask_axil_ff1;

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
    .addrb (external_qid_index),
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
    .web256(external_packet_counter_ram_we256),
    .web512(external_packet_counter_ram_we512),
    .waddr (external_qid_index_update),
    .addrb (external_qid_index),
    .doutb (external_qid_packet_counter)
  );
  

  axi_lite_register #(
    .CLOCKING_MODE ("common_clock"),
    .ADDR_W        (C_ADDR_W),
    .DATA_W        (32)
  ) axil_reg_inst (
    .s_axil_awvalid (s_axil_awvalid),
    .s_axil_awaddr  (s_axil_awaddr[11:0]),
    .s_axil_awready (s_axil_awready),
    .s_axil_wvalid  (s_axil_wvalid),
    .s_axil_wdata   (s_axil_wdata),
    .s_axil_wready  (s_axil_wready),
    .s_axil_bvalid  (s_axil_bvalid),
    .s_axil_bresp   (s_axil_bresp),
    .s_axil_bready  (s_axil_bready),
    .s_axil_arvalid (s_axil_arvalid),
    .s_axil_araddr  (s_axil_araddr[11:0]),
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
        REG_PKT_COUNTER: begin
            reg_dout <= pkt_counter;
        end
        REG_MODULE_ID: begin
            reg_dout <= MODULE_ID;
        end
        REG_DEBUG: begin
            reg_dout <= reg_debug_axil;
        end
        REG_RAM_INDIR_ADDR: begin
            reg_dout <= qid_page_index;
        end
        REG_FULL_COUNTER: begin
            reg_dout <= full_counter;
        end
        REG_QMASK: begin
            reg_dout <= reg_qmask_axil;
        end
        REG_FENCE: begin
          reg_dout <= reg_fence_axil;
        end
        default: begin
                reg_dout <= 32'hDEADBEEF;
            end
      endcase
    end
  end
  
  always @(posedge axil_aclk) begin
    if (~axil_aresetn) begin
        reg_debug_axil <= 0;
        reg_qmask_axil <= 11'h7ff;
        reg_fence_axil <= 0;
    end else begin
        if (reg_en && reg_we) begin
            case (reg_addr)
                REG_DEBUG: begin
                    reg_debug_axil <= reg_din;
                end
                REG_RAM_INDIR_ADDR: begin
                    qid_page_index <= reg_din;
                end
                REG_QMASK: begin
                    reg_qmask_axil <= reg_din;
                end
                REG_FENCE: begin
                    reg_fence_axil <= reg_din;
                end
                default: begin
                end
            endcase
        end
    end
  end

  // Synchronize fence control from AXI-Lite clock domain into AXIS clock domain.
  always @(posedge axis_aclk) begin
    if (~axil_aresetn) begin
      reg_fence_axis_ff1 <= 0;
      reg_fence <= 0;
      reg_debug_axis_ff1 <= 0;
      reg_debug <= 0;
      reg_qmask_axil_ff1 <= 11'h7ff;
      reg_qmask <= 11'h7ff;
    end else begin
      reg_fence_axis_ff1 <= reg_fence_axil;
      reg_fence <= reg_fence_axis_ff1;
      
      reg_debug_axis_ff1 <= reg_debug_axil;
      reg_debug <= reg_debug_axis_ff1;
      
      reg_qmask_axil_ff1 <= reg_qmask_axil;
      reg_qmask <= reg_qmask_axil_ff1;
      

    end
  end

endmodule: qdma_subsystem_register

