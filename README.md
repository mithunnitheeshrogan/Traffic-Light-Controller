# Traffic Light Controller (Verilog)

A two-road traffic light controller (main road + side road with a vehicle sensor), implemented as a Moore FSM in Verilog and verified with a self-checking testbench in ModelSim.

## Overview

- The main road is green by default.
- The side road only gets a green when a vehicle is detected on it (`car_side = 1`) and the main road has finished its minimum green time.
- The side green ends early if the vehicle leaves, otherwise it ends when its maximum time expires.
- Green and yellow durations are parameterized (in clock cycles).

## Repository Structure

```
.
├── traffic_light_controller.v      # RTL design
├── tb_traffic_light_controller.v   # Self-checking testbench
├── docs/                           # Waveform and transcript screenshots
└── README.md
```

## Design

### Ports

| Port | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Active-low synchronous reset |
| `car_side` | in | 1 | Vehicle sensor on the side road |
| `main_light` | out | 3 | Main road light, `{R,Y,G}` |
| `side_light` | out | 3 | Side road light, `{R,Y,G}` |

### Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `T_MAIN_GREEN` | 10 | Minimum main-road green time (cycles) |
| `T_YELLOW` | 3 | Yellow time for both roads (cycles) |
| `T_SIDE_GREEN` | 6 | Maximum side-road green time (cycles) |

### Light encoding

| Value | Meaning |
|---|---|
| `3'b100` | RED |
| `3'b010` | YELLOW |
| `3'b001` | GREEN |

### FSM states

| State | Encoding | Main | Side | Moves to next state when |
|---|---|---|---|---|
| `S_MAIN_G` | `2'b00` | Green | Red | `timer >= T_MAIN_GREEN-1` **and** `car_side = 1` |
| `S_MAIN_Y` | `2'b01` | Yellow | Red | `timer >= T_YELLOW-1` |
| `S_SIDE_G` | `2'b10` | Red | Green | `timer >= T_SIDE_GREEN-1` **or** `car_side = 0` |
| `S_SIDE_Y` | `2'b11` | Red | Yellow | `timer >= T_YELLOW-1` |

Sequence: `S_MAIN_G → S_MAIN_Y → S_SIDE_G → S_SIDE_Y → S_MAIN_G`

### Implementation notes

- Moore machine: outputs depend only on the current state.
- Three-block coding style: state register, next-state logic (combinational), output logic (combinational).
- A single `timer` counter counts cycles spent in the current state and is cleared whenever the state changes, so each state lasts exactly the configured number of cycles.
- Time is measured in clock cycles to keep simulation short. For a real board clock, add a clock divider or increase the parameters.

## Verification

The testbench (`tb_traffic_light_controller.v`) is self-checking and prints `TEST PASSED` or `TEST FAILED` with an error count.

**Checkers running throughout the simulation**
- Safety: both roads are never non-red at the same time.
- Timing: the main-road yellow lasts exactly `T_YELLOW` cycles.

**Directed tests**
- Reset: main green / side red after reset.
- No side car: main stays green.
- Side car present: full cycle repeats.
- Early exit: `car_side` drops during side green, so side green ends before `T_SIDE_GREEN`.
- Reset applied while the FSM is in the side-green state.

Verification is functional simulation only (ModelSim). The design has not been synthesized or timing-analyzed.

## How to Run (ModelSim)

```tcl
vlib work
vlog traffic_light_controller.v tb_traffic_light_controller.v
vsim -voptargs=+acc work.tb_traffic_light_controller
add wave -radix binary sim:/tb_traffic_light_controller/*
add wave -radix unsigned sim:/tb_traffic_light_controller/dut/timer
add wave sim:/tb_traffic_light_controller/dut/state
run -all
```

On older ModelSim versions, use `vsim -novopt work.tb_traffic_light_controller` instead.

Expected console output ends with:

```
*** TEST PASSED: no errors ***
```

## Results

Add your screenshots to `docs/` and reference them here:

```
![Waveform](docs/waveform.png)
![Transcript](docs/transcript.png)
```

## Possible Extensions

- Pedestrian crossing request input
- 4-way intersection (N/S and E/W)
- Emergency vehicle override
- Clock divider for a real board clock

## Tools

- Verilog (Verilog-2001)
- ModelSim

## Author

Mithun
