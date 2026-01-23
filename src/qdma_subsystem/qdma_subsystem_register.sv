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
//   0x4000 |  RO  | TX packets from QDMA
//   0x4004 |      |
// -----------------------------------------------------------------------------
//   0x4008 |  RO  | TX bytes from QDMA
//   0x400C |      |
// -----------------------------------------------------------------------------
//   0x4100 |  RO  | RX packets into QDMA
//   0x4104 |      |
// -----------------------------------------------------------------------------
//   0x4108 |  RO  | RX bytes into QDMA
//   0x410C |      |
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
  output reg       reg_bypass_valid,


  //input             packet_counter_dist_ram_we,
  //input     [31:0] packet_counter_dist_ram_addr,
  //output    [31:0] packet_counter_dist_ram_rdata,
  //input [31:0]  external_dist_ram_addr,
  //output [31:0] external_dist_ram_rdata,
  
  
  input      [31:0] pkt_counter,
  input      [63:0] dst_addr,
  input      [63:0] mult_result,


  input         axil_aclk,
  input         axis_aclk,
  input         axil_aresetn
);

  localparam C_ADDR_W = 12;
  localparam DIST_RAM_ADDR_W = 20;
  localparam MODULE_ID = 32'hA9DBEA;
  
  localparam REG_ADDR_LOWER     = 12'h110;
  localparam REG_ADDR_UPPER     = 12'h114;
  localparam REG_PORT_ID        = 12'h118;
  localparam REG_QID            = 12'h11C;
  localparam REG_FUNC           = 12'h120;
  localparam REG_PFCH_TAG       = 12'h124;
  localparam REG_BYPASS_VALID   = 12'h128;
  localparam REG_PKT_COUNTER    = 12'h12C;
  localparam REG_DST_ADDR_LOWER = 12'h130;
  localparam REG_DST_ADDR_UPPER = 12'h134;
  localparam REG_MULT_LOWER     = 12'h138;
  localparam REG_MULT_UPPER     = 12'h13C;
  localparam REG_NUM_DESC       = 12'h140;
  //localparam REG_MODULE_ID      = 12'h144;
  // From this point onwards, registers are reserved accessing dist_ram
  //localparam REG_DIST_RAM_BASE  = 12'h400;
  // Last register to access indirect address for dist ram
  //localparam REG_DIST_RAM_INDIR_ADDR = 12'hFFF;
  localparam REG_MODULE_ID      = 12'h400;


  reg [31:0] dist_ram_indir_addr;


  //wire [31:0] dist_ram_douta;
  //wire [DIST_RAM_ADDR_W-1:0] dist_ram_addr;
  //wire address_in_dist_ram_range;
  //wire dist_ram_we;
  //assign address_in_dist_ram_range = (s_axil_awaddr[C_ADDR_W-1:0] >= REG_DIST_RAM_BASE);
  //assign dist_ram_we = s_axil_wvalid && s_axil_wready && address_in_dist_ram_range && (s_axil_awaddr[C_ADDR_W-1:0] != REG_DIST_RAM_BASE);
  //assign dist_ram_addr = {dist_ram_indir_addr[(DIST_RAM_ADDR_W-C_ADDR_W)-1:0], s_axil_awaddr[C_ADDR_W-1:0]};

  //dist_ram #(
  //  .ADDR_WIDTH (DIST_RAM_ADDR_W),
  //  .DATA_WIDTH (32)
  //) base_addresses_memory (
  //  .clk  (axil_aclk),
  //  .we   (dist_ram_we),
  //  .addra (dist_ram_addr),
  //  .addrb (external_dist_ram_addr),
  //  .din  (s_axil_wdata),
  //  .douta (dist_ram_douta),
  //  .doutb (external_dist_ram_rdata),
  //);

  //wire [31:0] packet_counter_dist_ram_rdata;
  //dist_ram #(
  //  .ADDR_WIDTH (12),
  //  .DATA_WIDTH (32)
  //) packet_counter_memory (
  //  .clk  (axis_aclk),
  //  .we   (packet_counter_dist_ram_we),
  //  .addra (packet_counter_dist_ram_addr),
  //  .addrb (32'b0),
  //  .din  (packet_counter_dist_ram_rdata+32'd1),
  //  .douta (packet_counter_dist_ram_rdata),
  //  .doutb (),
  //);
  
//  reg  [31:0] reg_addr_lower;
//  reg  [31:0] reg_addr_higher;
//  reg   [2:0] reg_port_id;
//  reg  [10:0] reg_qid;
//  reg   [7:0] reg_func;
//  reg   [6:0] reg_pfch_tag;

  wire                reg_en;
  wire                reg_we;
  wire [C_ADDR_W-1:0] reg_addr;
  wire         [31:0] reg_din;
  reg          [31:0] reg_dout;

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
    .reg_dout       (reg_dout),

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
        REG_BYPASS_VALID: begin
            reg_dout <= reg_bypass_valid;
        end
        REG_PKT_COUNTER: begin
            reg_dout <= pkt_counter;
        end
        REG_ADDR_LOWER: begin
            reg_dout <= dst_addr[31:0];
        end
        REG_ADDR_UPPER: begin
            reg_dout <= dst_addr[63:32];
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
        //REG_DIST_RAM_INDIR_ADDR: begin
        //    reg_dout <= dist_ram_indir_addr;
        //end
        default: begin
            //if (address_in_dist_ram_range) begin
            //    // Read from dist ram
            //    reg_dout <= dist_ram_douta;
            //end else begin
                reg_dout <= 32'hDEADBEEF;
            //end
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
        reg_bypass_valid <= 0;
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
                REG_BYPASS_VALID: begin
                    reg_bypass_valid <= reg_din;
                end
                REG_NUM_DESC: begin
                    reg_num_desc <= reg_din;
                end
                //REG_DIST_RAM_INDIR_ADDR: begin
                //    dist_ram_indir_addr <= reg_din;
                //end
                default: begin
                end
            endcase
        end
    end
  end

endmodule: qdma_subsystem_register

