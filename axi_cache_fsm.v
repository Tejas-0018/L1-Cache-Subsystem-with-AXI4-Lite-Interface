

module axi_cache_fsm (
    input wire clk,
    input wire reset,
    
    // CPU Interface
    input wire cpu_req,       
    input wire cpu_rw,        
    output reg cpu_ready,     
    
    // Datapath / SRAM Interface
    input wire cache_hit,     
    input wire evict_dirty,   
    output reg cache_we,      
    output reg mem_to_cache,  // 1 = write from AXI to SRAM, 0 = CPU to SRAM
    
    // ==========================================
    // AXI4-Lite Master Control Signals
    // ==========================================
    output reg M_AXI_AWVALID, input wire M_AXI_AWREADY, // Write Address
    output reg M_AXI_WVALID,  input wire M_AXI_WREADY,  // Write Data
    output reg M_AXI_BREADY,  input wire M_AXI_BVALID,  // Write Response
    output reg M_AXI_ARVALID, input wire M_AXI_ARREADY, // Read Address
    output reg M_AXI_RREADY,  input wire M_AXI_RVALID   // Read Data
);

    localparam [2:0] 
        IDLE         = 3'd0,
        COMPARE      = 3'd1,
        WB_REQ       = 3'd2, // Write-Back Request (Address + Data)
        WB_WAIT      = 3'd3, // Wait for Write Response
        ALLOC_REQ    = 3'd4, // Request new block (Address)
        ALLOC_WAIT   = 3'd5; // Wait for new block (Data)

    reg [2:0] current_state, next_state;

    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= IDLE;
        else       current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state; 
        case (current_state)
            IDLE: if (cpu_req) next_state = COMPARE;
            
            COMPARE: begin
                if (cache_hit)           next_state = IDLE; 
                else if (evict_dirty)    next_state = WB_REQ; // Must evict dirty block first
                else                     next_state = ALLOC_REQ; // Clean block, just fetch
            end
            
            WB_REQ: // Hold VALID high until Memory says READY for both address and data
                if (M_AXI_AWREADY && M_AXI_WREADY) next_state = WB_WAIT;
                
            WB_WAIT: // Wait for confirmation the write finished
                if (M_AXI_BVALID) next_state = ALLOC_REQ;
                
            ALLOC_REQ: // Hold VALID high until Memory accepts read address
                if (M_AXI_ARREADY) next_state = ALLOC_WAIT;
                
            ALLOC_WAIT: // Wait for the requested data to arrive
                if (M_AXI_RVALID) next_state = COMPARE; // Data arrived! Go back and hit.
                
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Default everything to 0 to prevent accidental toggles)
    always @(*) begin
        cpu_ready     = 1'b0; cache_we      = 1'b0; mem_to_cache  = 1'b0;
        M_AXI_AWVALID = 1'b0; M_AXI_WVALID  = 1'b0; M_AXI_BREADY  = 1'b0;
        M_AXI_ARVALID = 1'b0; M_AXI_RREADY  = 1'b0;

        case (current_state)
            COMPARE: begin
                if (cache_hit) begin
                    cpu_ready = 1'b1;         
                    if (cpu_rw) cache_we = 1'b1; // CPU Write Hit
                end
            end
            
            WB_REQ: begin
                M_AXI_AWVALID = 1'b1; // Send Write Address
                M_AXI_WVALID  = 1'b1; // Send Write Data
            end
            
            WB_WAIT: begin
                M_AXI_BREADY = 1'b1; // Ready to receive confirmation
            end
            
            ALLOC_REQ: begin
                M_AXI_ARVALID = 1'b1; // Send Read Address
            end
            
            ALLOC_WAIT: begin
                M_AXI_RREADY = 1'b1;  // Ready to receive data
                if (M_AXI_RVALID) begin
                    cache_we = 1'b1;     // Save data to SRAM
                    mem_to_cache = 1'b1; // Route data from AXI bus
                end
            end
        endcase
    end
endmodule
