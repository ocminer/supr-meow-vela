#!/usr/bin/env bash
# Launch supr-meow-vela. cwd is the package directory; HiveOS captures stdout.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1
. h-manifest.conf
echo "[supr-meow-vela] HiveOS package ${CUSTOM_VERSION}"
if [[ -f $CUSTOM_CONFIG_FILENAME ]]; then
  . "$CUSTOM_CONFIG_FILENAME" || exit 1
fi
CUSTOM_STATS_FILENAME=${CUSTOM_STATS_FILENAME:-${CUSTOM_LOG_BASENAME}.stats.json}
mkdir -p -- "$(dirname -- "$CUSTOM_LOG_BASENAME")" "$(dirname -- "$CUSTOM_STATS_FILENAME")" || exit 1
rm -f -- "$CUSTOM_STATS_FILENAME" || exit 1
# Bundled CUDA runtime + cuBLASLt live in lib/. The DRIVER (libcuda, libnvidia-ml) comes from HiveOS and must keep winning.
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}$(pwd)/lib"
[[ -z $POOL_URL ]] && echo "POOL_URL missing — set the pool in the flight sheet" && exit 1
[[ -z $WALLET   ]] && echo "WALLET missing — set the wallet template in the flight sheet" && exit 1
# ---- model: sd-turbo-int.poisd (1.2 GB), fetched once and cached ----------------------------------
# /hive-config is Hive's small configuration partition, not a model cache.
# Keep the cache outside the miner directory so upgrades do not delete it.
default_model_dir=${MODEL_DIR:+0}
MODEL_DIR="${MODEL_DIR:-/hive/models/supr-meow-vela}"
MODEL_URL="${MODEL_URL:-https://vela.suprnova.cc/dl/sd-turbo-int.poisd}"
MODEL_SHA256="${MODEL_SHA256:-ba38ab96b3398e22ea631d8a457350f91833e57463199d063663308513651f36}"
# A custom URL may serve a different file; only add the built-in mirrors for our
# default model. An explicit MODEL_FALLBACK_URL (space-separated list, or empty)
# overrides this.
if [[ ! ${MODEL_FALLBACK_URL+x} ]]; then
  MODEL_FALLBACK_URL=""
  [[ $MODEL_URL == https://vela.suprnova.cc/dl/sd-turbo-int.poisd ]] && \
    MODEL_FALLBACK_URL="https://www.suprnova.cc/dl/sd-turbo-int.poisd https://huggingface.co/valereseach/vela-sd-turbo-int-v2/resolve/main/sd-turbo-int.poisd"
fi
if [[ -z $MODEL_PATH && -z $default_model_dir ]]; then
  legacy="/hive-config/models/$(basename "${MODEL_URL%%\?*}")"
  if [[ -s $legacy ]] && echo "${MODEL_SHA256}  ${legacy}" | sha256sum -c - >/dev/null 2>&1; then
    MODEL_PATH=$legacy
    echo "[supr-meow-vela] reusing the verified model from $legacy"
  fi
fi
if [[ -z $MODEL_PATH ]]; then
  mkdir -p "$MODEL_DIR" || exit 1
  MODEL_PATH="$MODEL_DIR/$(basename "${MODEL_URL%%\?*}")"
  if [[ ! -s $MODEL_PATH ]]; then
    if [[ $MODEL_URL == https://vela.suprnova.cc/dl/sd-turbo-int.poisd ]]; then
      free_kb=$(df -Pk "$MODEL_DIR" | awk 'END {print $4}')
      if [[ $free_kb =~ ^[0-9]+$ && $free_kb -lt 1225300 ]]; then
        echo "[supr-meow-vela] not enough free space in $MODEL_DIR: need about 1.3 GB for the model. Set MODEL_DIR to a disk with free space."
        exit 1
      fi
    fi
    urls=( "$MODEL_URL" )
    for u in $MODEL_FALLBACK_URL; do if [[ $u != "$MODEL_URL" ]]; then urls+=( "$u" ); fi; done
    part="${MODEL_PATH}.part.$$"
    trap 'rm -f -- "$part"' EXIT
    for url in "${urls[@]}"; do
      echo "[supr-meow-vela] downloading model (1.2 GB, one time): $url"
      if command curl -q -fL -sS --retry 2 --retry-delay 2 --connect-timeout 15 \
          --speed-time 60 --speed-limit 1024 -o "$part" "$url" && \
          [[ -s $part ]] && echo "${MODEL_SHA256}  ${part}" | sha256sum -c -; then
        mv -- "$part" "$MODEL_PATH" || exit 1
        break
      fi
      echo "[supr-meow-vela] download failed or checksum mismatch: $url"
      rm -f -- "$part"
    done
    [[ -s $MODEL_PATH ]] || { echo "[supr-meow-vela] all model download sources failed"; exit 1; }
  fi
fi
[[ -s $MODEL_PATH ]] || { echo "[supr-meow-vela] no model — set MODEL_URL or MODEL_PATH in the flight sheet's extra config"; exit 1; }
echo "${MODEL_SHA256}  ${MODEL_PATH}" | sha256sum -c - || { echo "[supr-meow-vela] CHECKSUM MISMATCH — refusing to mine"; exit 1; }
args=( -o "$POOL_URL" -u "$WALLET" -p "${PASSWORD:-x}" --model "$MODEL_PATH" )
[[ -n $BATCH        ]] && args+=( --batch "$BATCH" )
[[ -n $LANES        ]] && args+=( --lanes "$LANES" )
[[ -n $DEVICES      ]] && args+=( --devices "$DEVICES" )
[[ -n $SUGGEST_DIFF ]] && args+=( --suggest-diff "$SUGGEST_DIFF" )
[[ ${TLS:-0} == 1 || $POOL_URL == stratum+ssl://* ]] && args+=( --tls )
[[ -n $EXTRA_ARGS   ]] && args+=( $EXTRA_ARGS )
# Keep the monitoring destination controlled by the launcher. Preserve the
# miner's exit status; a successful tee must not hide a failed miner.
./supr-meow-vela "${args[@]}" --stats-file "$CUSTOM_STATS_FILENAME" 2>&1 | tee -a "${CUSTOM_LOG_BASENAME}.log"
status=${PIPESTATUS[0]}
rm -f -- "$CUSTOM_STATS_FILENAME"
exit "$status"
