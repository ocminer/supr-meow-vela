supr-meow-vela 0.1.7 fixes the automatic model download on HiveOS, MMPOS and SMOS with older curl versions.

## What changed

- The HiveOS, MMPOS and SMOS launchers no longer pass `--no-progress-meter` to curl. Older mining-OS images (for example HiveOS on Ubuntu 18.04 with curl 7.58) reject that option, so every model download failed immediately and the miner could not start. The launchers now use `-sS`, which works with every curl version.
- Mining code and kernels are unchanged from 0.1.6; speed and outputs are identical.

## Validation

- Launcher tests run the real HiveOS script against local download fixtures, with a curl that rejects options newer than curl 7.58: primary download, mirror fallback after HTTP or checksum failure, cache reuse, custom URLs and failure handling all pass. A source check confirms that no launcher uses those newer options.
- The rebuilt GPU code is identical to 0.1.6 for all six CUDA targets; Linux CPU, TCP reconnect and TLS reconnect regression tests passed.
- Native Windows CI builds all six CUDA targets, runs CPU/network/reconnect tests and checks that the packaged executable starts. Windows GPU mining is not hardware-tested on the hosted runner.

## Downloads

| Platform | Asset |
|---|---|
| Linux / MMPOS / SMOS | `supr-meow-vela-0.1.7.tar.gz` |
| HiveOS custom miner | `supr-meow-vela-hiveos.tar.gz` |
| Native Windows x64 | `supr-meow-vela-0.1.7-windows-x86_64.zip` |

The Linux tarball includes HiveOS, MMPOS and SMOS launchers. The separate HiveOS archive has the directory name required by its installer. Packages include file checksums; `.sha256` sidecars and `SHA256SUMS` verify downloads.

Docker: `ocminersupr/supr-meow-vela:0.1.7` and `:latest`.

All builds target SM 80, 86, 89, 90, 100 and 120 (Ampere, Ada, Hopper and Blackwell) with CUDA 13.3. A CUDA 13-capable NVIDIA driver (R580+) is required. Linux archives require glibc 2.38+ and OpenSSL 3; Docker provides the userspace dependencies. Windows uses plain TCP; TLS is available on Linux and Docker.

Reuse the existing `sd-turbo-int.poisd` model. HiveOS downloads from `https://vela.suprnova.cc/dl/sd-turbo-int.poisd` first and uses `https://www.suprnova.cc/dl/sd-turbo-int.poisd` as its verified fallback. If a rig already has a partial or failed download, nothing needs to be deleted; the launcher only keeps a model file whose checksum matches.

## License

This release uses the **Suprnova Vela Source-Available License 1.0**. Running the unmodified miner or verifier, including for profit, is permitted. **Incorporation into a commercial or closed-source miner requires prior written permission from ocminer / suprnova.** Permitted derivative miners must be non-commercial and publish complete corresponding source under the same license. Read the included `LICENSE` and `NOTICE` for the full terms.

Previously released versions through v0.1.4 retain their original MIT terms. Third-party components and models keep their own licenses.
