

module tb_cache_randomized;

    // ==========================================
    // 1. Signals Declaration
    // ==========================================
    logic clk;
    logic reset;
    
    logic cpu_req;
    logic cpu_rw;
    logic [11:0] cpu_address;
    logic [7:0] cpu_data_in;
    
    logic [7:0] cpu_data_out;
    logic cpu_ready;
    logic cache_hit;
    
    logic [31:0] perf_total_accesses;
    logic [31:0] perf_total_misses;
    logic [31:0] perf_total_writebacks;

    // ==========================================
    // 2. Instantiate the Top Level Design (DUT)
    // ==========================================
    top_level_cache_system DUT (
        .clk(clk),
        .reset(reset),
        
        .cpu_req(cpu_req),
        .cpu_rw(cpu_rw),
        .cpu_address(cpu_address),
        .cpu_data_in(cpu_data_in),
        
        .cpu_data_out(cpu_data_out),
        .cpu_ready(cpu_ready),
        .cache_hit(cache_hit),
        
        .perf_total_accesses(perf_total_accesses),
        .perf_total_misses(perf_total_misses),
        .perf_total_writebacks(perf_total_writebacks)
    );

    // ==========================================
    // 3. Clock Generation
    // ==========================================
    always #5 clk = ~clk; 

    // ==========================================
    // 4. Main Test Sequence (Icarus-Safe)
    // ==========================================
    int i;
    real hit_rate;
    int rand_addr_chance;
    int rand_rw_chance;

    initial begin
        // Initialize
        clk = 0;
        reset = 1;
        cpu_req = 0;
        cpu_rw = 0;
        cpu_address = 0;
        cpu_data_in = 0;
        
        // Hold reset for a few cycles
        #25 reset = 0;
        #10;

        $display("--------------------------------------------------");
        $display(" Starting Icarus-Safe Random Cache Verification   ");
        $display("--------------------------------------------------");

        // Fire 2,000 random transactions into the cache
        for (i = 0; i < 2000; i++) begin
            
            // --- Custom Randomization Math ---
            
            // 1. Spatial Locality (85% Hot Zone, 15% Cold Zone)
            rand_addr_chance = $urandom_range(0, 99);
            if (rand_addr_chance < 85) begin
                cpu_address = $urandom_range(12'h000, 12'h03F); // Hot zone (first 64 bytes)
            end else begin
                cpu_address = $urandom_range(12'h040, 12'hFFF); // Cold zone
            end
            
            // 2. Read/Write Mix (70% Read, 30% Write)
            rand_rw_chance = $urandom_range(0, 99);
            if (rand_rw_chance < 70) begin
                cpu_rw = 1'b0; // Read
            end else begin
                cpu_rw = 1'b1; // Write
            end
            
            // 3. Random Data Payload
            cpu_data_in = $urandom_range(0, 255);
            
            // --- Drive the Bus ---
            
            @(posedge clk);
            cpu_req     <= 1'b1;
            
            // Wait for the FSM to signal the transaction is complete
            wait (cpu_ready == 1'b1);
            
            // Pull down request
            @(posedge clk);
            cpu_req <= 1'b0;
            
            // Insert 0 to 3 cycles of idle time before the next request
            repeat ($urandom_range(0, 3)) @(posedge clk); 
        end

        // Let the final transaction settle
        #100;
        
        // Calculate Hit Rate
        hit_rate = (1.0 - (real'(perf_total_misses) / real'(perf_total_accesses))) * 100.0;
        
        // Dump the hardware counter results
        $display("\n==================================================");
        $display("             HARDWARE PROFILING RESULTS           ");
        $display("==================================================");
        $display(" Total CPU Accesses : %0d", perf_total_accesses);
        $display(" Total Cache Misses : %0d", perf_total_misses);
        $display(" Total Write-Backs  : %0d", perf_total_writebacks);
        $display(" Final Hit Rate     : %0.2f %%", hit_rate);
        $display("==================================================");
        
        $finish;
    end
    
    // Waveform Dumping for EPWave
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache_randomized);
    end

endmodule
