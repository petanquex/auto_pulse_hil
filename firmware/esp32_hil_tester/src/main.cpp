#include <Arduino.h>
#include <SPI.h>

// --- Pin Definitions ---
const int CS_PIN = 5;       // SPI Chip Select
const int PWM_CH1_IN = 25;  // Wire this to FPGA PIN_32
const int PWM_CH2_IN = 26;  // Wire this to FPGA PIN_33

// --- Interrupt Variables for PWM Measurement ---
// Using cycle counts for maximum HIL accuracy
volatile uint32_t ch1_rise = 0;
volatile uint32_t ch1_high_time = 0;
volatile uint32_t ch1_period = 0;

// // Interrupt Service Routine for Channel 1
// void IRAM_ATTR pwm_ch1_isr() {
//     uint32_t now = ESP.getCycleCount();
//     if (digitalRead(PWM_CH1_IN)) {
//         ch1_period = now - ch1_rise;
//         ch1_rise = now;
//     } else {
//         ch1_high_time = now - ch1_rise;
//     }
// }

// Interrupt Service Routine for Channel 1
void IRAM_ATTR pwm_ch1_isr() {
    uint32_t now = ESP.getCycleCount();
    
    // THE FIX: Direct hardware register read. 
    // This is virtually instant compared to digitalRead()
    bool is_high = (GPIO.in >> PWM_CH1_IN) & 0x1;
    
    if (is_high) {
        ch1_period = now - ch1_rise;
        ch1_rise = now;
    } else {
        ch1_high_time = now - ch1_rise;
    }
}

void setup() {
    Serial.begin(115200);
    
    // Setup SPI
    pinMode(CS_PIN, OUTPUT);
    digitalWrite(CS_PIN, HIGH);
    SPI.begin(18,19,23,5); // Default VSPI: SCLK=18, MISO=19, MOSI=23

    // Setup PWM Measurement Interrupts
    pinMode(PWM_CH1_IN, INPUT);
    attachInterrupt(digitalPinToInterrupt(PWM_CH1_IN), pwm_ch1_isr, CHANGE);
    
    Serial.println("HIL_READY");
}

// Helper to send the 16-bit packet
void send_spi_command(uint8_t channel, uint16_t speed) {
    uint16_t packet = (channel << 12) | (speed & 0x0FFF);
    
    SPI.beginTransaction(SPISettings(10000000, MSBFIRST, SPI_MODE0)); // 10 MHz
    digitalWrite(CS_PIN, LOW);
    SPI.transfer16(packet);
    digitalWrite(CS_PIN, HIGH);
    SPI.endTransaction();
}

void loop() {
    // Listen for commands from the Python test script (e.g., "TEST 1 2048")
    if (Serial.available() > 0) {
        String cmd = Serial.readStringUntil('\n');
        cmd.trim();
        
        if (cmd.startsWith("TEST")) {
            int channel, speed;
            sscanf(cmd.c_str(), "TEST %d %d", &channel, &speed);
            
            // 1. Send the physical SPI command to the FPGA
            send_spi_command(channel, speed);
            
            // 2. Wait a moment for the FPGA to update its PWM output
            delay(10); 
            
            // 3. Calculate duty cycle from the hardware interrupts
            float duty_cycle = 0.0;
            if (ch1_period > 0) {
                // Disable interrupts briefly to safely copy the volatile variables
                noInterrupts();
                uint32_t high = ch1_high_time;
                uint32_t total = ch1_period;
                interrupts();
                
                duty_cycle = ((float)high / (float)total) * 100.0;
            }
            
            // 4. Report back to the GitHub Runner
            Serial.printf("RESULT CH:%d SET:%d MEASURED:%.2f\n", channel, speed, duty_cycle);
        }
    }
}