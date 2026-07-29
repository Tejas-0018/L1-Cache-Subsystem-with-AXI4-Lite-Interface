# L1-Cache-Subsystem-with-AXI4-Lite-Interface

## 📌 Overview
This repository contains the RTL design and verification environment for a **2-Way Set-Associative L1 Cache**, built entirely from scratch in **Verilog**. The architecture features a custom multi-state cache controller acting as an **AXI4-Lite Master** to negotiate robust, standard-compliant memory transfers with a backend Main Memory array.

The project demonstrates advanced digital logic design principles, including **Write-Back eviction policies**, **Autonomous LRU (Least Recently Used) tracking**, and **Constrained Random Verification (CRV)**.

## ⚙️ Architecture & Specifications
*   **Associativity:** 2-Way Set-Associative
*   **Addressing:** 12-bit CPU Address Space (4KB Main Memory)
*   **Bus Interface:** ARM AXI4-Lite Standard (AW, W, B, AR, R channels)
*   **Write Policy:** Write-Back (with localized Dirty Bit tracking)
*   **Replacement Policy:** LRU (Least Recently Used)
*   **FSM Controller:** 6-State Moore Machine (`IDLE`, `COMPARE`, `WB_REQ`, `WB_WAIT`, `ALLOC_REQ`, `ALLOC_WAIT`)

## 📂 Module Breakdown
The hardware is designed with strict modularity, separating control logic from data routing:
1.  `cache_sram_2way`: The physical storage engine. Features single-cycle combinational tag comparison and autonomous metadata (Valid, Dirty, LRU) updates.
2.  `axi_main_memory`: A 4KB simulated backend RAM acting as the AXI4-Lite Slave device.
3.  `axi_cache_fsm`: The central brain. Orchestrates complex eviction and allocation sequences without touching the data payload.
4.  `axi_cache_datapath`: The routing network. Multiplexes bytes, splices words, and maps dirty SRAM outputs directly to the AXI write buses for zero-delay evictions.
5.  `top_level_cache_system`: The top wrapper containing integrated hardware performance counters.

## 📊 Verification & Performance
The system is verified using a procedural **Constrained Random Verification (CRV)** testbench compatible with Icarus Verilog. 

To model real-world CPU behavior, the randomizer injects 2,000 transactions with the following constraints:
*   **85% Spatial Locality** (Hot Zone targeting)
*   **70% Read / 30% Write Mix**

**Hardware Profiling Results:**
*   Total CPU Accesses: `2000`
*   Cache Misses: `645`
*   Write-Backs (Dirty Evictions): `305`
*   **Final Hit Rate:** `67.75%`

## 🛠️ How to Run on EDA Playground
This project is fully verified to run on [EDA Playground](https://www.edaplayground.com/) using the free Icarus Verilog simulator.
1. Paste the design modules into `design.sv`.
2. Paste the testbench into `testbench.sv`.
3. Set the simulator to **Icarus Verilog 0.10.0** (or newer).
4. Check **"Open EPWave after run"**.
5. Click **Run** to view the hardware profiling metrics in the console and observe the cycle-by-cycle AXI handshakes in the waveform viewer.

## ⏱️ Timing Operations
*   **Cache Hit:** 1 Clock Cycle
*   **Clean Miss (Allocation):** 4 Clock Cycles
*   **Dirty Miss (Eviction + Allocation):** 6 Clock Cycles
