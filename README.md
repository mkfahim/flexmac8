# FlexMAC8 — Silicluster V3 Digital Project

FlexMAC8 is a precision-adaptive, unsigned 8-bit multiply-accumulate (MAC) circuit with a 16-bit accumulator. The design uses synthesizable Verilog-2001 and is intended for the SKY130 digital implementation flow at a nominal 1.8 V supply.

## Submitted files

* `flexmac8.v` — synthesizable top-level RTL (`flexmac8`).
* `tb_flexmac8.v` — self-checking Verilog testbench (`tb_flexmac8`).

## Digital interface

|Signal|Direction|Width|Meaning|
|-|-|-:|-|
|`clk`|Input|1|External rising-edge clock, up to 10 MHz|
|`rst`|Input|1|Asynchronous active-high reset|
|`data_in`|Input|8|Operand data for LOAD commands|
|`cmd`|Input|2|Command selection|
|`precision`|Input|2|MAC precision selection|
|`start`|Input|1|Accept command on rising clock edge while not busy|
|`read_hi`|Input|1|Select high (`1`) or low (`0`) accumulator byte|
|`data_out`|Output|8|Selected accumulator byte|
|`busy`|Output|1|MAC operation in progress|
|`done`|Output|1|Completion indication for an accepted command|
|`overflow`|Output|1|Sticky 16-bit accumulator overflow flag|

The design uses **14 ordinary digital input bits and 11 ordinary digital output bits**, in addition to the dedicated `clk` and `rst` pins.

## Operation

Commands (`cmd`) are:

* `00`: load operand A from `data_in`.
* `01`: load operand B from `data_in`.
* `10`: compute and accumulate A multiplied by the effective B operand.
* `11`: clear operands, accumulator, and overflow flag.

For `cmd=10`, `precision` selects:

|Precision|Effective B operand|Processing clocks after acceptance|
|-|-|-:|
|`00`|Full 8-bit B|8|
|`01`|B with its lowest 2 bits cleared|6|
|`10`|B with its lowest 4 bits cleared|4|
|`11`|Full 8-bit B (fallback)|8|

The accumulator wraps modulo 2^16. Once overflow occurs, the `overflow` output remains asserted until a CLEAR command or reset. New `start` requests are ignored while `busy` is high. LOAD and CLEAR commands complete at the accepting clock edge; MAC completion is indicated after the selected processing cycles.

## Verification

The provided self-checking testbench uses a **100 ns clock period (10 MHz)** and checks exact/precision-reduced arithmetic, accumulation, byte readback, overflow, and reset behavior. A recorded Verilator run completed **467 arithmetic/readback checks with no mismatches**.

To reproduce the functional test with Icarus Verilog from this folder:

```sh
iverilog -g2005 -s tb_flexmac8 -o simv flexmac8.v tb_flexmac8.v
vvp simv
```

The design also completed a SKY130 (`sky130_fd_sc_hd`) LibreLane implementation in a 180 µm × 115 µm footprint, with 6,426.16 µm² placed standard-cell area and no setup/hold timing violations at the 100 ns target. DRC, LVS, and antenna checks passed.

The Verilog source and testbench are the deliverables required for a Silicluster V3 digital submission. Physical design outputs are not included but can be provided on request.

## Related work

FlexMAC8 relates to research on precision-scalable multiply-accumulate (MAC) architectures and bit-serial arithmetic:

1. V. Camus, C. Enz, and M. Verhelst, “Survey of Precision-Scalable Multiply-Accumulate Units for Neural-Network Processing,” *IEEE AICAS*, 2019. https://doi.org/10.1109/AICAS.2019.8771610
2. H. Zhang, D. Chen, and S.-B. Ko, “New Flexible Multiple-Precision Multiply-Accumulate Unit for Deep Neural Network Training and Inference,” *IEEE Transactions on Circuits and Systems I: Regular Papers*, 2019. https://ieeexplore.ieee.org/document/8825551
3. W. Li, A. Hu, G. Wang, N. Xu, and G. He, “Low-Complexity Precision-Scalable Multiply-Accumulate Unit Architectures for Deep Neural Network Accelerators,” *IEEE Transactions on Circuits and Systems II: Express Briefs*, 2023. https://ieeexplore.ieee.org/document/9997127
4. H. Chhajed, G. Raut, N. S. Dhakad, S. Vishwakarma, and S. K. Vishvakarma, “BitMAC: Bit-Serial Computation-Based Efficient Multiply-Accumulate Unit for DNN Accelerator,” *Circuits, Systems, and Signal Processing*, 2022. https://link.springer.com/article/10.1007/s00034-021-01873-9

These works provide the architectural context for precision-programmable and bit-efficient MAC units. FlexMAC8 is a smaller, command-controlled unsigned RTL design: it selects among exact or deterministically truncated B operands and performs multiplication with a serial shift-and-add datapath rather than a combinational or bit-brick PSMAC architecture.
