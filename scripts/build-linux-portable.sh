#!/usr/bin/env bash
# Build the Linux release binary so it runs on old and new distributions alike
# (Ubuntu 20.04 / glibc 2.31 up to the latest release; HiveOS, MMPOS, SMOS).
#
# A binary built on a current distribution links against that distribution's
# glibc (e.g. GLIBC_2.38) and its OpenSSL 3, so older mining OSes refuse to start
# it. This script instead uses conda-forge's GCC 13 with a glibc 2.17 sysroot,
# a static OpenSSL 3.0 and static libstdc++/libgcc. The miner then needs only
# glibc 2.17 symbols; the bundled NVIDIA libcublasLt needs glibc 2.27.
#
# usage: scripts/build-linux-portable.sh <work-dir> [build-dir]
#   work-dir   toolchain + OpenSSL cache (about 1 GB, reused between runs)
#   build-dir  CMake build directory (default <work-dir>/build)
# Then: BUILD_DIR=<build-dir> scripts/package.sh
set -euo pipefail
SRC="$(cd "$(dirname "$0")/.." && pwd)"
W="$(mkdir -p "$1" && cd "$1" && pwd)"; B="${2:-$W/build}"
CUDA=${CUDA_HOME:-/usr/local/cuda-13.3}
OSSL_VER=3.0.18
ENV="$W/env"; T="$ENV/bin/x86_64-conda-linux-gnu"

if [[ ! -x $T-g++ ]]; then
  [[ -x $W/micromamba ]] || { curl -fsSL -o "$W/micromamba" \
    https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-linux-64; chmod +x "$W/micromamba"; }
  MAMBA_ROOT_PREFIX="$W/mamba" "$W/micromamba" create -y -q -p "$ENV" -c conda-forge \
    "gxx_linux-64=13" "gcc_linux-64=13" "sysroot_linux-64=2.17" cmake ninja make perl patchelf
  rm -rf "$W/mamba/pkgs"
fi
export PATH="$ENV/bin:$CUDA/bin:/usr/bin:/bin"

OSSL="$W/openssl-$OSSL_VER-static"
if [[ ! -f $OSSL/lib/libssl.a ]]; then
  ( cd "$W" && curl -fsSL -o openssl.tgz \
      "https://github.com/openssl/openssl/releases/download/openssl-$OSSL_VER/openssl-$OSSL_VER.tar.gz" \
    && rm -rf "openssl-$OSSL_VER" && tar xzf openssl.tgz && cd "openssl-$OSSL_VER" \
    && CC=$T-gcc AR=$T-ar RANLIB=$T-ranlib ./Configure linux-x86_64 no-shared no-module no-engine \
         no-dso no-tests --prefix="$OSSL" --libdir=lib --openssldir=/nonexistent/supr-meow-vela-ssl -fPIC \
    && make -j"$(nproc)" build_libs && make install_dev ) > "$W/openssl-build.log" 2>&1
fi

# rpath-link + allow-shlib-undefined: libcudart/libcublasLt resolve their own
# libstdc++/libgcc_s/glibc symbols on the target system at run time.
cmake -S "$SRC" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=$T-gcc -DCMAKE_CXX_COMPILER=$T-g++ \
  -DCMAKE_CUDA_COMPILER="$CUDA/bin/nvcc" -DCMAKE_CUDA_HOST_COMPILER=$T-g++ -DCUDAToolkit_ROOT="$CUDA" \
  '-DCMAKE_CUDA_ARCHITECTURES=80;86;89;90;100;120' \
  -DOPENSSL_ROOT_DIR="$OSSL" -DOPENSSL_USE_STATIC_LIBS=TRUE -DMEOW_BUILD_TESTS=ON \
  "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath-link,$ENV/lib -Wl,--allow-shlib-undefined -static-libstdc++ -static-libgcc"
TMPDIR="$B" cmake --build "$B" -j"$(nproc)"

# The conda compiler adds its own library directory to the RPATH; ship only $ORIGIN/lib.
patchelf --remove-rpath "$B/supr-meow-vela"
patchelf --force-rpath --set-rpath '$ORIGIN/lib' "$B/supr-meow-vela"

need=$(objdump -T "$B/supr-meow-vela" | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1)
echo "supr-meow-vela requires up to $need"
[[ $need == GLIBC_2.17 ]] || { echo "unexpected glibc requirement $need"; exit 1; }
if readelf -d "$B/supr-meow-vela" | grep -qE 'libssl|libcrypto|libstdc\+\+|libgcc_s'; then
  echo "unexpected dynamic OpenSSL/libstdc++ dependency"; exit 1
fi
(cd "$B" && ctest --output-on-failure)
