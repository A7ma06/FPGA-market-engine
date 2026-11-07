<div align="center">

# FPGA MARKET ENGINE
### From market messages to best bid & offer — in SystemVerilog.

A hardware order-book engine running on the **Terasic DE0-Nano · Cyclone IV E**.  
Decode a **128-bit message**, update a **16-slot order store**, and publish the **best bid and offer** after a complete book scan.

![SystemVerilog](https://img.shields.io/badge/RTL-SystemVerilog-6366f1?style=for-the-badge)
![Cyclone IV E](https://img.shields.io/badge/FPGA-Cyclone_IV_E-0ea5e9?style=for-the-badge)
![50 MHz](https://img.shields.io/badge/Board_clock-50_MHz-14b8a6?style=for-the-badge)

**ADD · CANCEL · TRADE** &nbsp; | &nbsp; **SignalTap hardware capture** &nbsp; | &nbsp; **15 integration checks**

[Hardware evidence](#captured-on-silicon) · [Resource & timing results](#inside-the-fpga) · [Run the tests](#run-the-tests) · [Replay on hardware](#replay-on-hardware)

</div>

---

```text
  128-bit message          Order-book update           Quote publication
 ┌────────────────┐     ┌─────────────────────┐      ┌──────────────────┐
 │ Message parser │───▶│ ADD / CANCEL / TRADE│───▶  │ 16-slot BBO scan │
 └────────────────┘     │ 16-slot order store │      └────────┬─────────┘
                        └─────────────────────┘               ▼
                                                    Best bid + best ask
                                                    with validity flags
```

The top-level valid/ready handshake accepts one command at a time. The order manager searches by order ID, applies the update, then shares the store's read port with the BBO scanner. Both quote prices and their valid flags are published together when the scan completes.

| Build footprint | Timing at 50 MHz | Verification |
|:---|:---|:---|
| **3,338 / 22,320 LEs (15%)** | **+5.352 ns setup slack** | **Six-message board replay** |
| **2,668 registers · 19,456 memory bits** | **+0.107 ns hold slack** | **15 integration checks** |

Resource and timing figures are the existing reported results for the **full board demo with SignalTap enabled**, not an isolated engine benchmark. See [the detailed results and timing-corner context below](#inside-the-fpga). The 50 MHz board clock is not a claim of one message per cycle; message throughput and end-to-end latency are not reported here.

## Captured on silicon

A sell order for 30 hits the book at 110. A trade takes 10. The ask stays at 110. The next trade takes the remaining 20, and the ask disappears. The SignalTap trace below captures the FPGA writing each change into the book.

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
