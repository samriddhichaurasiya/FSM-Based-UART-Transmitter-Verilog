# FSM-Based UART Transmitter (Verilog)

A parameterized, synthesizable UART transmitter implemented in Verilog HDL using a 4-state Finite State Machine (`IDLE`, `START`, `DATA`, `STOP`) and verified with a self-checking testbench in Icarus Verilog / EDA Playground.

## Key Features
- **Configurable Baud Rate:** Parameterized `CLKS_PER_BIT` to support arbitrary system clock and baud rate combinations.
- **Standard 8N1 Frame Format:** 1 active-low start bit, 8 data bits transmitted LSB-first, and 1 active-high stop bit.
- **Handshake Signals:** Includes `tx_start`, `busy`, and single-cycle `tx_done` status flags.
- **Self-Checking Verification:** Testbench samples mid-bit across 15 randomized and edge-case byte frames (`0x00`, `0xFF`, `0x0D`, `0x8D`, etc.), verifying 15/15 frames with zero errors.
