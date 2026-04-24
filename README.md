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
- `scripts/` - local automation for simulation, waveform export, and GTKWave launch
- `.github/workflows/verilog-ci.yml` - GitHub Actions simulation check
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

Local automation on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_flow.ps1
```

That command:

1. compiles `fifo.v` and `tb_fifo.v`
2. runs the self-checking simulation
3. generates waveform PNGs under `artifacts/waveforms/`
4. opens `fifo.vcd` in GTKWave with a curated FIFO trace list

If you only want individual steps:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_sim.ps1
python .\scripts\export_wave_plots.py --vcd .\fifo.vcd --outdir .\artifacts\waveforms
powershell -ExecutionPolicy Bypass -File .\scripts\open_wave.ps1
```

## Waveform Results

The following plots capture the FIFO behavior across the full 0 us to 3 us simulation window in 500 ns segments.

### 0 ns to 500 ns

![FIFO waveform from 0 ns to 500 ns](artifacts/Plot%200-500%20%28ns%29.png)

### 500 ns to 1000 ns

![FIFO waveform from 500 ns to 1000 ns](artifacts/plot%20500-1000%20%28ns%29.png)

### 1000 ns to 1500 ns

![FIFO waveform from 1000 ns to 1500 ns](artifacts/plot%201000-1500%20%28ns%29.png)

### 1500 ns to 2000 ns

![FIFO waveform from 1500 ns to 2000 ns](artifacts/plot%201500-2000%20%28ns%29.png)

### 2000 ns to 2500 ns

![FIFO waveform from 2000 ns to 2500 ns](artifacts/plot%202000-2500%28ns%29.png)

### 2500 ns to 3000 ns

![FIFO waveform from 2500 ns to 3000 ns](artifacts/plot%202500-3000%20%28ns%29.png)

## Implementation Notes

- FIFO depth must be a power of two because it is derived from `ADDR_WIDTH`.
- The RTL uses a simple dual-port style memory array. Exact RAM inference behavior depends on the target synthesis tool and technology library.
- If your implementation flow requires dedicated CDC constraints or vendor-specific pragmas beyond `ASYNC_REG`, add them in the project constraints rather than only in RTL comments.

## Suggested Next Steps

- Add linting and CDC checks in your preferred FPGA/ASIC flow
- Add formal properties for no-overflow/no-underflow and FIFO ordering guarantees
- Extend CI with lint, CDC, and synthesis jobs for your target device or process
