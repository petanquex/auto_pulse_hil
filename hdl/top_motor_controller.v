`timescale 1ns / 1ps

module top_motor_controller (
    input  wire clk,        // FPGA System Clock (e.g., 50 MHz)
    input  wire rst_n,      // Active-low asynchronous reset
    
    // SPI Interface Pins (Connected to external ESP32/STM32)
    input  wire sclk,
    input  wire cs_n,
    input  wire mosi,
    
    // PWM Output Pins (Connected to physical motor drivers)
    output wire pwm_ch1,
    output wire pwm_ch2
);

    // =========================================================================
    // Internal Wires (The "Solder Traces" on our virtual PCB)
    // =========================================================================
    wire [15:0] spi_data;
    wire        spi_data_ready;

    // =========================================================================
    // 1. Instantiate the SPI Slave
    // =========================================================================
    spi_slave inst_spi (
        .clk        (clk),
        .rst_n      (rst_n),
        .sclk       (sclk),
        .cs_n       (cs_n),
        .mosi       (mosi),
        .cmd_out    (spi_data),
        .data_ready (spi_data_ready)
    );

    // =========================================================================
    // 2. The Router (Memory and Demultiplexer Logic)
    // =========================================================================
    reg [11:0] duty_ch1;
    reg [11:0] duty_ch2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_ch1 <= 12'b0;
            duty_ch2 <= 12'b0;
        end else begin
            // When the SPI module pulses data_ready HIGH...
            if (spi_data_ready) begin
                // Look at the top 4 bits (Channel ID) to decide where the data goes
                case (spi_data[15:12])
                    4'b0001: duty_ch1 <= spi_data[11:0]; // Route to Motor 1
                    4'b0010: duty_ch2 <= spi_data[11:0]; // Route to Motor 2
                    default: ; // Ignore invalid Channel IDs
                endcase
            end
        end
    end

    // =========================================================================
    // 3. Instantiate the PWM Generators
    // =========================================================================
    pwm_generator inst_pwm1 (
        .clk        (clk),
        .rst_n      (rst_n),
        .duty_cycle (duty_ch1),
        .pwm_out    (pwm_ch1)
    );

    pwm_generator inst_pwm2 (
        .clk        (clk),
        .rst_n      (rst_n),
        .duty_cycle (duty_ch2),
        .pwm_out    (pwm_ch2)
    );

endmodule