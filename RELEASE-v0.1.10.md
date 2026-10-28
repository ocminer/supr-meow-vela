# supr-meow-vela v0.1.10

This release fixes HiveOS installation, model storage and dashboard statistics.
Both Linux archives now unpack into the `supr-meow-vela/` directory expected by
Hive's custom-miner installer. Use the versioned installation URL below so an
upgrade cannot silently reuse an older cached archive.

- Correct Hive's sourced stats callback, rate units, uptime and GPU mapping.
- Report per-GPU rates, temperatures, fans and share counts from an atomic local snapshot; stale or stopped miners report zero. No monitoring port is required.
- Keep complete status lines on larger rigs, including eight-card systems.
- Cache new models under `/hive/models/supr-meow-vela`, outside Hive's configuration partition. Existing verified models are reused; low disk space is reported clearly.
- Handle flight-sheet values, TLS URLs and miner exit codes correctly.

## HiveOS setup

Custom miner name: **`supr-meow-vela`**

Installation URL:
`https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.10/supr-meow-vela-0.1.10.tar.gz`

Use `%WAL%.%WORKER_NAME%`, pool `vela.suprnova.cc:7601`, password `x`, and leave
extra config empty for the defaults. Optional settings are shell assignments,
for example `BATCH=4` on its own line. See the [complete setup and upgrade guide](https://github.com/ocminer/supr-meow-vela/blob/v0.1.10/docs/hiveos.md).

## Performance

The CUDA kernels are unchanged from v0.1.9. These are the previous measured
results from 2026-10-27, retained for reference; this maintenance release makes
no additional performance claim. The matched RTX 3070 improvement introduced
in v0.1.9 was **25.18 → 28.47 inf/s (+13.1%)** over v0.1.8 at a 220 W cap.

| GPU | Architecture | GPU draw (W) | inf/s | inf/J |
|---|---|---:|---:|---:|
| RTX 3070, single card | Ampere SM 86 | 219.4 | 28.47 | 0.1297 |
| RTX 3070, two-card instance A | Ampere SM 86 | 239.3 | 28.85 | 0.1205 |
| RTX 3070, two-card instance B | Ampere SM 86 | 239.3 | 29.04 | 0.1213 |
| RTX 4070 Ti SUPER | Ada SM 89 | 284.0 | 52.78 | 0.1858 |
| CMP 170HX | Ampere SM 80 | 198.5 | 36.09 | 0.1818 |
| RTX 5080 | Blackwell SM 120 | 360.0 | 83.03 | 0.2306 |
| RTX 5090 | Blackwell SM 120 | 450.0 | 117.89 | 0.2620 |

[Benchmark method and settings](https://github.com/ocminer/supr-meow-vela/blob/v0.1.10/docs/benchmarks-2026-10-27.md) ·
[Download CSV](https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.10/supr-meow-vela-0.1.10-benchmarks.csv).
Power is measured GPU power, not whole-system draw; clocks, caps and cooling affect results.

## Packages and compatibility

- `supr-meow-vela-0.1.10.tar.gz`: Linux, HiveOS, MMPOS and SMOS. Recommended HiveOS installation URL.
- `supr-meow-vela-hiveos.tar.gz`: identical legacy HiveOS download alias.
- `supr-meow-vela-0.1.10-windows-x86_64.zip`: native Windows x64.
- Docker: `ocminersupr/supr-meow-vela:0.1.10` and `:latest`.

Portable Linux binaries support Ubuntu 20.04 through current releases with
static OpenSSL and C++ runtime. CUDA 13 requires an R580-or-newer NVIDIA driver.
The model downloads from Vela, with Suprnova and Hugging Face fallbacks and
SHA-256 verification. Checksums, benchmark data and third-party notices are
included. The Suprnova Vela Source-Available License 1.0 is unchanged; prior
published MIT grants through v0.1.4 remain unaffected.
Commercial or closed-source incorporation requires prior written permission
from the owner; normal mining, including for profit, remains allowed.

Validation covers the official Hive installer and callback contract in an
isolated test filesystem, launcher/download regressions, atomic stats tests,
portable Linux compatibility and native Windows build/startup. A live HiveOS
web dashboard and Windows GPU hardware were not available for testing.
