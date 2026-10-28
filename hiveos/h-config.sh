#!/usr/bin/env bash
# Sourced by Hive's miner_config_gen; write the flight sheet as a shell config.
_vela_hive_config() {
  local pool temporary line
  [[ -n $CUSTOM_URL ]] || { echo "CUSTOM_URL is empty" >&2; return 1; }
  [[ -n $CUSTOM_TEMPLATE ]] || { echo "CUSTOM_TEMPLATE (wallet) is empty" >&2; return 1; }
  [[ -n $CUSTOM_CONFIG_FILENAME ]] || { echo "No CUSTOM_CONFIG_FILENAME" >&2; return 1; }
  # Hive allows several pool URLs; this miner currently uses the first endpoint.
  read -r pool _ <<< "${CUSTOM_URL//$'\r'/}"
  [[ -n $pool ]] || { echo "Pool URL is empty" >&2; return 1; }
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z_0-9]*=|#|$) ]] || {
      echo 'Invalid extra config: use assignments such as BATCH=4 or EXTRA_ARGS="--mem 2048"' >&2
      return 1
    }
  done <<< "${CUSTOM_USER_CONFIG//$'\r'/}"
  temporary="${CUSTOM_CONFIG_FILENAME}.tmp.$$"
  {
    printf 'POOL_URL=%q\nWALLET=%q\nPASSWORD=%q\n' "$pool" "$CUSTOM_TEMPLATE" "${CUSTOM_PASS:-x}"
    printf '%s\n' "${CUSTOM_USER_CONFIG//$'\r'/}"
  } > "$temporary" || return 1
  if ! bash -n "$temporary"; then
    echo 'Invalid extra config: use one KEY=VALUE assignment per line, quoting values containing spaces' >&2
    rm -f -- "$temporary"
    return 1
  fi
  mv -f -- "$temporary" "$CUSTOM_CONFIG_FILENAME"
}
_vela_hive_config
