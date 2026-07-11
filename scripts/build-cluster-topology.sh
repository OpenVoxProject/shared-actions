#!/usr/bin/env bash
#
# Build the VM cluster for a single acceptance matrix cell.
#
# For the openvox suite (agent + co-located server) an OS may have an agent
# build but no server build. In that case the server (the "primary" VM, which
# Beaker treats as master/database) is pinned to a fallback OS and a dedicated
# agent VM is added on the native OS under test, so agent coverage on the native
# OS is preserved. Every other case runs natively with the suite's base vm spec.
#
# Usage:
#   build-cluster-topology.sh <suite> <native_os> <native_ver> <native_arch> \
#       <base_vms_json> <server_capable_os_json> <server_fallback_os_json>
#
# Prints a JSON object: { "os", "os_version", "os_arch", "vms" }
# where os/os_version/os_arch are the nested_vms cluster defaults (the OS any vm
# spec without its own override inherits) and vms is the resolved vm spec array.
set -euo pipefail

suite=${1:?}
native_os=${2:?}
native_ver=${3:?}
native_arch=${4:?}
base_vms=${5:?}
server_capable_os=${6:?}
server_fallback_os=${7:?}

os=$native_os
os_version=$native_ver
os_arch=$native_arch
vms=$base_vms

if [[ "$suite" == "openvox" ]]; then
  native_pair=$(jq -cn --arg n "$native_os" --arg v "$native_ver" '[$n, $v]')
  if ! jq -e --argjson p "$native_pair" 'any(. == $p)' <<<"$server_capable_os" >/dev/null; then
    fb_name=$(jq -r '.[0]' <<<"$server_fallback_os")
    fb_ver=$(jq -r '.[1]' <<<"$server_fallback_os")
    echo "Native OS ${native_os}-${native_ver} has no server build; running the server on ${fb_name}-${fb_ver}." >&2
    # The nested_vms cluster default OS stays native (inherited by the agent);
    # the primary/server is pinned to the fallback OS via a per-vm os override.
    vms=$(jq -c \
      --arg fn "$fb_name" --arg fv "$fb_ver" --arg fa "$native_arch" \
      'map(if .role == "primary"
            then . + {os: {name: $fn, version: $fv, arch: $fa}}
            else . end)
       + [{role: "agent", count: 1, cpus: 2, mem_mb: 4096}]' \
      <<<"$base_vms")
  fi
fi

jq -cn \
  --arg os "$os" \
  --arg os_version "$os_version" \
  --arg os_arch "$os_arch" \
  --argjson vms "$vms" \
  '{os: $os, os_version: $os_version, os_arch: $os_arch, vms: $vms}'
