# Project Overview

This project implements a hardware accelerator for advanced signal processing or interpolation tasks, featuring a **Systolic Array**, **CORDIC** arithmetic, and **Cubic Convolution** kernels. The design is wrapped with **AXI4-Stream** interfaces, making it suitable for integration as an IP core in FPGA-based Systems-on-Chip (SoC) (e.g., Xilinx Zynq connecting to AXI DMA).

## Architecture

The system processes incoming data streams by performing the following operations:

1.  **Matrix-Vector Multiplication:** Uses a 3x4 Systolic Array (`SystolicArray.v` wrapped in `SRT.v`) to transform input vectors.
2.  **Normalization & Difference:** The transformed vectors are normalized and compared against reference values.
3.  **CORDIC Rotation:** A CORDIC engine (`CORDIC_Vector.v`) processes the difference vectors, likely to compute magnitudes or rotate vectors to a canonical basis.
4.  **Cubic Convolution:** The results are passed through a pipelined cubic convolution kernel (`cubic_cov_d1.v`), which implements polynomial evaluation (likely for interpolation weights or derivative calculation).

## Key Files

*   **`top.v`**: Top-level AXI-Stream wrapper. Handles clocking, reset, and interface signals for DMA communication.
*   **`process.v`**: The core logic controller. It manages the state machine (IDLE -> LOAD Matrix -> STREAM Data), instantiates the sub-modules (`SRT`, `CORDIC_Vector`, `cubic_cov_d1`), and orchestrates the data flow.
*   **`SystolicArray.v`**: Implements the 3x4 systolic array structure for efficient matrix processing.
*   **`PE.v`**: Processing Element for the systolic array (MAC unit).
*   **`CORDIC_Vector.v`**: Vector-mode CORDIC implementation for coordinate rotation/calculation.
*   **`cubic_cov_d1.v`**: Pipelined implementation of a cubic convolution function (using fixed-point arithmetic).
*   **`tb.v`**: Testbench for simulation.

## Building and Running

This project is a raw Verilog RTL design. There are no build scripts provided.

### Simulation
To simulate the design, you can use standard Verilog simulators `vcs`. The testbench `tb.v` is the entry point.

**Using vcs:**
```tcsh
source ../vcs.cmd
```

**Note:** The `tb.v` file contains `$fsdbDumpfile` calls which are specific to the Verdi/VCS environment.

## Data Formats
*   **Fixed Point:** The design heavily relies on Q16 fixed-point arithmetic (16 fractional bits).
*   **AXI-Stream:** Data is transferred via 64-bit AXI-Stream interfaces (`s00_axis_tdata`, `m00_axis_tdata`).
