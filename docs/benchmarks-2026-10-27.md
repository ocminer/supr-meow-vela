# Vela development benchmarks — 2026-10-27

Status: **unreleased optimized build after v0.1.8**. [Spreadsheet CSV](benchmarks-2026-10-27.csv).

| GPU | Sample | Architecture | Power cap (W) | GPU draw (W) | inf/s | inf/J |
|---|---|---|---:|---:|---:|---:|
| GeForce RTX 3070 | single card | Ampere (SM 86) | 220 | 219.4 | 28.47 | 0.1297 |
| GeForce RTX 3070 | two-card instance A | Ampere (SM 86) | 240 | 239.3 | 28.85 | 0.1205 |
| GeForce RTX 3070 | two-card instance B | Ampere (SM 86) | 240 | 239.3 | 29.04 | 0.1213 |
| GeForce RTX 4070 Ti SUPER | single card | Ada (SM 89) | 285 | 284.0 | 52.78 | 0.1858 |
| CMP 170HX | single card | Ampere (SM 80) | 200 | 198.5 | 36.09 | 0.1818 |
| GeForce RTX 5080 | single card | Blackwell (SM 120) | 360 | 360.0 | 83.03 | 0.2306 |
| GeForce RTX 5090 | single card | Blackwell (SM 120) | 450 | 450.0 | 117.89 | 0.2620 |

## Measurement method

Measurements taken on 2026-10-27 with the same optimized Linux development
binary, CUDA 13.3 runtime, the standard `sd-turbo-int.poisd` model, batch 4 and
2 lanes per GPU. Each run used four minutes of live pool mining. The first
minute and incomplete reporting intervals were excluded. Throughput is the
mean of 17–18 complete miner reporting intervals; GPU power is the mean of
telemetry samples from seconds 60–235. These are measured inference rates,
not estimates from share counts. All qualifying live runs had zero rejected
shares and passed the consensus-vector and attention checks.

Power is GPU telemetry, not whole-system consumption. Efficiency is mean
inf/s divided by mean watts: inf/J, equivalently (inf/s)/W. Power caps, clocks,
cooling, driver and GPU variation affect results. The CSV also records mean
SM/memory clocks and the number of cards in the miner instance.

The two RTX 3070 rows marked A and B were measured concurrently in **one
two-GPU miner instance**. Other rows used one selected GPU per instance.
Workspace was 2048 MiB per lane except the 220 W RTX 3070, which used automatic
workspace sizing. The CMP 170HX was measured at a 200 W cap for sustained
operation within the temperature limit. The RTX 5090 result is at a 450 W cap;
it is not directly comparable to earlier 600 W measurements.

Seven physical GPUs across five GPU types are represented. This table makes
no performance claim for unmeasured GPUs. This is a development-build
snapshot; a future release with different GPU code needs new measurements.

Benchmark binary SHA-256: `51838dff7bda5daa245cd820850c9cc7d15707bea1aa2ec586593799cdeafacc`.

## Matched improvement over v0.1.8

On the same RTX 3070 with a 220 W cap and batch 4 × 2 lanes, the published
v0.1.8 build measured **25.18 inf/s** and the final optimized build measured
**28.47 inf/s**, a **13.1% increase**. Mean GPU draw was 218.8 W and
219.4 W respectively. Both four-minute live runs had zero rejected shares.
This gain is a matched measurement on that card, not a fleet-wide percentage.
