

module axi_main_memory (
    // 1. Global Signals (AXI standard uses active-low reset)
    input wire S_AXI_ACLK,
    input wire S_AXI_ARESETN,

    // 2. Write Address Channel (AW)
    input wire [11:0]  S_AXI_AWADDR,
    input wire         S_AXI_AWVALID,
    output reg         S_AXI_AWREADY,

    // 3. Write Data Channel (W)
    input wire [31:0]  S_AXI_WDATA,
    input wire [3:0]   S_AXI_WSTRB,    // Byte enable strobes
    input wire         S_AXI_WVALID,
    output reg         S_AXI_WREADY,

    // 4. Write Response Channel (B)
    output reg [1:0]   S_AXI_BRESP,
    output reg         S_AXI_BVALID,
    input wire         S_AXI_BREADY,

    // 5. Read Address Channel (AR)
    input wire [11:0]  S_AXI_ARADDR,
    input wire         S_AXI_ARVALID,
    output reg         S_AXI_ARREADY,

    // 6. Read Data Channel (R)
    output reg [31:0]  S_AXI_RDATA,
    output reg [1:0]   S_AXI_RRESP,
    output reg         S_AXI_RVALID,
    input wire         S_AXI_RREADY
);

    // Physical Memory Storage: 1024 blocks of 32-bits (4KB total)
    reg [31:0] memory_array [0:1023];

    // Internal latches for addresses
    reg [11:0] awaddr_latch;
    reg [11:0] araddr_latch;
    
    // Convert 12-bit byte address to 10-bit block index (drop bottom 2 bits)
    wire [9:0] write_index = awaddr_latch[11:2];
    wire [9:0] read_index  = araddr_latch[11:2];

    integer i;
    initial begin
        for(i = 0; i < 1024; i = i + 1) begin
            memory_array[i] = 32'h00000000;
        end
    end

    // =========================================================
    // WRITE LOGIC (AW, W, and B Channels)
    // =========================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00; // 00 = OKAY response
        end else begin
            // 1. Address Handshake
            if (S_AXI_AWVALID && !S_AXI_AWREADY) begin
                S_AXI_AWREADY <= 1'b1;
                awaddr_latch  <= S_AXI_AWADDR;
            end else begin
                S_AXI_AWREADY <= 1'b0;
            end

            // 2. Data Handshake & Write Execution
            if (S_AXI_WVALID && !S_AXI_WREADY) begin
                S_AXI_WREADY <= 1'b1;
                // Write into memory using the latched address
                memory_array[write_index] <= S_AXI_WDATA; 
            end else begin
                S_AXI_WREADY <= 1'b0;
            end

            // 3. Send Write Response (B channel)
            // Trigger response only after both Address and Data have been accepted
            if (S_AXI_AWREADY && S_AXI_AWVALID && S_AXI_WREADY && S_AXI_WVALID && !S_AXI_BVALID) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00; // OKAY
            end else if (S_AXI_BREADY && S_AXI_BVALID) begin
                // Master accepted our response, clear the valid flag
                S_AXI_BVALID <= 1'b0; 
            end
        end
    end

    // =========================================================
    // READ LOGIC (AR and R Channels)
    // =========================================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RRESP   <= 2'b00; // OKAY
        end else begin
            // 1. Address Handshake
            if (S_AXI_ARVALID && !S_AXI_ARREADY) begin
                S_AXI_ARREADY <= 1'b1;
                araddr_latch  <= S_AXI_ARADDR;
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end

            // 2. Data Retrieval & Response
            // If address is accepted and we aren't already sending unread data...
            if (S_AXI_ARREADY && S_AXI_ARVALID && !S_AXI_RVALID) begin
                S_AXI_RVALID <= 1'b1;
                S_AXI_RRESP  <= 2'b00; // OKAY
                S_AXI_RDATA  <= memory_array[read_index]; // Fetch data
            end else if (S_AXI_RREADY && S_AXI_RVALID) begin
                // Master successfully read the data, clear valid flag
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule
