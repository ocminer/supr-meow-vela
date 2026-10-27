# Next release — unreleased

RTX 3070 throughput improved from **25.18 to 28.47 inf/s (+13.1%)** in matched
live mining at a 220 W power cap, with zero rejected shares. Two RTX 3070s in
one miner instance measured **28.85 and 29.04 inf/s per card** at 240 W caps.

## GPU benchmarks

| GPU | Sample | Architecture | Power cap (W) | GPU draw (W) | inf/s | inf/J |
|---|---|---|---:|---:|---:|---:|
| GeForce RTX 3070 | single card | Ampere (SM 86) | 220 | 219.4 | 28.47 | 0.1297 |
| GeForce RTX 3070 | two-card instance A | Ampere (SM 86) | 240 | 239.3 | 28.85 | 0.1205 |
| GeForce RTX 3070 | two-card instance B | Ampere (SM 86) | 240 | 239.3 | 29.04 | 0.1213 |
| GeForce RTX 4070 Ti SUPER | single card | Ada (SM 89) | 285 | 284.0 | 52.78 | 0.1858 |
| CMP 170HX | single card | Ampere (SM 80) | 200 | 198.5 | 36.09 | 0.1818 |
| GeForce RTX 5080 | single card | Blackwell (SM 120) | 360 | 360.0 | 83.03 | 0.2306 |
| GeForce RTX 5090 | single card | Blackwell (SM 120) | 450 | 450.0 | 117.89 | 0.2620 |

See the [benchmark sheet](docs/benchmarks-2026-10-27.md) and
[CSV spreadsheet](docs/benchmarks-2026-10-27.csv) for measurement conditions,
clocks and configuration. Power is measured GPU draw. Efficiency is inf/J.

## Validation

The Linux development binary passed consensus-vector and attention checks on
all five measured GPU types. Full inference outputs matched the published
reference byte for byte across multiple seeds, prompts and batch sizes, in
CUDA Graph and eager execution. Live mining passed on single-card and two-card
instances. A lower-target CUDA build also passed correctness checks on an
RTX 3070. These measurements qualify the identified Linux binary; Windows
builds and final release packages have not been produced for this update yet.

## License

The Suprnova Vela Source-Available License 1.0 is unchanged. Running the
unmodified miner, including for profit, is permitted. Incorporation into
commercial or closed-source miners requires the owner's prior written
permission. See LICENSE and NOTICE. Releases through v0.1.4 retain their
original MIT terms; third-party components retain their own licenses.
