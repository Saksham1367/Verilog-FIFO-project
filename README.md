# Parameterized Asynchronous FIFO

This repository contains a synthesizable asynchronous FIFO implemented in Verilog with separate write and read clock domains. The design is now structured more like reusable IP than a fixed 8x8 classroom example: it is parameterized, exposes integration-friendly status signals, and includes a broader self-checking testbench.

## Features

- Parameterized `DATA_WIDTH` and `ADDR_WIDTH`
- Power-of-two FIFO depth: `DEPTH = 2**ADDR_WIDTH`
- Gray-coded read and write pointers for clock-domain crossing
- Two-flop synchronizers on the crossed Gray pointers
- Active-high resets with asynchronous assertion and internally synchronized release
- Handshake/status outputs for integration and debug:
  - `wr_ack`, `overflow`, `full`, `almost_full`, `wr_count`
  - `rd_valid`, `underflow`, `empty`, `almost_empty`, `rd_count`
- Self-checking verification covering directed and randomized asynchronous traffic

## Repository Contents

- `fifo.v` - synthesizable asynchronous FIFO RTL
- `tb_fifo.v` - self-checking verification testbench
- `README.md` - design and usage notes

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `DATA_WIDTH` | `8` | Width of each FIFO word |
| `ADDR_WIDTH` | `3` | Address width; FIFO depth is `2**ADDR_WIDTH` |
| `ALMOST_FULL_MARGIN` | `1` | `almost_full` asserts when free space is less than or equal to this margin |
| `ALMOST_EMPTY_MARGIN` | `1` | `almost_empty` asserts when occupancy is less than or equal to this margin |

## Interface

### Write clock domain

| Signal | Dir | Width | Description |
| --- | --- | --- | --- |
| `wr_clk` | In | 1 | Write clock |
| `wr_rst` | In | 1 | Active-high write-domain reset |
| `wr_en` | In | 1 | Write request |
| `wr_data` | In | `DATA_WIDTH` | Write data |
| `wr_ptr` | Out | `ADDR_WIDTH` | Lower address bits of the write pointer, mainly for debug/visibility |
| `wr_count` | Out | `ADDR_WIDTH+1` | Local write-domain occupancy estimate |
| `wr_ack` | Out | 1 | One-cycle pulse when a write is accepted |
| `overflow` | Out | 1 | One-cycle pulse when a write is attempted while full |
| `full` | Out | 1 | FIFO full indication in the write domain |
| `almost_full` | Out | 1 | Early warning flag based on `ALMOST_FULL_MARGIN` |

### Read clock domain

| Signal | Dir | Width | Description |
| --- | --- | --- | --- |
| `rd_clk` | In | 1 | Read clock |
| `rd_rst` | In | 1 | Active-high read-domain reset |
| `rd_en` | In | 1 | Read request |
| `rd_data` | Out | `DATA_WIDTH` | Read data |
| `rd_ptr` | Out | `ADDR_WIDTH` | Lower address bits of the read pointer, mainly for debug/visibility |
| `rd_count` | Out | `ADDR_WIDTH+1` | Local read-domain occupancy estimate |
| `rd_valid` | Out | 1 | One-cycle pulse when a read is accepted and `rd_data` is updated |
| `underflow` | Out | 1 | One-cycle pulse when a read is attempted while empty |
| `empty` | Out | 1 | FIFO empty indication in the read domain |
| `almost_empty` | Out | 1 | Early warning flag based on `ALMOST_EMPTY_MARGIN` |

## Functional Behavior

- A write is accepted on a `wr_clk` rising edge when `wr_en=1` and `full=0`.
- `wr_ack` pulses for one `wr_clk` cycle for each accepted write.
- `overflow` pulses for one `wr_clk` cycle when `wr_en=1` and the FIFO is full.
- A read is accepted on an `rd_clk` rising edge when `rd_en=1` and `empty=0`.
- `rd_valid` pulses for one `rd_clk` cycle for each accepted read.
- `rd_data` is updated on the same `rd_clk` edge that accepts the read.
- `underflow` pulses for one `rd_clk` cycle when `rd_en=1` and the FIFO is empty.

## CDC and Reset Notes

- Read and write pointers are maintained in binary locally and converted to Gray code before crossing clock domains.
- Each crossed Gray pointer passes through a two-flop synchronizer.
- The synchronizer registers are tagged with `ASYNC_REG` attributes for implementation flows that honor them.
- `wr_rst` and `rd_rst` are active high, asynchronously asserted, and internally released synchronously to their respective clocks.
- For full FIFO reinitialization, assert both resets together. Independent reset sequencing while data is in flight is not treated as a supported recovery mode for this IP instance.

## Counter and Flag Notes

- `wr_count` and `rd_count` are domain-local occupancy views computed using synchronized opposite-domain pointers.
- Because the opposite pointer must cross a synchronizer, these counts can lag real occupancy by synchronization latency.
- `full` and `empty` are safe control flags for gating transfers.
- `almost_full` and `almost_empty` are intended as early-warning flow-control indicators, not exact global occupancy guarantees.

## Verification Scope

The updated testbench is self-checking and covers:

1. Reset initialization
2. Full-depth fill and pointer wrap
3. Overflow protection
4. Full-depth drain and pointer wrap
5. Underflow protection
6. Reset recovery while data is present
7. Randomized asynchronous read/write traffic with a scoreboard

The testbench instantiates the FIFO with non-default parameters (`DATA_WIDTH=16`, `ADDR_WIDTH=4`) so parameterization is exercised, not just declared.

## Simulation

Example with Icarus Verilog:

```bash
iverilog -o fifo_tb fifo.v tb_fifo.v
vvp fifo_tb
```

Optional waveform viewing:

```bash
gtkwave fifo.vcd
```

## Implementation Notes

- FIFO depth must be a power of two because it is derived from `ADDR_WIDTH`.
- The RTL uses a simple dual-port style memory array. Exact RAM inference behavior depends on the target synthesis tool and technology library.
- If your implementation flow requires dedicated CDC constraints or vendor-specific pragmas beyond `ASYNC_REG`, add them in the project constraints rather than only in RTL comments.

## Suggested Next Steps

- Add linting and CDC checks in your preferred FPGA/ASIC flow
- Add CI that compiles and runs the testbench automatically
- Add formal properties for no-overflow/no-underflow and FIFO ordering guarantees
