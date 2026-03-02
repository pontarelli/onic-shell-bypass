module top_sim;

bit clk             ; 
bit rst             ; 
bit pause           ; 
bit rst_fill        ;
bit rstn            ;

logic [511:0]   S0_AXIS_TDATA       ;
logic [47:0]    S0_AXIS_TUSER       ;
logic           S0_AXIS_TVALID  = 0 ;
logic           S0_AXIS_TREADY      ;
logic [63:0]    S0_AXIS_TKEEP       ;
logic           S0_AXIS_TLAST       ; 


logic  [511:0]   M0_AXIS_TDATA         ;
logic  [47:0]    M0_AXIS_TUSER         ;
logic            M0_AXIS_TVALID        ;
logic            M0_AXIS_TREADY        ;
logic  [63:0]    M0_AXIS_TKEEP         ;
logic            M0_AXIS_TLAST         ;

logic [31:0]    S_AXI_AWADDR   = 0   ;
logic           S_AXI_AWVALID  = 0   ;
logic [31:0]    S_AXI_WDATA    = 0   ;
logic [3:0]     S_AXI_WSTRB    = 0   ;
logic           S_AXI_WVALID   = 0   ;
logic           S_AXI_BREADY   = 1   ;
logic [31:0]    S_AXI_ARADDR   = 0   ;
logic           S_AXI_ARVALID  = 0   ;
logic           S_AXI_RREADY      ;
logic           S_AXI_ARREADY     ;
logic [31:0]    S_AXI_RDATA       ;
logic [1:0]     S_AXI_RRESP       ;
logic           S_AXI_RVALID      ;
logic           S_AXI_WREADY      ;
logic [1:0]     S_AXI_BRESP       ;
logic           S_AXI_BVALID      ;
logic           S_AXI_AWREADY     ;


logic [15:0]    tx_pktcount_1 ;
logic           pcapfinished_1 ;

//logic           eos_1 ;
logic [15:0]     rx_pktcount_1 ;


logic                         m_axis_qdma_cpl_tvalid;
logic                 [511:0] m_axis_qdma_cpl_tdata;
logic                   [1:0] m_axis_qdma_cpl_size;
logic                  [15:0] m_axis_qdma_cpl_dpar;
logic                  [10:0] m_axis_qdma_cpl_ctrl_qid;
logic                 [15:0] m_axis_qdma_cpl_ctrl_wait_pld_pkt_id;
  






parameter CLK_PERIOD = 4.0;

//xil_axi_resp_t  resp;
bit[31:0]  addr, data;

initial begin
    pause= 1'b1;
    rst = 1'b1;
    rstn = 1'b0;
    #(100 * CLK_PERIOD);
    rst = 1'b0;
    rstn = 1'b1;
    $display("Reset Deasserted");
    #(10 * CLK_PERIOD);
   end


//Clock generation
   initial begin
      clk = 1'b0;
      #(CLK_PERIOD/2);
      forever begin
         #(CLK_PERIOD/2) clk = ~clk;
      end   
   end

    task axi_write;
        input [31:0] awaddr;
        input [31:0] wdata; 
        begin
            // *** Write address ***
            S_AXI_AWADDR = awaddr;
            S_AXI_AWVALID = 1;
            S_AXI_WDATA = wdata;
            S_AXI_WSTRB = 4'hf;
            S_AXI_WVALID = 1; 
            wait(S_AXI_AWREADY);
            wait(S_AXI_WREADY);
            @ (posedge clk);
            S_AXI_AWVALID = 0;
            S_AXI_WVALID = 0;
            // TBD: should wait bresp             
        end
    endtask
    
    task axi_read;
        input [31:0] araddr;
        output [31:0] rdata;
        begin
            // *** Read address ***
            S_AXI_ARADDR = araddr;
            S_AXI_ARVALID = 1;
            S_AXI_RREADY = 1;
            @ (posedge clk);
            wait(S_AXI_ARREADY);
            wait(S_AXI_RVALID);
            rdata=S_AXI_RDATA;
            S_AXI_ARVALID = 0;
            S_AXI_RREADY = 0;        
        end
    endtask

initial begin
    // Read from AXI4-lite  
    #900ns
    addr =32'h10;
    axi_read(addr,data);
    $display("data is %d",data);

    // Read from AXI4-lite  
    /*
    #400ns
    addr =32'h10;
    axi_read(addr,data);
    $display("data is %d",data);
    */
    // Write from AXI4-lite 
    //Clear counters
    addr =32'h410;
    axi_write(addr,1);
    #10us
    axi_write(addr,0);
    #400ns
            
    addr =32'hFF0;
    axi_write(addr,0);
    #400ns
    
    addr =32'h400;
    axi_write(addr,0);
    #400ns
    
    addr =32'h404;
    axi_write(addr,0);
    #400ns
    
    addr =32'h408; 
    axi_write(addr,1024); //num_desc
    #400ns
    
    addr =32'h40C;
    axi_write(addr,128); //valid + tag=0
    #400ns
    pause= 1'b0;
    
    
    #100us
    axi_write(addr,1008*256+128); //cidx=1021 + valid + tag=0 
    
    //$display("data is %d",data);
        
