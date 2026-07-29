
module top_level_cache_system (
    input wire clk,
    input wire reset, // Active-High reset from CPU
    
    // Unified CPU Interface
    input wire cpu_req,           
    input wire cpu_rw,            // 0 = Read, 1 = Write
    input wire [11:0] cpu_address,
    input wire [7:0] cpu_data_in,
    
    output wire [7:0] cpu_data_out,
    output wire cpu_ready,        
    output wire cache_hit,        
    
    // ==========================================
    // Hardware Performance Counters (Exposed for Testbench)
    // ==========================================
    output reg [31:0] perf_total_accesses,
    output reg [31:0] perf_total_misses,
    output reg [31:0] perf_total_writebacks
);

    // ==========================================
    // 1. Internal Connecting Wires
    // ==========================================
    
    // Datapath <-> FSM Wires
    wire datapath_hit;
    wire evict_dirty;
    wire cache_we;
    wire mem_to_cache;
    
    assign cache_hit = datapath_hit;
    
    // AXI standard requires an active-low reset
    wire aresetn = ~reset; 

    // AXI4-Lite Bus Wires
    wire [11:0] axi_awaddr;
    wire        axi_awvalid, axi_awready;
    
    wire [31:0] axi_wdata;
    wire        axi_wvalid, axi_wready;
    
    wire [1:0]  axi_bresp;
    wire        axi_bvalid, axi_bready;
    
    wire [11:0] axi_araddr;
    wire        axi_arvalid, axi_arready;
    
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rvalid, axi_rready;

    // ==========================================
    // 2. Module Instantiations
    // ==========================================

    axi_cache_fsm FSM (
        .clk(clk),
        .reset(reset),
        
        .cpu_req(cpu_req),
        .cpu_rw(cpu_rw),
        .cpu_ready(cpu_ready),
        
        .cache_hit(datapath_hit),
        .evict_dirty(evict_dirty),
        .cache_we(cache_we),
        .mem_to_cache(mem_to_cache),
        
        // AXI Control Wiring
        .M_AXI_AWVALID(axi_awvalid), .M_AXI_AWREADY(axi_awready),
        .M_AXI_WVALID(axi_wvalid),   .M_AXI_WREADY(axi_wready),
        .M_AXI_BREADY(axi_bready),   .M_AXI_BVALID(axi_bvalid),
        .M_AXI_ARVALID(axi_arvalid), .M_AXI_ARREADY(axi_arready),
        .M_AXI_RREADY(axi_rready),   .M_AXI_RVALID(axi_rvalid)
    );

    axi_cache_datapath DATAPATH (
        .clock(clk),
        .reset(reset),
        
        .cpu_address(cpu_address),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        .hit(datapath_hit),
        .evict_dirty(evict_dirty),
        
        .cache_we(cache_we),
        .mem_to_cache(mem_to_cache),
        
        // AXI Data/Address Wiring
        .M_AXI_AWADDR(axi_awaddr),
        .M_AXI_WDATA(axi_wdata),
        .M_AXI_ARADDR(axi_araddr),
        .M_AXI_RDATA(axi_rdata)
    );

    axi_main_memory MAIN_MEM (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(aresetn), // Pass active-low reset
        
        .S_AXI_AWADDR(axi_awaddr),
        .S_AXI_AWVALID(axi_awvalid),
        .S_AXI_AWREADY(axi_awready),
        
        .S_AXI_WDATA(axi_wdata),
        .S_AXI_WSTRB(4'b1111), // Always write full 32-bits (4 bytes)
        .S_AXI_WVALID(axi_wvalid),
        .S_AXI_WREADY(axi_wready),
        
        .S_AXI_BRESP(axi_bresp),
        .S_AXI_BVALID(axi_bvalid),
        .S_AXI_BREADY(axi_bready),
        
        .S_AXI_ARADDR(axi_araddr),
        .S_AXI_ARVALID(axi_arvalid),
        .S_AXI_ARREADY(axi_arready),
        
        .S_AXI_RDATA(axi_rdata),
        .S_AXI_RRESP(axi_rresp),
        .S_AXI_RVALID(axi_rvalid),
        .S_AXI_RREADY(axi_rready)
    );

    // ==========================================
    // 3. Performance Analysis Counters
    // ==========================================
    
    reg req_active; // Prevents double-counting a request held high

    always @(posedge clk) begin
        if (reset) begin
            perf_total_accesses   <= 32'd0;
            perf_total_misses     <= 32'd0;
            perf_total_writebacks <= 32'd0;
            req_active            <= 1'b0;
        end else begin
            // 1. Count Total CPU Accesses
            if (cpu_req && !req_active) begin
                perf_total_accesses <= perf_total_accesses + 1;
                req_active <= 1'b1;
            end else if (!cpu_req) begin
                req_active <= 1'b0;
            end

            // 2. Count Cache Misses
            // A miss triggers a Read Address handshake to memory
            if (axi_arvalid && axi_arready) begin
                perf_total_misses <= perf_total_misses + 1;
            end

            // 3. Count Write-Backs (Evictions)
            // An eviction triggers a Write Address handshake to memory
            if (axi_awvalid && axi_awready) begin
                perf_total_writebacks <= perf_total_writebacks + 1;
            end
        end
    end

endmodule
