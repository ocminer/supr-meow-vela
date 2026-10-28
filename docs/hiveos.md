# HiveOS custom-miner setup

Use v0.1.11 or later for the installation and monitoring fixes. The package
requires an NVIDIA GPU supported by the miner, a CUDA 13 compatible driver
(R580 or newer), and an Ubuntu 20.04 or newer HiveOS image. Allow about **3 GB
of free space on the root filesystem** for the download, extracted runtime
and the 1.2 GB model. The model itself needs about 1.3 GB free at its cache path.

## Flight sheet

Choose **Custom** as the miner, then fill its configuration as follows:

| Field | Value |
|---|---|
| Custom miner name | `supr-meow-vela` |
| Installation URL | `https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.11/supr-meow-vela-0.1.11.tar.gz` |
| Hash algorithm | `vela-poi` (use the custom algorithm field if it is not listed) |
| Wallet and worker template | `%WAL%.%WORKER_NAME%` |
| Pool URL | `vela.suprnova.cc:7601` |
| Pass | `x` |
| Extra config arguments | Leave empty for the defaults |

The wallet must be a Vela address. If your wallet field already includes a
worker suffix, use `%WAL%` as the template. The miner uses the first pool URL
when several are supplied. For TLS, use `stratum+ssl://vela.suprnova.cc:7604`,
or set `TLS=1` with `vela.suprnova.cc:7604`.

Optional extra config uses **one shell `KEY=VALUE` assignment per line**:

```bash
BATCH=4
LANES=2
DEVICES=0,1
EXTRA_ARGS="--mem 2048"
```

Omit `DEVICES` to use all visible CUDA devices. Do not paste bare CLI flags
such as `--batch 4` into this field; use `BATCH=4` or `EXTRA_ARGS="--batch 4"`.

## Installation and upgrades

Use the versioned installation URL above. Both Linux archives contain the
required top-level `supr-meow-vela/` directory and executable Hive callbacks.
The legacy `supr-meow-vela-hiveos.tar.gz` alias is still provided, but Hive may
reuse a previously downloaded archive with that same name after an upgrade.

Update **both version numbers** in the flight sheet installation URL to
**0.1.11**, save it, then force-install that same package from a Hive shell.
Keeping an old URL can cause Hive to reinstall the older launcher:

```bash
miner stop
/hive/miners/custom/custom-get https://github.com/ocminer/supr-meow-vela/releases/download/v0.1.11/supr-meow-vela-0.1.11.tar.gz -f
miner start
```

The first launcher line must show `[supr-meow-vela] HiveOS package 0.1.11`.
The native executable still reports **0.1.10**: this release intentionally
reuses the existing binaries. Hive displays the **package version**, including
while the model is downloading.

The default model cache is **`/hive/models/supr-meow-vela`**, outside the small
`/hive-config` configuration partition and outside the miner installation
folder. It survives custom-miner upgrades. A valid model cached by an older
version under `/hive-config/models` is reused without another download.

To use another disk or an existing model, set one of these in extra config:

```bash
MODEL_DIR=/path/on/larger/disk/vela-models
# Or use an existing, checksum-verified model:
MODEL_PATH=/path/to/sd-turbo-int.poisd
```

The launcher tries the Vela model server, then Suprnova, then Hugging Face,
and verifies SHA-256 before mining. First start takes longer while downloading
and checking the model. If a low-hashrate watchdog restarts a first-time setup,
allow the model download to finish before enabling that watchdog.

## Monitoring and troubleshooting

`miner log` shows the miner output. The log is
`/var/log/miner/supr-meow-vela/supr-meow-vela.log`; the atomic stats snapshot is
`/var/log/miner/supr-meow-vela/supr-meow-vela.stats.json`.

Hive reads the `h-stats.sh` callback, which sets its `khs` and `stats` variables.
There is **no miner HTTP port to configure**. Port 9010 belongs to the separate
pool verifier and must not be enabled for dashboard monitoring.

The snapshot reports actual inferences per second. Hive's base rate unit `hs`
is used for each GPU, with total `khs = inf/s / 1000`; for example, 28.4 inf/s
is 28.4 base units or 0.0284 kH/s. Hive may display H/s rather than inf/s.
Selected/reordered GPUs are mapped by their actual CUDA PCI bus numbers.
Unavailable fan readings remain null. Missing, dead-process or stale stats
report zero instead of retaining an old hashrate.

- **`curl: option --no-progress-meter: is unknown`:** the packaged launcher does not pass this option and works with curl 7.58. Update the flight-sheet URL and force-reinstall as above; no curl upgrade is needed for this fix. Check the package banner to confirm which launcher actually runs.
- **Missing `h-manifest.conf` after install:** use the versioned v0.1.11 package and force-reinstall it. The generic archive layout in older releases was unsuitable for Hive's installer.
- **Not enough free space:** check `df -h / /hive/models/supr-meow-vela` and set `MODEL_DIR` to a filesystem with room. Installing on a large SSD does not itself guarantee that the mounted partition has free space.
- **CUDA driver error / no CUDA devices:** check `nvidia-smi` and the installed driver; the package includes CUDA runtime libraries, not a kernel driver.
- **Zero rate immediately after starting:** allow the model to load and the first mining interval to complete, then check the log for a pool or CUDA error.

Integration follows the [official Hive custom-miner contract](https://github.com/minershive/hiveos-linux/blob/master/hive/miners/custom/README.md),
[installer](https://github.com/minershive/hiveos-linux/blob/master/hive/miners/custom/custom-get)
and [agent callback](https://github.com/minershive/hiveos-linux/blob/master/hive/miners/custom/h-stats.sh).
