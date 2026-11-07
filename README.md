# FPGA Market Engine

A sell order for 30 hits the book at 110. A trade takes 10. The ask stays at 110. The next trade takes the remaining 20, and the ask disappears. This SystemVerilog engine runs that sequence on a **Terasic DE0-Nano**. The SignalTap trace below catches the FPGA writing each change into the book.

![Six order-store writes captured on the DE0-Nano](docs/signaltap-order-writes.png)

Read the buses at each rising clock edge where `write_enable` is high. From left to right, the engine adds three orders, cancels the second buy, then writes slot 2 twice. The partial trade keeps the slot valid with 20 units remaining. The final trade clears its valid bit.

## Inside the FPGA

The engine accepts one **128-bit message** on a valid/ready handshake. The order manager searches a **16-slot book** by order ID and applies the update. It then hands the same read port to the best-bid-and-offer scanner, which checks all 16 slots before publishing both prices and their valid flags together. A new command waits until the engine is ready again.

| Hardware result | Measured value |
|---|---:|
| Board clock | 50 MHz (20 ns period) |
| Logic elements | 3,338 / 22,320 (15%) |
| Dedicated logic registers | 2,668 |
| Embedded memory | 19,456 / 608,256 bits |
| Worst reported setup slack on `CLOCK_50` | +5.352 ns |
| Worst reported hold slack on `CLOCK_50` | +0.107 ns |

Figures come from the Quartus Prime Lite 25.1 Fitter and Timing Analyzer summaries for the **full board demo with SignalTap enabled**, targeting the Cyclone IV E EP4CE22F17C6. Setup and hold minima are taken separately across the reported timing corners.

## Six messages on hardware

| Replay step | Best bid | Best ask |
|---|---:|---:|
| Add buy at 100, quantity 50 | 100 | — |
| Add buy at 105, quantity 20 | 105 | — |
| Add sell at 110, quantity 30 | 105 | 110 |
| Cancel the buy at 105 | 100 | 110 |
| Trade 10 against the sell | 100 | 110 |
| Trade the final 20 against the sell | 100 | — |

The board controller checks each result. The integration testbench adds **15 passing checks**, including a full book, reuse of slot 15, an oversized trade, backpressure and reset during a pending transaction.

## Run the tests

Install Icarus Verilog and put iverilog and vvp on PATH. From PowerShell in the repository root, run:

```powershell
.\run_tests.ps1
```

The integration test covers price selection, cancellations, trades, capacity, last-slot reuse, rejected commands, backpressure and reset recovery.

## Replay on hardware

Open quartus/market_demo.qpf in Quartus Prime Lite with Cyclone IV support. Start a full compilation and use the Programmer with USB-Blaster to load output_files/market_board_top.sof. Press and release KEY[0] to replay. LED0 is the heartbeat, LED1 indicates pass, LED2 indicates failure and LED3 indicates the demo is busy.

To capture the writes, open quartus/market_capture.stp. Hold KEY[0], run SignalTap acquisition, then release the button when waiting for the trigger.
