# supr-meow-vela v0.1.9

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

See the [benchmark sheet](https://github.com/ocminer/supr-meow-vela/blob/v0.1.9/docs/benchmarks-2026-10-27.md) and
[CSV spreadsheet](https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.9/supr-meow-vela-0.1.9-benchmarks.csv) for measurement conditions,
clocks and configuration. Power is measured GPU draw. Efficiency is inf/J.

## Validation

The qualified Linux binary passed consensus-vector and attention checks on
all five measured GPU types. Full inference outputs matched the published
reference byte for byte across multiple seeds, prompts and batch sizes, in
CUDA Graph and eager execution. Live mining passed on single-card and two-card
instances. A lower-target CUDA build also passed correctness checks on an
RTX 3070. The release preserves the measured GPU code. Native Windows CI validates
CPU arithmetic, networking, model download fallback and packaged startup;
the hosted runner has no NVIDIA GPU, so Windows GPU mining is not hardware-tested.

## Downloads and compatibility

- `supr-meow-vela-0.1.9.tar.gz`: Linux x86-64 with HiveOS, MMPOS and SMOS launchers.
- `supr-meow-vela-hiveos.tar.gz`: HiveOS custom-miner package.
- `supr-meow-vela-0.1.9-windows-x86_64.zip`: native Windows x64.
- `supr-meow-vela-0.1.9-benchmarks.csv`: GPU benchmark spreadsheet.
- Docker: `ocminersupr/supr-meow-vela:0.1.9` and `:latest`.

Archives contain the benchmark Markdown/CSV, applicable licenses and an inner
file manifest. Download checksums are supplied separately. All six CUDA targets
(SM 80, 86, 89, 90, 100 and 120) are included, using CUDA 13.3.

Linux supports Ubuntu 20.04 and newer, including current HiveOS, MMPOS and SMOS
images; OpenSSL and the C++ runtime are linked in. A CUDA 13-capable NVIDIA driver
(R580+) is required. Windows uses plain TCP; Linux/Docker also support TLS.
The Windows README now identifies the correct version. Packages include notices
for the static Linux OpenSSL and GCC runtime libraries as well as the CUDA runtime.

Model download order remains Vela, Suprnova mirror, then Hugging Face, with
SHA-256 verification and cache reuse. The existing `sd-turbo-int.poisd` model
is unchanged; there is no need to download it again.

## License

The Suprnova Vela Source-Available License 1.0 is unchanged. Running the
unmodified miner, including for profit, is permitted. Incorporation into
commercial or closed-source miners requires the owner's prior written
permission. See LICENSE and NOTICE. Releases through v0.1.4 retain their
original MIT terms; third-party components retain their own licenses.
