`timescale 1ns / 1ps

module pwm_generator (
    input  wire        clk,        // FPGA System Clock (e.g., 50 MHz)
    input  wire        rst_n,      // Active-low asynchronous reset
    input  wire [11:0] duty_cycle, // 12-bit requested speed (0 to 4095)
    
    output reg         pwm_out     // Physical electrical signal to the motor
);

    // =========================================================================
    // Internal Registers
    // =========================================================================
    reg [11:0] counter; // A 12-bit counter to keep track of the PWM period

    // =========================================================================
    // Core PWM Logic
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state: Turn off the motor and reset the clock
            counter <= 12'b0;
            pwm_out <= 1'b0;
        end else begin
            // 1. The Timekeeper: Count up by 1 every clock cycle
            counter <= counter + 1'b1;

            // 2. The Comparator: Generate the pulse
            if (counter < duty_cycle) begin
                pwm_out <= 1'b1; // Turn the pin ON
            end else begin
                pwm_out <= 1'b0; // Turn the pin OFF
            end
        end
    end

endmodule