end 

  wire             fence;
  wire             debug;
  wire      [10:0] qid;
  wire      [10:0] qmask;
  wire      [10:0] qid_index;
  wire      [10:0] qid_index_update;
  wire             packet_counter_ram_we;
  wire      [31:0] qid_packet_counter;
  wire     [127:0] qid_data;
  wire      [31:0] full_counter;
  wire      [31:0] pkt_counter;
  wire                         c2h_status_valid;
  wire                  [15:0] c2h_status_bytes;
  wire                   [1:0] c2h_status_func_id;
   
pcap_parse
#(
    .pcap_filename  ("/home/guest/test.pcap"),
    .play_in_loop(1),
    .default_ifg(0),
    .n_loops(1000)
    
)
parse_i
(
    .pause          (pause        	                                                               ),
    .data           (S0_AXIS_TDATA                                                                 ),
    .strb           (S0_AXIS_TKEEP                                                                 ),
    .ready          (S0_AXIS_TREADY                                                                ),
    .valid          (S0_AXIS_TVALID                                                                ),
    .len            (S0_AXIS_TUSER                                                                 ),
    .qid            (qid                                                                           ),
    .eop            (S0_AXIS_TLAST                                                                 ),
    .clk            (clk         	                                                               ),
    .pktcount       (tx_pktcount_1                                                                 ),
    .pcapfinished   (pcapfinished_1	                                                               ) 

);

  

 qdma_subsystem_register reg_inst (
      .s_axil_awvalid (S_AXI_AWVALID),
      .s_axil_awaddr  (S_AXI_AWADDR),
      .s_axil_awready (S_AXI_AWREADY),
      .s_axil_wvalid  (S_AXI_WVALID),
      .s_axil_wdata   (S_AXI_WDATA),
      .s_axil_wready  (S_AXI_WREADY),
      .s_axil_bvalid  (S_AXI_BVALID),
      .s_axil_bresp   (S_AXI_BRESP),
      .s_axil_bready  (S_AXI_BREADY),
      .s_axil_arvalid (S_AXI_ARVALID),
      .s_axil_araddr  (S_AXI_ARADDR),
      .s_axil_arready (S_AXI_ARREADY),
      .s_axil_rvalid  (S_AXI_RVALID),
      .s_axil_rdata   (S_AXI_RDATA),
      .s_axil_rresp   (S_AXI_RRESP),
      .s_axil_rready  (S_AXI_RREADY),
      
      .reg_fence(fence),
      
      //C2H bypasss control signals
      .reg_debug(debug),
      .reg_qmask(qmask),
      .external_qid_index(qid_index),
      .external_qid_index_update(qid_index_update),
      .external_packet_counter_ram_we(packet_counter_ram_we),
      .external_qid_packet_counter(qid_packet_counter),
      .external_qid_data(qid_data),
      .pkt_counter(pkt_counter),
      .full_counter(full_counter),

      .axil_aclk      (clk),
      .axis_aclk      (clk),
      .axil_aresetn   (rstn)
    );



    qdma_subsystem_c2h #(
      .NUM_PHYS_FUNC (1)
    ) c2h_inst (
      .s_axis_c2h_tvalid                    (S0_AXIS_TVALID),
      .s_axis_c2h_tdata                     (S0_AXIS_TDATA),
      .s_axis_c2h_tlast                     (S0_AXIS_TLAST),
      .s_axis_c2h_tuser_size                (S0_AXIS_TUSER[15:0]),
      .s_axis_c2h_tuser_qid                 (qid),
      .s_axis_c2h_tready                    (S0_AXIS_TREADY),

      .m_axis_qdma_c2h_tvalid               (M0_AXIS_TVALID),
      .m_axis_qdma_c2h_tdata                (M0_AXIS_TDATA),
      .m_axis_qdma_c2h_tcrc                 (axis_qdma_c2h_tcrc),
      .m_axis_qdma_c2h_tlast                (M0_AXIS_TLAST),
      .m_axis_qdma_c2h_ctrl_marker          (axis_qdma_c2h_ctrl_marker),
      .m_axis_qdma_c2h_ctrl_port_id         (axis_qdma_c2h_ctrl_port_id),
      .m_axis_qdma_c2h_ctrl_ecc             (axis_qdma_c2h_ctrl_ecc),
      .m_axis_qdma_c2h_ctrl_len             (axis_qdma_c2h_ctrl_len),
      .m_axis_qdma_c2h_ctrl_qid             (axis_qdma_c2h_ctrl_qid),
      .m_axis_qdma_c2h_ctrl_has_cmpt        (axis_qdma_c2h_ctrl_has_cmpt),
      .m_axis_qdma_c2h_mty                  (M0_AXIS_TKEEP[5:0]),
      .m_axis_qdma_c2h_tready               (cpl_tready), //(M0_AXIS_TREADY),

      .m_axis_qdma_cpl_tvalid               (axis_qdma_cpl_tvalid),
      .m_axis_qdma_cpl_tdata                (axis_qdma_cpl_tdata),
      .m_axis_qdma_cpl_size                 (axis_qdma_cpl_size),
      .m_axis_qdma_cpl_dpar                 (axis_qdma_cpl_dpar),
      .m_axis_qdma_cpl_ctrl_qid             (axis_qdma_cpl_ctrl_qid),
      .m_axis_qdma_cpl_ctrl_cmpt_type       (axis_qdma_cpl_ctrl_cmpt_type),
      .m_axis_qdma_cpl_ctrl_wait_pld_pkt_id (axis_qdma_cpl_ctrl_wait_pld_pkt_id),
      .m_axis_qdma_cpl_ctrl_port_id         (axis_qdma_cpl_ctrl_port_id),
      .m_axis_qdma_cpl_ctrl_marker          (axis_qdma_cpl_ctrl_marker),
      .m_axis_qdma_cpl_ctrl_user_trig       (axis_qdma_cpl_ctrl_user_trig),
      .m_axis_qdma_cpl_ctrl_col_idx         (axis_qdma_cpl_ctrl_col_idx),
      .m_axis_qdma_cpl_ctrl_err_idx         (axis_qdma_cpl_ctrl_err_idx),
      .m_axis_qdma_cpl_ctrl_no_wrb_marker   (axis_qdma_cpl_ctrl_no_wrb_marker),
      .m_axis_qdma_cpl_tready               (1'b1), //(axis_qdma_cpl_tready),

      .debug                               (debug),
      .qmask                               (qmask),
      
      .qid_index                           (qid_index),
      .qid_index_update                    (qid_index_update),
      .qid_data                            (qid_data),
       
      .packet_counter_ram_we               (packet_counter_ram_we),
      .qid_packet_counter                  (qid_packet_counter),


      .c2h_byp_in_st_csh_vld           (c2h_byp_in_st_csh_vld),
      .c2h_byp_in_st_csh_addr          (c2h_byp_in_st_csh_addr),
      .c2h_byp_in_st_csh_port_id       (c2h_byp_in_st_csh_port_id),
      .c2h_byp_in_st_csh_qid           (c2h_byp_in_st_csh_qid),
      .c2h_byp_in_st_csh_error         (c2h_byp_in_st_csh_error),
      .c2h_byp_in_st_csh_func          (c2h_byp_in_st_csh_func),
      .c2h_byp_in_st_csh_pfch_tag      (c2h_byp_in_st_csh_pfch_tag),
      .c2h_byp_in_st_csh_rdy           (1'b1), //(c2h_byp_in_st_csh_rdy),

      .pkt_counter                     (pkt_counter),
      .full_counter                    (full_counter),
      
      .c2h_status_valid                     (c2h_status_valid),
      .c2h_status_bytes                     (c2h_status_bytes),
      .c2h_status_func_id                   (c2h_status_func_id),

      .axis_aclk                            (clk),
      .axil_aresetn                         (rstn)
    );


//assign S0_AXIS_TUSER=32'b0;
/*
wire [511:0] temp_data;
wire [63:0] temp_keep;
wire [47:0]temp_user;
wire temp_valid;
wire temp_last;
wire temp_ready;
*/

//assign M0_AXIS_TREADY= (randomNumber %2)==0 ? 1'b0 : 1'b1;

int unsigned randomNumber;
wire cpl_tready;

always_ff @(negedge rstn or posedge clk) begin
        if(~rstn) begin
            randomNumber = $urandom(42); 
        end else begin
            randomNumber = $urandom();
        end    
end
assign cpl_tready= (randomNumber %20)==0 ? 1'b0 : 1'b1; 

pcap_dumper
#(
    .pcap_filename 	( "sink.pcap")
)
AXIS_SINK_PCIE
(
    .rst_n       	( rstn ),
    .tdata        	(M0_AXIS_TDATA ),
    .tstrb        	(M0_AXIS_TKEEP ),
    .tready       	(M0_AXIS_TREADY),
    .tvalid       	(M0_AXIS_TVALID),
    .tlast         	(M0_AXIS_TLAST),
    .clk         	( clk ),
    .eos    	(  1'b0),
    .pktcount	(  rx_pktcount_1)
);


endmodule;
