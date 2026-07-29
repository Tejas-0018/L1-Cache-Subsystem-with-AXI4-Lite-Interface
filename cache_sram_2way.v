

module cache_sram_2way(
    input clock,
    input reset,
    input [2:0] index,
    input we,                      
    input mem_to_cache,            
    input [6:0] tag_in,
    input [31:0] data_in,          
    
    output hit_out,
    output [31:0] data_out,
    output evict_dirty_out,        
    output [6:0] evict_tag_out     
);

    // ==========================================
    // BLOCK 1: THE PHYSICAL REGISTERS
    // ==========================================
    // We duplicate the storage to create two "Ways" for the same index.
    reg [31:0] data_way0 [0:7]; 
    reg [6:0]  tag_way0  [0:7];
    reg        valid_way0[0:7];
    reg        dirty_way0[0:7]; 

    reg [31:0] data_way1 [0:7]; 
    reg [6:0]  tag_way1  [0:7];
    reg        valid_way1[0:7];
    reg        dirty_way1[0:7]; 
    
    // 1-bit tracker per index: 0 = Way 0 is oldest, 1 = Way 1 is oldest
    reg lru_array [0:7];
    
    integer i;

    // ==========================================
    // BLOCK 2: COMBINATIONAL READS & HITS
    // ==========================================
    // Hardware comparators check both ways simultaneously
    wire hit_w0 = valid_way0[index] && (tag_way0[index] == tag_in);
    wire hit_w1 = valid_way1[index] && (tag_way1[index] == tag_in);
    
    assign hit_out = hit_w0 || hit_w1;
    
    // MUX to route the correct data out. If it's a miss, route the LRU data out for eviction.
    assign data_out = hit_w0 ? data_way0[index] : 
                      hit_w1 ? data_way1[index] : 
                      (lru_array[index] == 1'b0) ? data_way0[index] : data_way1[index];

    assign evict_dirty_out = (lru_array[index] == 1'b0) ? dirty_way0[index] : dirty_way1[index];
    assign evict_tag_out   = (lru_array[index] == 1'b0) ? tag_way0[index] : tag_way1[index];

    // ==========================================
    // BLOCK 3: SYNCHRONOUS WRITES & LRU TRACKING
    // ==========================================
    always @(posedge clock) begin
        if (reset) begin
            for(i = 0; i < 8; i = i + 1) begin
                valid_way0[i] <= 1'b0; dirty_way0[i] <= 1'b0;
                valid_way1[i] <= 1'b0; dirty_way1[i] <= 1'b0;
                lru_array[i]  <= 1'b0; 
            end
        end else if (we) begin
            // We are writing new data into the cache
            if (mem_to_cache) begin
                // Writing from Main Memory (Allocation) -> Overwrite the LRU way
                if (lru_array[index] == 1'b0) begin
                    data_way0[index]  <= data_in;
                    tag_way0[index]   <= tag_in;
                    valid_way0[index] <= 1'b1;
                    dirty_way0[index] <= 1'b0; 
                    lru_array[index]  <= 1'b1; // Way 0 was just used, so Way 1 is now older
                end else begin
                    data_way1[index]  <= data_in;
                    tag_way1[index]   <= tag_in;
                    valid_way1[index] <= 1'b1;
                    dirty_way1[index] <= 1'b0; 
                    lru_array[index]  <= 1'b0; 
                end
            end else begin
                // Writing from CPU -> Update the way that successfully hit
                if (hit_w0) begin
                    data_way0[index]  <= data_in;
                    dirty_way0[index] <= 1'b1; 
                    lru_array[index]  <= 1'b1; 
                end else if (hit_w1) begin
                    data_way1[index]  <= data_in;
                    dirty_way1[index] <= 1'b1; 
                    lru_array[index]  <= 1'b0; 
                end
            end
        end else if (hit_out) begin
            // If the CPU just reads, we still must update the LRU bit
            if (hit_w0) lru_array[index] <= 1'b1;
            if (hit_w1) lru_array[index] <= 1'b0;
        end
    end
endmodule
