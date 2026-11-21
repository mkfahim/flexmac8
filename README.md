# FlexMAC8 — Silicluster V3 Digital Project

FlexMAC8 is a precision-adaptive, unsigned 8-bit multiply-accumulate (MAC) circuit with a 16-bit accumulator. The design uses synthesizable Verilog-2001 and is intended for the SKY130 digital implementation flow at a nominal 1.8 V supply (V<sub>DD</sub> = 1.8 V).

## Submitted files

| File | Description |
|:-----|:------------|
| [`flexmac8.v`](./flexmac8.v) | Synthesizable top-level RTL (`flexmac8`). |
| [`tb_flexmac8.v`](./tb_flexmac8.v) | Self-checking Verilog testbench (`tb_flexmac8`). |

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

> [!TIP]
> Run the following commands from the repository root to reproduce the functional test.

```sh
iverilog -g2005 -s tb_flexmac8 -o simv flexmac8.v tb_flexmac8.v
vvp simv
```

Press <kbd>Ctrl</kbd>+<kbd>C</kbd> to abort a running simulation.

### SKY130 Implementation

The design was implemented using LibreLane with the SKY130 `sky130_fd_sc_hd` standard-cell library.

| Implementation parameter | Result |
|---|---:|
| Silicluster given die area | 180 µm × 115 µm |
| Placed standard-cell area | 6,426.16 µm² |
| Clock target | 100 ns |
| Timing violations | None |
| DRC | Passed |
| LVS | Passed |
| Antenna check | Passed |

> The Verilog source and testbench are the deliverables required for a Silicluster V3 digital submission. Physical-design outputs are not included in this repository but can be provided separately.

## Related work

FlexMAC8 relates to research on precision-scalable multiply-accumulate (MAC) architectures and bit-serial arithmetic. These works provide the architectural context for precision-programmable and bit-efficient MAC units.

<details>
<summary>Show references (2)</summary>
  
<a id="ref-1"></a>[1] H. Zhang, D. Chen, and S.-B. Ko, “New Flexible Multiple-Precision Multiply-Accumulate Unit for Deep Neural Network Training and Inference,” *IEEE Transactions on Computers*, vol. 69, no. 1, pp. 26–38, Jan. 2020. https://doi.org/10.1109/TC.2019.2936192

<a id="ref-2"></a>[2] H. Chhajed, G. Raut, N. Dhakad, S. Vishwakarma, and S. K. Vishvakarma, “BitMAC: Bit-Serial Computation-Based Efficient Multiply-Accumulate Unit for DNN Accelerator,” *Circuits, Systems, and Signal Processing*, vol. 41, pp. 2045–2060, 2022. https://doi.org/10.1007/s00034-021-01873-9
</details>

