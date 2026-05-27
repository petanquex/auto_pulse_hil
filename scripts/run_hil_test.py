#!/usr/bin/env python3
import serial
import time
import sys

# Configuration matching your Phase 2 setup
SERIAL_PORT = '/dev/ttyUSB1'
BAUD_RATE = 115200
TIMEOUT = 5  # Wait up to 5 seconds for a response

def main():
    print("========================================")
    print(" Starting Hardware-in-the-Loop Test")
    print("========================================")
    
    try:
        # Open the serial connection to the ESP32
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=TIMEOUT)
        # Give the ESP32 a moment to reset upon serial connection
        time.sleep(2) 
        # ADD THIS LINE: Throw away any bootloader garbage in the buffer
        ser.reset_input_buffer()
    except Exception as e:
        print(f"ERROR: Could not open serial port {SERIAL_PORT}.")
        print("Did you pass the ESP32 through with usbipd?")
        print(f"Details: {e}")
        sys.exit(1)

    print(f"Connected to ESP32 on {SERIAL_PORT}.")
    
    # Send a command to test Channel 1 with a value of 2048 
    # (Assuming a 12-bit SPI system where 2048 / 4096 = 50% duty cycle)
    # Define your test parameters here (Safe range: 200 to 3896)
    target_channel = 1
    target_speed = 3000
    
    # Dynamically build the command string
    test_command = f"TEST {target_channel} {target_speed}\n"
    print(f"Sending command to ESP32: {test_command.strip()}")
    print(f"Sending command to ESP32: {test_command.strip()}")
    
    ser.write(test_command.encode('utf-8'))
    ser.flush()

    # Wait for and read the response
    start_time = time.time()
    result_line = ""
    
    while (time.time() - start_time) < TIMEOUT:
        if ser.in_waiting > 0:
            line = ser.readline().decode('utf-8', errors='ignore').strip()
            print(f"[ESP32 Console] {line}")
            
            # Look for our expected measurement string
            if "MEASURED:" in line:
                result_line = line
                break
    
    ser.close()

    if not result_line:
        print("========================================")
        print(" ERROR: Timed out waiting for ESP32 response.")
        print(" Check your physical jumper wires.")
        print("========================================")
        sys.exit(1)

    # Parse the measured value (Expecting format like "... MEASURED:50.02")
    try:
        measured_str = result_line.split("MEASURED:")[1].strip()
        measured_str = measured_str.replace('%', '') # Clean up if ESP32 sends a percent sign
        measured_val = float(measured_str)
    except Exception as e:
        print("========================================")
        print(" ERROR: Could not parse measurement from ESP32.")
        print(f" Raw String received: {result_line}")
        print("========================================")
        sys.exit(1)

    # Auto-calculate the expected physical percentage
    expected_val = (target_speed / 4096.0) * 100.0
    # Tolerance limit +-3%
    tolerance = 3.0 

    print("========================================")
    print(f" Expected Duty Cycle : {expected_val:.2f}%")
    print(f" Measured Duty Cycle : {measured_val}%")
    
    if abs(measured_val - expected_val) <= tolerance:
        print(" SUCCESS: Physical hardware passed HIL verification!")
        print("========================================")
        sys.exit(0)
    else:
        print(" ERROR: Physical hardware measurement out of tolerance!")
        print("========================================")
        sys.exit(1)

if __name__ == '__main__':
    main()