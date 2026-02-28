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
`include "open_nic_shell_macros.vh"
`timescale 1ns/1ps
module qdma_subsystem_c2h #(
  parameter int NUM_PHYS_FUNC = 1
) (
  input     [NUM_PHYS_FUNC-1:0] s_axis_c2h_tvalid,
  input [512*NUM_PHYS_FUNC-1:0] s_axis_c2h_tdata,
  input     [NUM_PHYS_FUNC-1:0] s_axis_c2h_tlast,
  input  [16*NUM_PHYS_FUNC-1:0] s_axis_c2h_tuser_size,
  input  [11*NUM_PHYS_FUNC-1:0] s_axis_c2h_tuser_qid,
  output    [NUM_PHYS_FUNC-1:0] s_axis_c2h_tready,

  output                        m_axis_qdma_c2h_tvalid,
  output                [511:0] m_axis_qdma_c2h_tdata,
  output                 [31:0] m_axis_qdma_c2h_tcrc,
  output                        m_axis_qdma_c2h_tlast,
  output                        m_axis_qdma_c2h_ctrl_marker,
  output                  [2:0] m_axis_qdma_c2h_ctrl_port_id,
  output                  [6:0] m_axis_qdma_c2h_ctrl_ecc,
  output                 [15:0] m_axis_qdma_c2h_ctrl_len,
  output                 [10:0] m_axis_qdma_c2h_ctrl_qid,
  output                        m_axis_qdma_c2h_ctrl_has_cmpt,
  output reg              [5:0] m_axis_qdma_c2h_mty,
  input                         m_axis_qdma_c2h_tready,

  output                        m_axis_qdma_cpl_tvalid,
  output                [511:0] m_axis_qdma_cpl_tdata,
  output                  [1:0] m_axis_qdma_cpl_size,
  output                 [15:0] m_axis_qdma_cpl_dpar,
  output                 [10:0] m_axis_qdma_cpl_ctrl_qid,
  output                  [1:0] m_axis_qdma_cpl_ctrl_cmpt_type,
  output                 [15:0] m_axis_qdma_cpl_ctrl_wait_pld_pkt_id,
  output                  [2:0] m_axis_qdma_cpl_ctrl_port_id,
  output                        m_axis_qdma_cpl_ctrl_marker,
  output                        m_axis_qdma_cpl_ctrl_user_trig,
  output                  [2:0] m_axis_qdma_cpl_ctrl_col_idx,
  output                  [2:0] m_axis_qdma_cpl_ctrl_err_idx,
  output                        m_axis_qdma_cpl_ctrl_no_wrb_marker,
  input                         m_axis_qdma_cpl_tready,

  input                         debug,
  input                  [10:0] qmask,
  
  output                 [10:0] qid_index,
  output                 [10:0] qid_index_update,
  output                        packet_counter_ram_we,
  input                  [31:0] qid_packet_counter,
  input                 [127:0] qid_data,       
  
  output reg             [31:0] full_counter,
  output reg             [31:0] pkt_counter,

  

  output                         c2h_byp_in_st_csh_vld,
  output                  [63:0] c2h_byp_in_st_csh_addr,
  output                   [2:0] c2h_byp_in_st_csh_port_id,
  output                  [10:0] c2h_byp_in_st_csh_qid,
  output                         c2h_byp_in_st_csh_error,
  output                   [7:0] c2h_byp_in_st_csh_func,
  output                   [6:0] c2h_byp_in_st_csh_pfch_tag,
  input                          c2h_byp_in_st_csh_rdy,
  
  output                        c2h_status_valid,
  output                 [15:0] c2h_status_bytes,
  output reg              [1:0] c2h_status_func_id,

  input                         axis_aclk,
  input                         axil_aresetn
);

  reg  [NUM_PHYS_FUNC-1:0] processing;
  wire [NUM_PHYS_FUNC-1:0] arb_req;
  wire [NUM_PHYS_FUNC-1:0] arb_fin;
  wire [NUM_PHYS_FUNC-1:0] arb_grant;
  wire                     arb_ready;

  reg                      axis_c2h_tvalid;
  reg              [511:0] axis_c2h_tdata;
  reg                      axis_c2h_tlast;
  reg               [15:0] axis_c2h_tuser_size;
  reg               [10:0] axis_c2h_tuser_qid;
  wire                     axis_c2h_tready;

  wire                     crc32_en;
  wire             [511:0] crc32_data;
  wire              [31:0] crc32_out;

  wire              [56:0] c2h_ecc_data;
  wire               [6:0] c2h_ecc;

  reg               [15:0] pkt_pld_id;

  // 43b FIFO data: 11b qid + 16b pkt_id + 16b size
  wire                     cpl_fifo_wr_en;
  wire              [42:0] cpl_fifo_din;
  wire                     cpl_fifo_rd_en;
  wire              [42:0] cpl_fifo_dout;
  wire                     cpl_fifo_empty;
  wire                     cpl_fifo_full;

  //bypass path signals
  wire  byp_in_fifo_rd_en,byp_in_fifo_empty;
  reg   byp_in_fifo_wr_en;
  wire [92:0] byp_in_fifo_din;

  
  wire [63:0] mult_result;
  wire [31:0] reg_num_desc;
  wire [15:0] qid_pidx;
  wire [15:0] qid_cidx;
  wire full_queue;
  wire [511:0] debug_tdata;
  wire [10:0] axis_qdma_c2h_ctrl_qid;
  
  reg [63:0]  qdma_c2h_pkt_addr;
  reg  [2:0]  qdma_c2h_port_id;
  reg [10:0]  qdma_c2h_qid;
  wire  [7:0]  qdma_c2h_func;
  wire  [6:0]  qdma_c2h_pfch_tag; 
  reg [10:0] packet_counter_addr;
  
  reg [10:0] qid;
  reg [2:0]  pid;
  
  wire m_axis_qdma_c2h_sop;
  wire m_axis_qdma_c2h_tvalid_fifo_out;
  reg axis_c2h_sop;
  reg drop_prev;
  wire drop;

  generate for (genvar i = 0; i < NUM_PHYS_FUNC; i += 1) begin
    always @(posedge axis_aclk) begin
      if (~axil_aresetn) begin
        processing[i] <= 1'b0;
      end
      else if (~processing[i] && s_axis_c2h_tvalid[i]) begin
        processing[i] <= ~(s_axis_c2h_tlast[i] && s_axis_c2h_tready[i]);
      end
      else if (processing[i] && s_axis_c2h_tvalid[i] && s_axis_c2h_tlast[i] && s_axis_c2h_tready[i]) begin
        processing[i] <= 1'b0;
      end
    end

    assign arb_req[i]           = s_axis_c2h_tvalid[i] || processing[i];
    assign arb_fin[i]           = s_axis_c2h_tvalid[i] && s_axis_c2h_tlast[i] && s_axis_c2h_tready[i];
    assign s_axis_c2h_tready[i] = arb_grant[i];
  end
  endgenerate

  assign arb_ready = axis_c2h_tready && ~cpl_fifo_full;

  rr_arbiter #(
    .N (NUM_PHYS_FUNC)
  ) arb_inst (
    .req   (arb_req),
    .fin   (arb_fin),
    .grant (arb_grant),
    .ready (arb_ready),
    .clk   (axis_aclk),
    .rstn  (axil_aresetn)
  );

  always @(*) begin
    axis_c2h_tvalid     = 1'b0;
    axis_c2h_tdata      = 0;
    axis_c2h_tlast      = 1'b0;
    axis_c2h_tuser_size = 0;
    axis_c2h_tuser_qid  = 0;

    for (int i = 0; i < NUM_PHYS_FUNC; i += 1) begin
      if (arb_grant[i]) begin
        axis_c2h_tvalid     = s_axis_c2h_tvalid[i];
        axis_c2h_tdata      = s_axis_c2h_tdata[`getvec(512, i)];
        axis_c2h_tlast      = s_axis_c2h_tlast[i];
        axis_c2h_tuser_size = s_axis_c2h_tuser_size[`getvec(16, i)];
        axis_c2h_tuser_qid  = s_axis_c2h_tuser_qid[`getvec(11, i)];
        break;
      end
    end
  end

  axi_stream_register_slice #(
    .TDATA_W (512),
    .TUSER_W (1+16 + 11),
    .MODE    ("forward")
  ) slice_inst (
    .s_axis_tvalid (axis_c2h_tvalid),
    .s_axis_tdata  (axis_c2h_tdata),
    .s_axis_tkeep  ({64{1'b1}}),
    .s_axis_tlast  (axis_c2h_tlast),
    .s_axis_tid    (0),
    .s_axis_tdest  (0),
    .s_axis_tuser  ({axis_c2h_sop,axis_c2h_tuser_size, axis_c2h_tuser_qid}),
    .s_axis_tready (axis_c2h_tready),

    .m_axis_tvalid (m_axis_qdma_c2h_tvalid_fifo_out),
    .m_axis_tdata  (debug_tdata),
    .m_axis_tkeep  (),
    .m_axis_tlast  (m_axis_qdma_c2h_tlast),
    .m_axis_tid    (),
    .m_axis_tdest  (),
    .m_axis_tuser  ({m_axis_qdma_c2h_sop,m_axis_qdma_c2h_ctrl_len, axis_qdma_c2h_ctrl_qid}),
    .m_axis_tready (m_axis_qdma_c2h_tready),

    .aclk          (axis_aclk),
    .aresetn       (axil_aresetn)
  );
  assign m_axis_qdma_c2h_tvalid = m_axis_qdma_c2h_tvalid_fifo_out; //block
  //assign m_axis_qdma_c2h_tvalid = (!drop) & m_axis_qdma_c2h_tvalid_fifo_out; //drop 
  always @(posedge axis_aclk) begin
    if (~axil_aresetn) begin
      m_axis_qdma_c2h_mty <= 0;
    end
    else if (axis_c2h_tvalid && axis_c2h_tready) begin
          m_axis_qdma_c2h_mty <= (axis_c2h_tlast) ? (axis_c2h_tuser_size[5:0] == 0) ? 0 : (64 - axis_c2h_tuser_size[5:0]) : 0;
    end
  end

  always @(posedge axis_aclk) begin
    if (~axil_aresetn) begin
      axis_c2h_sop = 1;
      drop_prev =0;
    end
    else begin 
           if (axis_c2h_tvalid && axis_c2h_tready && !axis_c2h_tlast) begin
              axis_c2h_sop=0;
           end
           if (axis_c2h_tvalid && axis_c2h_tready && axis_c2h_tlast) begin
              axis_c2h_sop=1;
           end
           drop_prev = drop;
    end
  end          
  
  assign drop =(m_axis_qdma_c2h_sop)? full_queue : drop_prev;
  
  assign m_axis_qdma_c2h_tcrc          = crc32_out;
  assign m_axis_qdma_c2h_ctrl_marker   = 1'b0;
  assign m_axis_qdma_c2h_ctrl_port_id  = 0;
  assign m_axis_qdma_c2h_ctrl_has_cmpt = 1'b1;
  assign m_axis_qdma_c2h_ctrl_ecc      = c2h_ecc;

  assign crc32_en   = axis_c2h_tvalid && axis_c2h_tready;
  assign crc32_data = axis_c2h_tdata;

  crc32 crc32_inst (
    .crc_en  (crc32_en),
    .data_in (crc32_data),
    .crc_out (crc32_out),
    .clk     (axis_aclk),
    .rst     (~axil_aresetn)
  );

  assign c2h_ecc_data[56:33] = 24'h0; // reserved
  assign c2h_ecc_data[32]    = 1'b1;  // c2h_ctrl_has_cmpt
  assign c2h_ecc_data[31]    = 1'b0;  // c2h_ctrl_marker
  assign c2h_ecc_data[30:28] = 3'h0;  // c2h_ctrl_port_id
  assign c2h_ecc_data[27]    = 1'b0;  // reserved
  assign c2h_ecc_data[26:16] = axis_c2h_tuser_qid;
  assign c2h_ecc_data[15:0]  = axis_c2h_tuser_size;

  qdma_subsystem_c2h_ecc ecc_inst (
    .ecc_data_in     (c2h_ecc_data),
    .ecc_data_out    (),
    .ecc_chkbits_out (c2h_ecc),

    .ecc_clk         (axis_aclk),
    .ecc_clken       (1'b1),
    .ecc_reset       (~axil_aresetn)
  );

  // Note that packet ID is only incremented when the packet has actually been
  // received by QDMA.  Thus it samples the "m_axis_*" signals.
  always @(posedge axis_aclk) begin
    if (~axil_aresetn) begin
      pkt_pld_id <= 0;
    end
    else if (m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tready) begin
      pkt_pld_id <= pkt_pld_id + 1;
    end
  end

  // This FIFO stores completion information, including packet length, packet ID
  // and queue ID.  When the FIFO becomes nearly full, the arbitration is paused.
  xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_READ_LATENCY   (1),
    .FIFO_WRITE_DEPTH    (512),
    .READ_DATA_WIDTH     (43), // {qid, pkt_id, size}
    .READ_MODE           ("fwft"),
    .WRITE_DATA_WIDTH    (43),
    .PROG_FULL_THRESH    (512-5) // Note that there is a one cycle delay along the datapath due to the 
		                 // AXI register slice instantiated above.  The prog_full here is 
		                 // used instead to provide necessary early reaction time in case this
		                 // fifo nears full.  DEPTH-5 is specied for the prog_full threshold 
		                 // based on the values that are allowed when using FWFT mode of xpm_fifo_sync.
  ) cpl_fifo_inst (
    .wr_en         (cpl_fifo_wr_en),
    .din           (cpl_fifo_din),
    .wr_ack        (),
    .rd_en         (cpl_fifo_rd_en),
    .data_valid    (),
    .dout          (cpl_fifo_dout),

    .wr_data_count (),
    .rd_data_count (),

    .empty         (cpl_fifo_empty),
    .full          (), // Moved to prog_full (see note above)
    .almost_empty  (),
    .almost_full   (),
    .overflow      (),
    .underflow     (),
    .prog_empty    (),
    .prog_full     (cpl_fifo_full),
    .sleep         (1'b0),

    .sbiterr       (),
    .dbiterr       (),
    .injectsbiterr (1'b0),
    .injectdbiterr (1'b0),

    .wr_clk        (axis_aclk),
    .rst           (~axil_aresetn),
    .rd_rst_busy   (),
    .wr_rst_busy   ()
  );

  assign cpl_fifo_wr_en = m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tready;
  assign cpl_fifo_din   = {axis_qdma_c2h_ctrl_qid, 16'(pkt_pld_id + 1), m_axis_qdma_c2h_ctrl_len};
  assign cpl_fifo_rd_en = m_axis_qdma_cpl_tvalid && m_axis_qdma_cpl_tready && !full_queue; // block
  //assign cpl_fifo_rd_en = m_axis_qdma_cpl_tvalid && m_axis_qdma_cpl_tready;  //drop 

  assign m_axis_qdma_cpl_tvalid               = ~cpl_fifo_empty;
  assign m_axis_qdma_cpl_tdata[511:256]       = 0;
  assign m_axis_qdma_cpl_tdata[255:128]       = 0;
  assign m_axis_qdma_cpl_tdata[127:64]        = 0;
  assign m_axis_qdma_cpl_tdata[63:32]         = cpl_fifo_dout[31:0];
  assign m_axis_qdma_cpl_tdata[31:27]         = 0;
  assign m_axis_qdma_cpl_tdata[26:16]         = cpl_fifo_dout[42:32];
  assign m_axis_qdma_cpl_tdata[15:0]          = 0;

  assign m_axis_qdma_cpl_ctrl_no_wrb_marker   = 1'b0;
  assign m_axis_qdma_cpl_ctrl_col_idx         = 0;
  assign m_axis_qdma_cpl_ctrl_err_idx         = 0;
  assign m_axis_qdma_cpl_ctrl_qid             = cpl_fifo_dout[42:32];
  assign m_axis_qdma_cpl_ctrl_marker          = 1'b0;
  assign m_axis_qdma_cpl_ctrl_cmpt_type       = 2'b11;  //regular mode
  assign m_axis_qdma_cpl_ctrl_user_trig       = 1'b0;
  assign m_axis_qdma_cpl_ctrl_port_id         = 0;
  assign m_axis_qdma_cpl_size                 = 2'b00; // 8B completion packet
  assign m_axis_qdma_cpl_ctrl_wait_pld_pkt_id = cpl_fifo_dout[31:16];
  generate for (genvar i = 0; i < 16; i = i + 1) begin
    assign m_axis_qdma_cpl_dpar[i] = ~(^m_axis_qdma_cpl_tdata[(i*32) +: 32]);
  end
  endgenerate

  // C2H status update
  assign c2h_status_valid = axis_c2h_tvalid && axis_c2h_tlast && axis_c2h_tready;
  assign c2h_status_bytes = axis_c2h_tuser_size;
  always @(*) begin
    c2h_status_func_id = 2'd0;
    for (int i = 0; i < NUM_PHYS_FUNC; i += 1) begin
      if (arb_grant[i]) begin
        c2h_status_func_id = i;
        break;
      end
    end
  end

//add logic for c2h bypass path

assign {qid_cidx, qdma_c2h_bypass_enable,qdma_c2h_pfch_tag,reg_num_desc,qdma_c2h_pkt_addr}=qid_data[119:0];
assign c2h_byp_in_st_csh_vld = ~byp_in_fifo_empty;
assign byp_in_fifo_rd_en = c2h_byp_in_st_csh_rdy && c2h_byp_in_st_csh_vld;
assign c2h_byp_in_st_csh_error = 1'b0;


always@(posedge axis_aclk) begin
  if (~axil_aresetn) begin
    pkt_counter <= 32'd1;
    full_counter <= 0;
  end
  else begin
    pkt_counter = pkt_counter +(m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tready);
    if (full_queue)
      full_counter <= full_counter + (m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tvalid_fifo_out && m_axis_qdma_c2h_tready);  
  end
end

////25B (pad) + 4B + 4B +3B +2B + 4B +8B +14 ETH      
assign m_axis_qdma_c2h_tdata = (debug)? {debug_tdata[511:312], pkt_counter,qid_packet_counter,3'b0,packet_counter_ram_we,3'b0,qdma_c2h_bypass_enable,8'b0,1'b0,qdma_c2h_pfch_tag,5'b0, axis_qdma_c2h_ctrl_qid,reg_num_desc, qdma_c2h_pkt_addr + mult_result,debug_tdata[111:0]} : debug_tdata;
assign mult_result = 32'h0940*qid_pidx ; //2368*( packet_counter % reg_num_desc)
  

 xpm_fifo_sync #(
    .DOUT_RESET_VALUE    ("0"),
    .ECC_MODE            ("no_ecc"),
    .FIFO_MEMORY_TYPE    ("auto"),
    .FIFO_WRITE_DEPTH    (32),
    .READ_DATA_WIDTH     (93),
    .READ_MODE           ("fwft"),
    .WRITE_DATA_WIDTH    (93)
  ) byp_in_fifo_inst (
    .wr_en         (byp_in_fifo_wr_en),
    .din           (byp_in_fifo_din),
    .wr_ack        (),
    .rd_en         (byp_in_fifo_rd_en),
    .data_valid    (),
    .dout          ({c2h_byp_in_st_csh_addr, c2h_byp_in_st_csh_port_id, c2h_byp_in_st_csh_qid, c2h_byp_in_st_csh_func, c2h_byp_in_st_csh_pfch_tag}),

    .wr_data_count (),
    .rd_data_count (),

    .empty         (byp_in_fifo_empty),
    //.full          (byp_in_fifo_full),
    .full          (),
    .almost_empty  (),
    .almost_full   (),
    .overflow      (),
    .underflow     (),
    .prog_empty    (),
    .prog_full     (),
    .sleep         (1'b0),

    .sbiterr       (),
    .dbiterr       (),
    .injectsbiterr (1'b0),
    .injectdbiterr (1'b0),

    .wr_clk        (axis_aclk),
    .rst           (~axil_aresetn),
    .rd_rst_busy   (),
    .wr_rst_busy   ()
  );

  
  assign qdma_c2h_func=8'b0;
  
  assign packet_counter_ram_we = qdma_c2h_bypass_enable && m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tready;
  always@(posedge axis_aclk) begin
    if (~axil_aresetn) begin
      byp_in_fifo_wr_en = 1'b0;
      qid = 11'b0;
      pid = 3'b0;
    end
    else begin
      qid = m_axis_qdma_c2h_ctrl_qid; 
      pid = m_axis_qdma_c2h_ctrl_port_id;
      byp_in_fifo_wr_en = packet_counter_ram_we;
    end
  end
  assign m_axis_qdma_c2h_ctrl_qid = axis_qdma_c2h_ctrl_qid & qmask;
  assign qid_index = axis_qdma_c2h_ctrl_qid; //axis_c2h_tuser_qid (1cc before)
  assign qid_index_update = axis_qdma_c2h_ctrl_qid;
  
  assign byp_in_fifo_din = {qdma_c2h_pkt_addr + mult_result, pid, qid, qdma_c2h_func, qdma_c2h_pfch_tag};
  assign qid_pidx=qid_packet_counter[15:0] & (reg_num_desc-1);
  assign full_queue= (qid_cidx==qid_pidx+1) || (qid_cidx==0 && qid_pidx==reg_num_desc-1); // full when next write will make cidx catch up with pidx
  
  

endmodule: qdma_subsystem_c2h


/*
assign qid_index = axis_c2h_tuser_qid;  //1
// axis_qdma_c2h_ctrl_qid //2
assign {qid_cidx, qdma_c2h_bypass_enable,qdma_c2h_pfch_tag,reg_num_desc,qdma_c2h_pkt_addr}=qid_data[119:0]; //2
assign qid_pidx=qid_packet_counter[15:0]; //2

assign m_axis_qdma_c2h_tvalid = m_axis_qdma_c2h_tvalid_fifo_out; //2 
assign full= (qid_cidx==qid_pidx+1) || (qid_cidx==0 && qid_pidx==reg_num_desc-1); //2
assign drop =(m_axis_qdma_c2h_sop)? full_queue : drop_prev; //2
assign packet_counter_ram_we = qdma_c2h_bypass_enable && m_axis_qdma_c2h_tlast && m_axis_qdma_c2h_tvalid && m_axis_qdma_c2h_tready; // >=2
assign byp_in_fifo_wr_en =packet_counter_ram_we; //2
assign byp_in_fifo_din = {qdma_c2h_pkt_addr + mult_result, m_axis_qdma_c2h_ctrl_port_id, axis_qdma_c2h_ctrl_qid, qdma_c2h_func, qdma_c2h_pfch_tag}; //2
*/
