

module axi_cache_datapath (
    input clock,
    input reset,
    
    // CPU Interface
    input [11:0] cpu_address,
    input [7:0] cpu_data_in,
    output [7:0] cpu_data_out,
    output hit,
    output evict_dirty,       
    
    // Control Signals (Coming from FSM)
    input cache_we,         
    input mem_to_cache,     
    
    // AXI Master Data & Address Buses (Going to Main Memory)
    output [11:0] M_AXI_AWADDR, 
    output [31:0] M_AXI_WDATA,  
    output [11:0] M_AXI_ARADDR, 
    input  [31:0] M_AXI_RDATA   
);

    wire [1:0] offset = cpu_address[1:0];
    wire [2:0] index  = cpu_address[4:2];
    wire [6:0] tag    = cpu_address[11:5];
    
    wire [31:0] cache_line_out;      
    wire [6:0]  evict_tag;
    wire [31:0] cache_write_data;    

    // CPU Read MUX: Extract 1 byte from the 32-bit line
    assign cpu_data_out = (offset == 2'b00) ? cache_line_out[7:0]   :
                          (offset == 2'b01) ? cache_line_out[15:8]  :
                          (offset == 2'b10) ? cache_line_out[23:16] :
                                              cache_line_out[31:24] ;

    // CPU Write MUX: Combine 1 new byte with 3 old bytes OR pass AXI data
    assign cache_write_data = mem_to_cache ? M_AXI_RDATA : 
                              (offset == 2'b00) ? {cache_line_out[31:8], cpu_data_in} :
                              (offset == 2'b01) ? {cache_line_out[31:16], cpu_data_in, cache_line_out[7:0]} :
                              (offset == 2'b10) ? {cache_line_out[31:24], cpu_data_in, cache_line_out[15:0]} :
                                                  {cpu_data_in, cache_line_out[23:0]};

    // AXI Bus Address Routing
    assign M_AXI_ARADDR = {tag, index, 2'b00};       // Fetch address
    assign M_AXI_AWADDR = {evict_tag, index, 2'b00}; // Evict address
    assign M_AXI_WDATA  = cache_line_out;            // Evict data

    // Instantiate your 2-Way SRAM
    cache_sram_2way CSRAM_2WAY (
        .clock(clock),
        .reset(reset),
        .index(index),
        .we(cache_we),
        .mem_to_cache(mem_to_cache),  
        .tag_in(tag),
        .data_in(cache_write_data),
        
        .hit_out(hit),
        .data_out(cache_line_out),
        .evict_dirty_out(evict_dirty),
        .evict_tag_out(evict_tag)
    );

endmodule
