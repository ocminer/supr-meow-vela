#!/usr/bin/env bash
# Hive SOURCES this callback from its agent. Set khs/stats without changing the
# caller's directory or printing an API response. One inference is one base unit
# (hs); Hive's total is always in thousands of base units (khs).
khs=0
stats=null
_vela_hive_stats() {
  local package_dir snapshot pid result
  local CUSTOM_NAME CUSTOM_VERSION CUSTOM_LOG_BASENAME CUSTOM_CONFIG_FILENAME CUSTOM_STATS_FILENAME
  package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 0
  . "$package_dir/h-manifest.conf" || return 0
  # Keep the installed package visible while its model downloads or loads.
  stats=$(jq -nc --arg ver "$CUSTOM_VERSION" '{hs:[], hs_units:"hs", temp:[], fan:[],
    bus_numbers:[], uptime:0, ver:$ver, ar:[0,0], algo:"vela-poi"}') || return 0
  [[ -r $CUSTOM_STATS_FILENAME ]] || return 0
  snapshot=$(cat -- "$CUSTOM_STATS_FILENAME" 2>/dev/null) || return 0
  pid=$(jq -er '.pid | select(type == "number" and . > 0 and . == floor)' <<< "$snapshot" 2>/dev/null) || return 0
  kill -0 "$pid" 2>/dev/null || return 0
  # Reject incomplete, stopped or stale snapshots instead of retaining a rate
  # from a previous run. CUDA supplies the PCI mapping, including --devices and
  # CUDA_VISIBLE_DEVICES; no second nvidia-smi query or guessed GPU index needed.
  result=$(jq -ce --arg ver "$CUSTOM_VERSION" --argjson now "$(date +%s)" '
    def nonnegative: type == "number" and . >= 0;
    select(.schema == 1 and (.timestamp | nonnegative) and
           .timestamp <= ($now + 5) and .timestamp >= ($now - 60) and
           (.uptime | nonnegative) and (.version | type == "string") and
           (.devices | type == "array" and length > 0) and
           all(.devices[]; (.inf_s | nonnegative) and
               (.temp == null or (.temp | nonnegative)) and
               (.fan == null or (.fan | nonnegative)) and
               (.bus_number == null or (.bus_number | nonnegative))) and
           (.shares.accepted | nonnegative) and (.shares.rejected | nonnegative) and (.shares.stale | nonnegative)) |
    {hs: [.devices[].inf_s], hs_units: "hs", temp: [.devices[].temp],
     fan: [.devices[].fan], bus_numbers: [.devices[].bus_number],
     uptime: .uptime, ver: $ver, ar: [.shares.accepted, (.shares.rejected + .shares.stale)], algo: "vela-poi"}
  ' <<< "$snapshot" 2>/dev/null) || return 0
  khs=$(jq -r '(.hs | add) / 1000' <<< "$result") || { khs=0; return 0; }
  stats=$result
}
_vela_hive_stats
unset -f _vela_hive_stats
