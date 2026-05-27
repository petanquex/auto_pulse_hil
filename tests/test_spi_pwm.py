import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge

# ==============================================================================
# Helper Function: The Virtual SPI Master
# ==============================================================================
async def send_spi_command(dut, channel_id, speed_val):
    """
    Simulates an STM32/ESP32 sending a 16-bit SPI packet.
    Packet format: [4-bit Channel ID] [12-bit Speed]
    """
    # 1. Combine the 4-bit ID and 12-bit speed into a single 16-bit number
    packet = (channel_id << 12) | (speed_val & 0x0FFF)
    
    # 2. Pull Chip Select LOW to start the transaction
    dut.cs_n.value = 0
    await Timer(100, unit="ns") # Brief pause before sending data
    
    # 3. Shift out the 16 bits, one by one, starting from the Most Significant Bit (MSB)
    for i in range(15, -1, -1):
        # Extract the current bit (1 or 0) and put it on the MOSI wire
        bit_to_send = (packet >> i) & 1
        dut.mosi.value = bit_to_send
        
        # Wait a moment, then pulse the SPI Clock HIGH
        await Timer(50, unit="ns")
        dut.sclk.value = 1
        
        # Wait a moment, then pull the SPI Clock LOW
        await Timer(50, unit="ns")
        dut.sclk.value = 0
        
    # 4. Pull Chip Select HIGH to end the transaction
    await Timer(100, unit="ns")
    dut.cs_n.value = 1
    await Timer(200, unit="ns") # Rest before the next command

# ==============================================================================
# The Main Test Suite
# ==============================================================================
@cocotb.test()
async def test_motor_routing(dut):
    """
    Test that SPI commands correctly route to the proper motor memory registers.
    """
    # 1. Start a 50 MHz clock running in the background forever
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # 2. Set default states for the input pins
    dut.sclk.value = 0
    dut.cs_n.value = 1
    dut.mosi.value = 0
    dut.rst_n.value = 1

    # 3. Perform a Hardware Reset
    dut.rst_n.value = 0            # Press the reset button
    await Timer(100, unit="ns")   # Hold it for 100ns
    dut.rst_n.value = 1            # Release the reset button
    await Timer(100, unit="ns")   # Wait for the system to wake up

    # 4. Send Command 1: Tell Motor 1 (Channel ID 1) to go to speed 2048 (50%)
    await send_spi_command(dut, channel_id=1, speed_val=2048)

    # Allow the Verilog time to update its internal registers
    await RisingEdge(dut.clk)
    
    # Assert (Verify) that the internal router caught the packet and saved it to Motor 1
    assert dut.duty_ch1.value.to_unsigned() == 2048, f"Motor 1 failed! Got {dut.duty_ch1.value.to_unsigned()}"
    assert dut.duty_ch2.value.to_unsigned() == 0, "Motor 2 accidentally received Motor 1's data!"


    # 5. Send Command 2: Tell Motor 2 (Channel ID 2) to go to speed 4000 (97%)
    await send_spi_command(dut, channel_id=2, speed_val=4000)
    
    await RisingEdge(dut.clk)

    # Assert that Motor 2 updated, and Motor 1 remembered its old speed
    assert dut.duty_ch2.value.to_unsigned() == 4000, "Motor 2 failed to update!"
    assert dut.duty_ch1.value.to_unsigned() == 2048, "Motor 1 forgot its speed!"

    # 6. Let the simulation run for a bit to generate a nice waveform for viewing
    await Timer(5000, unit="ns")