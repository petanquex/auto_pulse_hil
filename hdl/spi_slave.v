`timescale 1ns / 1ps

module spi_slave (
    input  wire        clk,        // FPGA System Clock (e.g., 50 MHz)
    input  wire        rst_n,      // Active-low asynchronous reset
    input  wire        sclk,       // SPI Clock from external master
    input  wire        cs_n,       // SPI Chip Select (Active Low)
    input  wire        mosi,       // SPI Master Out, Slave In (Data)
    
    output reg  [15:0] cmd_out,    // The assembled 16-bit packet
    output reg         data_ready  // 1-clock-cycle pulse when packet is valid
);

    // =========================================================================
    // 1. Synchronizers (Double-Flopping)
    // Safely bring external asynchronous signals into the FPGA clock domain.
    // =========================================================================
    reg [2:0] sclk_sync;
    reg [2:0] cs_n_sync;
    reg [1:0] mosi_sync; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_n_sync <= 3'b111; // Chip select defaults to High (Inactive)
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_n_sync <= {cs_n_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    // =========================================================================
    // 2. Edge Detection
    // By looking at the history of the synchronized signals, we can detect edges.
    // 2'b01 means the previous clock it was 0, and this clock it is 1 (Rising)
    // =========================================================================
    wire sclk_rising_edge = (sclk_sync[2:1] == 2'b01);
    wire cs_n_rising_edge = (cs_n_sync[2:1] == 2'b01);


    // =========================================================================
    // 3. Shift Register & Bit Counting Logic
    // =========================================================================
    reg [15:0] shift_reg;
    reg [4:0]  bit_count; // Needs to count up to 16

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg  <= 16'b0;
            cmd_out    <= 16'b0;
            data_ready <= 1'b0;
            bit_count  <= 5'b0;
        end else begin
            // Default state: Keep the data_ready flag low. 
            // It will only pulse high for exactly 1 clock cycle when data arrives.
            data_ready <= 1'b0; 

            // If Chip Select is active (LOW)
            if (!cs_n_sync[1]) begin
                if (sclk_rising_edge) begin
                    // Shift the data left, append the new MOSI bit to the right
                    shift_reg <= {shift_reg[14:0], mosi_sync[1]};
                    bit_count <= bit_count + 1'b1;
                end
            end
            
            // When Chip Select goes HIGH, the transmission is over
            if (cs_n_rising_edge) begin
                // Security check: Only accept the command if exactly 16 bits arrived
                if (bit_count == 5'd16) begin 
                    cmd_out    <= shift_reg;
                    data_ready <= 1'b1; // Trigger the downstream PWM routers
                end
                bit_count <= 5'b0; // Reset the counter for the next packet
            end
        end
    end

endmodule