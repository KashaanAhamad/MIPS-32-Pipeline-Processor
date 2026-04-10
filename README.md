# MIPS32 5-Stage Pipelined Processor

A fully functional **32-bit MIPS pipelined processor** implemented in Verilog HDL. The design features a classic **5-stage pipeline** architecture using a **two-phase clocking** scheme and includes three comprehensive testbenches that demonstrate arithmetic, memory, and branch operations.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Two-Phase Clocking Scheme](#two-phase-clocking-scheme)
- [Pipeline Stages](#pipeline-stages)
  - [Stage 1 — Instruction Fetch (IF)](#stage-1--instruction-fetch-if)
  - [Stage 2 — Instruction Decode (ID)](#stage-2--instruction-decode-id)
  - [Stage 3 — Execute (EX)](#stage-3--execute-ex)
  - [Stage 4 — Memory Access (MEM)](#stage-4--memory-access-mem)
  - [Stage 5 — Write-Back (WB)](#stage-5--write-back-wb)
- [Instruction Set Architecture (ISA)](#instruction-set-architecture-isa)
- [Pipeline Hazard Handling](#pipeline-hazard-handling)
- [Register & Memory Organization](#register--memory-organization)
- [Pipeline Registers](#pipeline-registers)
- [Testbenches](#testbenches)
  - [Test 1 — Arithmetic (Adding Three Numbers)](#test-1--arithmetic-adding-three-numbers)
  - [Test 2 — Load & Store Operations](#test-2--load--store-operations)
  - [Test 3 — Factorial with Branching Loop](#test-3--factorial-with-branching-loop)
- [How to Simulate](#how-to-simulate)
- [File Structure](#file-structure)
- [Waveform Analysis](#waveform-analysis)
- [Limitations & Future Work](#limitations--future-work)

---

## Overview

This project implements a **non-bypassed, in-order, 5-stage pipelined MIPS32 processor** in Verilog. It is designed as an educational model to illustrate core concepts of computer architecture:

- **Pipelining** — overlapping execution of multiple instructions for throughput improvement.
- **Two-phase clocking** — alternating clock edges drive odd and even pipeline stages to avoid read-after-write conflicts within a single cycle.
- **Branch handling** — delayed branch resolution with instruction squashing via the `TAKEN_BRANCH` flag.
- **Halt support** — graceful pipeline termination through the `HLT` instruction.

The processor operates on **word-addressable** memory (1024 × 32-bit) and a **32-entry register file** (R0 is hardwired to zero).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        MIPS32 5-Stage Pipeline Architecture                    │
│                                                                                │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│   │    IF     │───▶│    ID     │───▶│    EX     │───▶│   MEM    │───▶│    WB    │ │
│   │ (clk1 ↑) │    │ (clk2 ↑) │    │ (clk1 ↑) │    │ (clk2 ↑) │    │ (clk1 ↑) │ │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘ │
│        │                │                │                │               │     │
│   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐      ┌────▼────┐        │     │
│   │ IF/ID   │      │ ID/EX   │      │ EX/MEM  │      │ MEM/WB  │        │     │
│   │  Latch  │      │  Latch  │      │  Latch  │      │  Latch  │        │     │
│   └─────────┘      └─────────┘      └─────────┘      └─────────┘        │     │
│                                                                          │     │
│   ┌──────────────────────────────────────────────────┐                   │     │
│   │           Register File (32 × 32-bit)            │◀──────────────────┘     │
│   └──────────────────────────────────────────────────┘                         │
│   ┌──────────────────────────────────────────────────┐                         │
│   │           Memory (1024 × 32-bit words)           │                         │
│   └──────────────────────────────────────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Two-Phase Clocking Scheme

The processor uses a **non-overlapping two-phase clock** (`clk1` and `clk2`) to avoid structural hazards between pipeline stages that share resources:

```
clk1:  ▔▔▔▁▁▁▁▁▁▁▔▔▔▁▁▁▁▁▁▁▔▔▔▁▁▁▁▁▁▁
clk2:  ▁▁▁▁▁▁▔▔▔▁▁▁▁▁▁▔▔▔▁▁▁▁▁▁▔▔▔▁▁▁
```

| Clock Phase | Stages Active         |
|:-----------:|:----------------------|
| `clk1 ↑`   | **IF**, **EX**, **WB** |
| `clk2 ↑`   | **ID**, **MEM**        |

By splitting the stages across two non-overlapping phases, a register can be **written** in the WB stage (on `clk1`) and **read** in the ID stage (on `clk2`) within the same logical cycle, eliminating the need for forwarding logic.

---

## Pipeline Stages

### Stage 1 — Instruction Fetch (IF)

> **Triggered on:** `posedge clk1`

The IF stage fetches the next instruction from memory and prepares it for decoding.

**Operations performed:**
1. **Branch check** — If a branch taken condition is detected from the EX/MEM latch (`BEQZ` with `cond == 1` or `BNEQZ` with `cond == 0`), the PC is redirected to the branch target address (`EX_MEM_ALUOut`).
2. **Sequential fetch** — Otherwise, the instruction at address `PC` is fetched from `Mem[]`.
3. **NPC computation** — `PC + 1` is computed and stored as the Next Program Counter.
4. **Latch update** — The fetched instruction and NPC are written to the `IF/ID` pipeline register.

**Pipeline registers written:**
| Register     | Value                  |
|:-------------|:-----------------------|
| `IF_ID_IR`   | `Mem[PC]` or `Mem[branch_target]` |
| `IF_ID_NPC`  | `PC + 1` or `branch_target + 1`   |
| `PC`         | Updated program counter            |

---

### Stage 2 — Instruction Decode (ID)

> **Triggered on:** `posedge clk2`

The ID stage decodes the fetched instruction, reads source operands from the register file, and classifies the instruction type.

**Operations performed:**
1. **Register read** — Source registers `rs` (bits `[25:21]`) and `rt` (bits `[20:16]`) are read from the register file. If the register index is `0`, the value is hardwired to `0` (MIPS convention for R0).
2. **Immediate sign-extension** — The 16-bit immediate field (bits `[15:0]`) is sign-extended to 32 bits.
3. **Instruction classification** — The opcode (bits `[31:26]`) is decoded to determine the instruction type:

| Type      | Encoding | Instructions                          |
|:----------|:---------|:--------------------------------------|
| `RR_ALU`  | `3'b000` | ADD, SUB, AND, OR, SLT, MUL          |
| `RM_ALU`  | `3'b001` | ADDI, SUBI, SLTI                      |
| `LOAD`    | `3'b010` | LW                                    |
| `STORE`   | `3'b011` | SW                                    |
| `BRANCH`  | `3'b100` | BEQZ, BNEQZ                          |
| `HALT`    | `3'b101` | HLT (and invalid opcodes)            |

**Pipeline registers written:**
| Register     | Value                              |
|:-------------|:-----------------------------------|
| `ID_EX_A`    | Value of register `rs`             |
| `ID_EX_B`    | Value of register `rt`             |
| `ID_EX_Imm`  | Sign-extended 16-bit immediate     |
| `ID_EX_IR`   | Instruction (passed through)       |
| `ID_EX_NPC`  | Next PC (passed through)           |
| `ID_EX_type` | Decoded instruction type           |

---

### Stage 3 — Execute (EX)

> **Triggered on:** `posedge clk1`

The EX stage performs the ALU operation or computes the branch target address.

**Operations by instruction type:**

- **RR_ALU** — Executes the register-register ALU operation:
  - `ADD`: `A + B`
  - `SUB`: `A - B`
  - `AND`: `A & B`
  - `OR`:  `A | B`
  - `SLT`: `A < B`
  - `MUL`: `A * B`

- **RM_ALU** — Executes the register-immediate ALU operation:
  - `ADDI`: `A + Imm`
  - `SUBI`: `A - Imm`
  - `SLTI`: `A < Imm`

- **LOAD / STORE** — Computes the effective memory address: `A + Imm`. For STORE, also passes `B` (the data to store) through the pipeline.

- **BRANCH** — Computes the branch target: `NPC + Imm`, and evaluates the branch condition: `A == 0`.

**Pipeline registers written:**
| Register         | Value                                   |
|:-----------------|:----------------------------------------|
| `EX_MEM_ALUOut`  | ALU result or branch target address     |
| `EX_MEM_B`       | Store data (for STORE instructions)     |
| `EX_MEM_cond`    | Branch condition flag (`A == 0`)        |
| `EX_MEM_IR`      | Instruction (passed through)            |
| `EX_MEM_type`    | Instruction type (passed through)       |
| `TAKEN_BRANCH`   | Reset to `0` (set to `1` by IF on branch) |

---

### Stage 4 — Memory Access (MEM)

> **Triggered on:** `posedge clk2`

The MEM stage performs memory read/write operations or passes ALU results through.

**Operations by instruction type:**

- **RR_ALU / RM_ALU** — The ALU result is simply passed through to the MEM/WB latch (no memory access needed).
- **LOAD** — Data is read from memory: `Mem[EX_MEM_ALUOut]` and stored in `MEM_WB_LMD` (Load Memory Data).
- **STORE** — Data (`EX_MEM_B`) is written to memory at address `EX_MEM_ALUOut`, but **only if `TAKEN_BRANCH == 0`** (to prevent stores from squashed instructions).

**Pipeline registers written:**
| Register         | Value                              |
|:-----------------|:-----------------------------------|
| `MEM_WB_ALUOut`  | ALU result (for ALU instructions)  |
| `MEM_WB_LMD`    | Loaded data (for LOAD instructions)|
| `MEM_WB_IR`     | Instruction (passed through)       |
| `MEM_WB_type`   | Instruction type (passed through)  |

---

### Stage 5 — Write-Back (WB)

> **Triggered on:** `posedge clk1`

The WB stage writes computed results back to the register file. Writes are **disabled** when `TAKEN_BRANCH == 1` to squash instructions that entered the pipeline after a taken branch.

**Operations by instruction type:**

- **RR_ALU** — ALU result is written to the `rd` register (bits `[15:11]` of the instruction).
- **RM_ALU** — ALU result is written to the `rt` register (bits `[20:16]` of the instruction).
- **LOAD** — Loaded data (`MEM_WB_LMD`) is written to the `rt` register (bits `[20:16]`).
- **HALT** — The `HALTED` flag is set to `1`, stopping all pipeline activity.

---

## Instruction Set Architecture (ISA)

The processor supports 14 instructions across 6 instruction types:

### Instruction Encoding

```
R-Type:  [31:26 opcode] [25:21 rs] [20:16 rt] [15:11 rd] [10:0 unused]
I-Type:  [31:26 opcode] [25:21 rs] [20:16 rt] [15:0  immediate]
```

### Instruction Reference

| Mnemonic | Opcode (6-bit) | Type   | Operation                       | Description                          |
|:---------|:---------------|:-------|:--------------------------------|:-------------------------------------|
| `ADD`    | `000000`       | R-Type | `rd ← rs + rt`                 | Add two registers                    |
| `SUB`    | `000001`       | R-Type | `rd ← rs − rt`                 | Subtract two registers               |
| `AND`    | `000010`       | R-Type | `rd ← rs & rt`                 | Bitwise AND                          |
| `OR`     | `000011`       | R-Type | `rd ← rs \| rt`                | Bitwise OR                           |
| `SLT`    | `000100`       | R-Type | `rd ← (rs < rt) ? 1 : 0`      | Set on Less Than                     |
| `MUL`    | `000101`       | R-Type | `rd ← rs × rt`                 | Multiply two registers               |
| `ADDI`   | `001010`       | I-Type | `rt ← rs + imm`                | Add immediate                        |
| `SUBI`   | `001011`       | I-Type | `rt ← rs − imm`                | Subtract immediate                   |
| `SLTI`   | `001100`       | I-Type | `rt ← (rs < imm) ? 1 : 0`     | Set on Less Than Immediate           |
| `LW`     | `001000`       | I-Type | `rt ← Mem[rs + imm]`           | Load Word from memory                |
| `SW`     | `001001`       | I-Type | `Mem[rs + imm] ← rt`           | Store Word to memory                 |
| `BEQZ`   | `001110`       | I-Type | `if (rs == 0) PC ← NPC + imm`  | Branch if Equal to Zero              |
| `BNEQZ`  | `001101`       | I-Type | `if (rs ≠ 0) PC ← NPC + imm`  | Branch if Not Equal to Zero          |
| `HLT`    | `111111`       | —      | Halt execution                  | Stop the processor                   |

---

## Pipeline Hazard Handling

Since this is a **non-bypassed** pipeline (no data forwarding), hazards are managed manually:

### Data Hazards
- **No hardware forwarding** is implemented. Data hazards are resolved by inserting **NOP / dummy instructions** (typically `OR Rx,Rx,Rx`) between dependent instructions in the assembly program.
- The programmer/compiler is responsible for inserting sufficient dummy instructions to ensure data produced by one instruction is available in the register file before a subsequent instruction reads it.

### Control Hazards (Branches)
- Branches are resolved in the **IF stage** by checking the `EX_MEM` latch (i.e., the branch decision is available 2 cycles after the branch enters the pipeline).
- When a branch is taken:
  1. The `TAKEN_BRANCH` flag is set to `1`.
  2. Instructions fetched speculatively after the branch are **squashed** — their register writes and memory stores are suppressed.
  3. The PC is redirected to the branch target address.

### Structural Hazards
- Avoided by the **two-phase clocking scheme** — reads and writes to the register file happen on different clock phases.

---

## Register & Memory Organization

| Resource       | Size          | Details                                    |
|:---------------|:--------------|:-------------------------------------------|
| Register File  | 32 × 32-bit   | `Reg[0]` to `Reg[31]`; `R0` is hardwired to `0` |
| Memory         | 1024 × 32-bit  | `Mem[0]` to `Mem[1023]`; word-addressable   |

---

## Pipeline Registers

Four sets of pipeline registers (latches) pass data between stages:

| Latch     | Fields                                              |
|:----------|:----------------------------------------------------|
| `IF/ID`   | `IF_ID_IR`, `IF_ID_NPC`                             |
| `ID/EX`   | `ID_EX_IR`, `ID_EX_NPC`, `ID_EX_A`, `ID_EX_B`, `ID_EX_Imm`, `ID_EX_type` |
| `EX/MEM`  | `EX_MEM_IR`, `EX_MEM_ALUOut`, `EX_MEM_B`, `EX_MEM_cond`, `EX_MEM_type` |
| `MEM/WB`  | `MEM_WB_IR`, `MEM_WB_ALUOut`, `MEM_WB_LMD`, `MEM_WB_type` |

---

## Testbenches

### Test 1 — Arithmetic (Adding Three Numbers)

**File:** `test_mips32.v`

**Objective:** Load three constants (10, 20, 25) into registers R1–R3, add them together, and store the result in R5.

**Assembly Program:**
```asm
ADDI  R1, R0, 10      # R1 = 10
ADDI  R2, R0, 20      # R2 = 20
ADDI  R3, R0, 25      # R3 = 25
OR    R7, R7, R7      # dummy (NOP)
OR    R7, R7, R7      # dummy (NOP)
ADD   R4, R1, R2      # R4 = R1 + R2 = 30
OR    R7, R7, R7      # dummy (NOP)
ADD   R5, R4, R3      # R5 = R4 + R3 = 55
HLT                   # Halt
```

**Expected Output:**
```
R0 =  0,  R1 = 10,  R2 = 20,  R3 = 25,  R4 = 30,  R5 = 55
```

---

### Test 2 — Load & Store Operations

**File:** `test_2_mips32.v`

**Objective:** Load a word from memory location 120 (value = 85), add 45 to it, and store the result (130) in memory location 121.

**Assembly Program:**
```asm
ADDI  R1, R0, 120     # R1 = 120 (base address)
OR    R3, R3, R3      # dummy (NOP)
LW    R2, 0(R1)       # R2 = Mem[120] = 85
OR    R3, R3, R3      # dummy (NOP)
ADDI  R2, R2, 45      # R2 = 85 + 45 = 130
OR    R3, R3, R3      # dummy (NOP)
SW    R2, 1(R1)       # Mem[121] = 130
HLT                   # Halt
```

**Expected Output:**
```
Mem[120] =   85
Mem[121] =  130
```

---

### Test 3 — Factorial with Branching Loop

**File:** `test_3_mips32.v`

**Objective:** Compute the factorial of a number N (stored in `Mem[200]`, default = 7). The result is stored in `Mem[198]`.

**Assembly Program:**
```asm
ADDI   R10, R0, 200    # R10 = 200 (address of N)
ADDI   R2,  R0, 1      # R2 = 1 (accumulator)
OR     R20, R20, R20   # dummy (NOP)
LW     R3,  0(R10)     # R3 = Mem[200] = N
OR     R20, R20, R20   # dummy (NOP)
Loop:
  MUL  R2,  R2, R3     # R2 = R2 × R3
  SUBI R3,  R3, 1      # R3 = R3 − 1
  OR   R20, R20, R20   # dummy (NOP)
  BNEQZ R3, Loop       # if R3 ≠ 0, goto Loop
SW     R2, -2(R10)     # Mem[198] = R2 (factorial result)
HLT                    # Halt
```

**Expected Output (N = 7):**
```
Mem[200] =  7
Mem[198] = 5040       (7! = 5040)
```

---

## How to Simulate

### Using Icarus Verilog (Open Source)

```bash
# Compile the design + testbench
iverilog -o sim_out pipe_MIPS32.v test_mips32.v

# Run the simulation
vvp sim_out

# View waveforms (optional)
gtkwave mips.vcd
```

### Using Xilinx Vivado

1. Create a new project and add `pipe_MIPS32.v` as a design source.
2. Add the desired testbench (`test_mips32.v`, `test_2_mips32.v`, or `test_3_mips32.v`) as a simulation source.
3. Run **Behavioral Simulation** from the Flow Navigator.
4. Observe register and memory values in the TCL console or waveform viewer.

### Using ModelSim / Questa

```tcl
vlog pipe_MIPS32.v test_mips32.v
vsim test_mips32
run -all
```

---

## File Structure

```
MIPS32-Processor/
├── pipe_MIPS32.v        # Main processor design — 5-stage pipelined MIPS32
├── test_mips32.v        # Testbench 1: Adding three numbers (10 + 20 + 25)
├── test_2_mips32.v      # Testbench 2: Load-Store (load from mem, add, store)
├── test_3_mips32.v      # Testbench 3: Factorial computation with loop
├── Img/                 # Directory for waveform screenshots / diagrams
└── README.md            # This documentation file
```

---

## Waveform Analysis

When running simulations, VCD (Value Change Dump) files are generated:

| Testbench        | VCD File     | Key Signals to Observe                         |
|:-----------------|:-------------|:-----------------------------------------------|
| `test_mips32`    | `mips.vcd`   | `Reg[1]`–`Reg[5]`, `PC`, pipeline latches      |
| `test_2_mips32`  | `mips2.vcd`  | `Mem[120]`, `Mem[121]`, `Reg[1]`, `Reg[2]`     |
| `test_3_mips32`  | `mips3.vcd`  | `Reg[2]` (accumulator), `Reg[3]` (counter), `Mem[198]` |

To analyze the pipeline behavior, observe how instructions flow through the `IF_ID_IR` → `ID_EX_IR` → `EX_MEM_IR` → `MEM_WB_IR` registers on successive clock edges.

---

## Limitations & Future Work

### Current Limitations
- **No data forwarding / bypassing** — Dummy (NOP) instructions must be manually inserted to resolve data hazards.
- **No branch prediction** — Branches are resolved late (at the MEM stage feedback to IF), causing pipeline bubbles.
- **No exception/interrupt handling** — The processor does not support traps or interrupts.
- **No cache hierarchy** — Memory is modeled as an ideal single-cycle array.
- **Word-addressable only** — No byte or half-word memory access support.

### Future Enhancements
- [ ] Implement **data forwarding (bypassing)** to eliminate NOP instructions.
- [ ] Add a **branch predictor** (static or dynamic) to reduce branch penalty.
- [ ] Support **byte/half-word** load and store instructions.
- [ ] Add **exception handling** (overflow, invalid opcode, etc.).
- [ ] Implement a simple **instruction/data cache**.
- [ ] Extend the ISA with additional instructions (shift, jump-and-link, etc.).

---

## License

This project is open-source and available for educational purposes.

---

> **Note:** This processor is designed for educational and simulation purposes to demonstrate pipeline concepts in computer architecture. It is not intended for synthesis on real hardware without further modifications.
