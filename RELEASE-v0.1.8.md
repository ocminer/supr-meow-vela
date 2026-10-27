supr-meow-vela 0.1.8 adds Hugging Face as an additional model download source on every platform.

## What changed

- The HiveOS, MMPOS, SMOS, Docker and Windows launchers now download the `sd-turbo-int.poisd` model from three sources, in order: `https://vela.suprnova.cc/dl/`, `https://www.suprnova.cc/dl/` and `https://huggingface.co/valereseach/vela-sd-turbo-int-v2/resolve/main/sd-turbo-int.poisd`. If a download or its SHA-256 check fails, the next source is tried; only a verified model is cached.
- MMPOS, SMOS and Docker previously used a single source; they now share the HiveOS fallback behaviour. `MODEL_FALLBACK_URL` accepts a space-separated list (empty disables fallback).
- Includes the 0.1.7 fix for older curl versions (HiveOS on Ubuntu 18.04).
- Mining code and kernels are unchanged from 0.1.6; speed and outputs are identical.

## Validation

- Launcher tests run the real HiveOS, MMPOS, SMOS and Docker scripts against local download fixtures with a curl that rejects options newer than curl 7.58: primary download, fallback to the Suprnova mirror and to Hugging Face after HTTP or checksum failures, custom fallback lists, cache reuse and failure handling all pass.
- The Hugging Face file was downloaded and matches the model's SHA-256. Windows CI runs the real `start.ps1` with both Suprnova sources unreachable and verifies that it downloads and checks the model from Hugging Face.
- The rebuilt GPU code is identical to 0.1.6 for all six CUDA targets; Linux CPU, TCP reconnect and TLS reconnect regression tests passed.
- Native Windows CI builds all six CUDA targets, runs CPU/network/reconnect tests and checks that the packaged executable starts. Windows GPU mining is not hardware-tested on the hosted runner.

## Downloads

| Platform | Asset |
|---|---|
| Linux / MMPOS / SMOS | `supr-meow-vela-0.1.8.tar.gz` |
| HiveOS custom miner | `supr-meow-vela-hiveos.tar.gz` |
| Native Windows x64 | `supr-meow-vela-0.1.8-windows-x86_64.zip` |

The Linux tarball includes HiveOS, MMPOS and SMOS launchers. The separate HiveOS archive has the directory name required by its installer. Packages include file checksums; `.sha256` sidecars and `SHA256SUMS` verify downloads.

Docker: `ocminersupr/supr-meow-vela:0.1.8` and `:latest`.

All builds target SM 80, 86, 89, 90, 100 and 120 (Ampere, Ada, Hopper and Blackwell) with CUDA 13.3. A CUDA 13-capable NVIDIA driver (R580+) is required. Linux archives require glibc 2.38+ and OpenSSL 3; Docker provides the userspace dependencies. Windows uses plain TCP; TLS is available on Linux and Docker.

Reuse the existing `sd-turbo-int.poisd` model (SHA-256 `ba38ab96b3398e22ea631d8a457350f91833e57463199d063663308513651f36`); a cached, verified copy is never downloaded again.

## License

This release uses the **Suprnova Vela Source-Available License 1.0**. Running the unmodified miner or verifier, including for profit, is permitted. **Incorporation into a commercial or closed-source miner requires prior written permission from ocminer / suprnova.** Permitted derivative miners must be non-commercial and publish complete corresponding source under the same license. Read the included `LICENSE` and `NOTICE` for the full terms.

Previously released versions through v0.1.4 retain their original MIT terms. Third-party components and models keep their own licenses.
