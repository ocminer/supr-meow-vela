# supr-meow-vela v0.1.11

HiveOS packaging update using the existing **v0.1.10 binaries**. The native
miner still reports 0.1.10; Hive reports package **0.1.11**.

- The launcher omits `--no-progress-meter` and uses curl options compatible with curl 7.58. No curl upgrade is required for this fix.
- Print the installed package version at startup and report it in Hive's stats, including while the model downloads or loads.
- Preserve the existing model cache, download mirrors and checksum verification.

## HiveOS installation

Set the custom miner name to **`supr-meow-vela`** and update the flight sheet's
installation URL to:

`https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.11/supr-meow-vela-0.1.11.tar.gz`

Change **both version numbers** in the URL and save the flight sheet before
force-reinstalling from the Hive shell:

```bash
miner stop
/hive/miners/custom/custom-get https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.11/supr-meow-vela-0.1.11.tar.gz -f
miner start
```

Confirm the first launcher line says `[supr-meow-vela] HiveOS package 0.1.11`.
Use `%WAL%.%WORKER_NAME%`, pool `vela.suprnova.cc:7601`, password `x`, and leave
extra config empty for the defaults. See the [complete setup guide](https://github.com/ocminer/supr-meow-vela/blob/v0.1.11/docs/hiveos.md).

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

[Benchmark method and settings](https://github.com/ocminer/supr-meow-vela/blob/v0.1.11/docs/benchmarks-2026-10-27.md) ·
[Download CSV](https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.11/supr-meow-vela-0.1.11-benchmarks.csv).
Power is measured GPU power, not whole-system draw; clocks, caps and cooling affect results.

## Packages and compatibility

- `supr-meow-vela-0.1.11.tar.gz`: Linux, HiveOS, MMPOS and SMOS. Recommended HiveOS installation URL.
- `supr-meow-vela-hiveos.tar.gz`: identical legacy HiveOS download alias.
- `supr-meow-vela-0.1.11-windows-x86_64.zip`: native Windows x64.
- Docker: `ocminersupr/supr-meow-vela:0.1.11` and `:latest`.

Portable Linux binaries support Ubuntu 20.04 through current releases with
static OpenSSL and C++ runtime. CUDA 13 requires an R580-or-newer NVIDIA driver.
The model downloads from Vela, with Suprnova and Hugging Face fallbacks and
SHA-256 verification. Checksums, benchmark data and third-party notices are
included. The Suprnova Vela Source-Available License 1.0 is unchanged; prior
published MIT grants through v0.1.4 remain unaffected.
Commercial or closed-source incorporation requires prior written permission
from the owner; normal mining, including for profit, remains allowed.

This packaging update was tested with real curl 7.58, including a failed
primary download followed by a successful fallback, checksum verification and
cache reuse. The official Hive installer and stats callback were exercised in
an isolated filesystem. Linux executables, Windows executables and bundled
runtime libraries are byte-identical to the qualified v0.1.10 release. No new
GPU performance or Windows hardware results are claimed; a live HiveOS web
dashboard was not available for testing.
