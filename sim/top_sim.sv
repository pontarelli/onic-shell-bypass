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

    //qid=0            
    addr =32'hFF0;
    axi_write(addr,0);
    #400ns
    
    //phys_addr
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
    
    //qid=1            
    addr =32'hFF0;
    axi_write(addr,1);
    #400ns
    
    //phys_addr
    addr =32'h400;
    axi_write(addr,32'hbeba0000);
    #400ns
    
    addr =32'h404;
    axi_write(addr,0);
    #400ns
    
    addr =32'h408; 
    axi_write(addr,1024); //num_desc
    #400ns
    
    addr =32'h40C;
    axi_write(addr,129); //valid + tag=1
    #400ns
    
    //qid=2            
    addr =32'hFF0;
    axi_write(addr,2);
    #400ns
    
    //phys_addr
    addr =32'h400;
    axi_write(addr,32'hdead0000);
    #400ns
    
    addr =32'h404;
    axi_write(addr,0);
    #400ns
    
    addr =32'h408; 
    axi_write(addr,1024); //num_desc
    #400ns
    
    addr =32'h40C;
    axi_write(addr,130); //valid + tag=2
    #400ns
    
    pause= 1'b0;
    
    
    #100us
    axi_write(addr,1008*256+128); //cidx=1021 + valid + tag=0 
    
    //$display("data is %d",data);
        
end 

  wire             fence;
  wire      [31:0] debug;
  wire      [10:0] qid;
  wire      [10:0] qmask;
  wire      [10:0] qid_index;
  wire      [10:0] qid_index_update;
  wire             packet_counter_ram_we;
  wire             packet_counter_ram_we256;
  wire             packet_counter_ram_we512;
  wire      [31:0] qid_packet_counter;
  wire     [127:0] qid_data;
  wire      [31:0] full_counter;
  wire      [31:0] pkt_counter;
  wire                         c2h_status_valid;
  wire                  [15:0] c2h_status_bytes;
  wire                   [1:0] c2h_status_func_id;
  
  
  wire [511:0] temp_data;
  wire [63:0] temp_keep;
  wire [10:0] temp_qid;
  wire [10:0] temp_qidp1;
  wire [10:0] temp_size;
  wire temp_valid;
  wire temp_last;
  wire temp_ready;
  wire cpl_tready;
  wire byp_ready;
  wire [63:0] c2h_byp_in_st_csh_addr;
  wire [31:0] phys_addrL;
  wire [31:0] phys_addrH;
   
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
    //.qid            (qid                                                                           ),
    .eop            (S0_AXIS_TLAST                                                                 ),
    .clk            (clk         	                                                               ),
    .pktcount       (tx_pktcount_1                                                                 ),
    .pcapfinished   (pcapfinished_1	                                                               ) 

);

  qdma_subsystem_function #(
        .FUNC_ID     (0),
        .QDMA_ID     (0),
        .MAX_PKT_LEN (1518),
        .MIN_PKT_LEN (64)
      ) func_inst (
        .s_axil_awvalid        (1'b0),
        .s_axil_awaddr         (32'd0),
        .s_axil_awready        (),
        .s_axil_wvalid         (1'b0),
        .s_axil_wdata          (32'd0),
        .s_axil_wready         (),
        .s_axil_bvalid         (),
        .s_axil_bresp          (),
        .s_axil_bready         (1'b0),
        .s_axil_arvalid        (1'b0),
        .s_axil_araddr         (32'd0),
        .s_axil_arready        (),
        .s_axil_rvalid         (),
        .s_axil_rdata          (),
        .s_axil_rresp          (),
        .s_axil_rready         (1'b0),

        .s_axis_h2c_tvalid     (1'b0),
        .s_axis_h2c_tdata      ({512{1'b0}}),
        .s_axis_h2c_tlast      (1'b0),
        .s_axis_h2c_tuser_size (16'd0),
        .s_axis_h2c_tuser_qid  (11'd0),
        .s_axis_h2c_tready     (),

        .m_axis_h2c_tvalid     (),
        .m_axis_h2c_tdata      (),
        .m_axis_h2c_tkeep      (),
        .m_axis_h2c_tlast      (),
        .m_axis_h2c_tuser_size (),
        .m_axis_h2c_tuser_src  (),
        .m_axis_h2c_tuser_dst  (),
        .m_axis_h2c_tready     (1'b0),

        .s_axis_c2h_tvalid     (S0_AXIS_TVALID),
        .s_axis_c2h_tdata      (S0_AXIS_TDATA),
        .s_axis_c2h_tkeep      (S0_AXIS_TKEEP),
        .s_axis_c2h_tlast      (S0_AXIS_TLAST),
        .s_axis_c2h_tuser_size (S0_AXIS_TUSER[15:0]),
        .s_axis_c2h_tuser_src  (16'd0),
        .s_axis_c2h_tuser_dst  (16'd0),
        .s_axis_c2h_tready     (S0_AXIS_TREADY),

        .m_axis_c2h_tvalid     (temp_valid),
        .m_axis_c2h_tdata      (temp_data),
        .m_axis_c2h_tlast      (temp_last),
        .m_axis_c2h_tuser_size (temp_size),
        .m_axis_c2h_tuser_qid  (temp_qid),
        .m_axis_c2h_tready     (temp_ready),

        .axil_aclk             (clk),
        .axis_aclk             (clk),
        .axis_master_aclk      (clk),
        .axil_aresetn          (rstn)
        
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
      .external_packet_counter_ram_we256(packet_counter_ram_we256),
      .external_packet_counter_ram_we512(packet_counter_ram_we512),
      .external_qid_packet_counter(qid_packet_counter),
      .external_qid_data(qid_data),
      .pkt_counter(pkt_counter),
      .full_counter(full_counter),

      .axil_aclk      (clk),
      .axis_aclk      (clk),
      .axil_aresetn   (rstn)
    );

assign temp_qidp1 =temp_qid +1;

    qdma_subsystem_c2h #(
      .NUM_PHYS_FUNC (1)
    ) c2h_inst (
      .s_axis_c2h_tvalid                    (temp_valid),
      .s_axis_c2h_tdata                     (temp_data),
      .s_axis_c2h_tlast                     (temp_last),
      .s_axis_c2h_tuser_size                (temp_size),
      .s_axis_c2h_tuser_qid                 (temp_qidp1),
      .s_axis_c2h_tready                    (temp_ready),

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
      .m_axis_qdma_c2h_tready               (byp_ready), //(M0_AXIS_TREADY),

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
      .m_axis_qdma_cpl_tready               (cpl_tready), //(axis_qdma_cpl_tready),

      .debug                               (debug),
      .qmask                               (qmask),
      
      .qid_index                           (qid_index),
      .qid_index_update                    (qid_index_update),
      .qid_data                            (qid_data),
       
      .packet_counter_ram_we               (packet_counter_ram_we),
      .packet_counter_ram_we256            (packet_counter_ram_we256),
      .packet_counter_ram_we512            (packet_counter_ram_we512),
      
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

assign phys_addrL = c2h_byp_in_st_csh_addr[31:0];
assign phys_addrH = c2h_byp_in_st_csh_addr[63:32];

//assign S0_AXIS_TUSER=32'b0;
/*
*/

//assign M0_AXIS_TREADY= (randomNumber %2)==0 ? 1'b0 : 1'b1;

int unsigned randomNumber;

always_ff @(negedge rstn or posedge clk) begin
        if(~rstn) begin
            randomNumber = $urandom(42); 
        end else begin
            randomNumber = $urandom();
        end    
end

assign cpl_tready= (randomNumber %19)==0 ? 1'b0 : 1'b1; 
assign byp_ready = (randomNumber %13)==0 ? 1'b0 : 1'b1;

always_ff @(posedge clk) begin
    if (c2h_inst.m_axis_qdma_cpl_tvalid & c2h_inst.m_axis_qdma_cpl_tready)
        $display(c2h_inst.m_axis_qdma_cpl_ctrl_wait_pld_pkt_id);
end


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

