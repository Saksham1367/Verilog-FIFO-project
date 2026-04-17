# 8x8 Asynchronous FIFO

This project implements an **8-entry, 8-bit asynchronous FIFO** in Verilog.
It supports separate write and read clock domains, so data can be written and
read safely even when the two clocks are unrelated.

## Files

- `fifo.v` - synthesizable FIFO module
- `tb_fifo.v` - self-checking testbench
- `README.md` - project documentation

## FIFO Overview

An asynchronous FIFO stores data in a small memory and uses separate pointers
for writing and reading.

### Key signals

| Signal | Description |
| --- | --- |
| `wr_clk` | Write clock |
| `wr_rst` | Write-domain reset, active high |
| `wr_en` | Write enable |
| `wr_data[7:0]` | Data written into the FIFO |
| `rd_clk` | Read clock |
| `rd_rst` | Read-domain reset, active high |
| `rd_en` | Read enable |
| `rd_data[7:0]` | Data read from the FIFO |
| `full` | FIFO is full |
| `empty` | FIFO is empty |

The module also exposes `wr_ptr` and `rd_ptr` as 3-bit debug pointers.

## Design Method

The FIFO uses:

- an 8-word memory array
- binary write and read pointers
- Gray-coded pointers for cross-domain synchronization
- two-flop synchronizers for safe clock-domain crossing

This is the standard safe way to build an asynchronous FIFO.

### Full/empty behavior

- `full` asserts when the next write would collide with the synchronized read pointer.
- `empty` asserts when the next read would collide with the synchronized write pointer.

## Reset Behavior

Both resets are active high.

- `wr_rst` resets the write pointer and write-side status logic
- `rd_rst` resets the read pointer and read-side status logic

## Testbench Behavior

The testbench:

1. applies reset
2. writes 8 bytes to fill the FIFO
3. checks that `full` asserts
4. tries one extra write and confirms it is blocked
5. reads back all stored values in order
6. verifies `empty`
7. performs a wrap-around/mixed read-write test
8. checks the final output sequence and final `empty` state

If everything is correct, the testbench prints:

`TEST PASSED: FIFO behaved correctly.`

## Simulation

Example with Icarus Verilog:

```bash
iverilog -o fifo_tb fifo.v tb_fifo.v
vvp fifo_tb
```

If you use another simulator, compile `fifo.v` and `tb_fifo.v` together and run
the top module `tb_fifo`.

## Simulation Results

The following waveform images show the FIFO behavior during simulation.

### 0 ns to 100 ns

![FIFO waveform from 0 ns to 100 ns](plot%20%280%20to%20100%20ns%29.png)

### 100 ns to 220 ns

![FIFO waveform from 100 ns to 220 ns](plot%20%28100%20to%20220%20ns%29.png)

### 0 ns to 300 ns

![FIFO waveform from 0 ns to 300 ns](plot%20till%20300ns.png)

## Notes

- The FIFO depth is 8 because the address width is 3 bits.
- The data width is 8 bits.
- The module is written to be easy to simulate and explain for a project report.
