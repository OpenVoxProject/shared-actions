#!/usr/bin/env bash
#
# Build the VM cluster configuration for jpartlow/nested_vms, for a single
# acceptance matrix cell.
#
# For the openvox suite (agent + co-located server) an OS may have an agent
# build but no server build. In that case the server (the "primary" VM, which
# Beaker treats as master/database) is pinned to a fallback OS and a dedicated
# agent VM is added on the native OS under test, so agent coverage on the native
# OS is preserved. Every other case runs natively with the suite's base vm spec.
#
# Usage:
#   build-cluster-topology.sh <suite> <collection> <os> <os_version> [<arch>]
#
#   suite       openvox | openvox-agent | openvox-server | openvoxdb
#   collection  openvox collection (openvox9 -> main, openvox8 -> 8.x, else main)
#   os          name of operating system to use. See "universe" varaiable in project.config.sh
#   os_ver      version of operating system to use.
#   arch        architecture of guest VMs to run. Defaults to x86_64.
#
# Example:
#   ./scripts/build-cluster-topology.sh openvox openvox9 debian 11 | jq .
#
# Prints a JSON object: { "os", "os_version", "os_arch", "vms" }
# where os/os_version/os_arch are the nested_vms cluster defaults (the OS any vm
# spec without its own override inherits) and vms is the resolved vm spec array.
set -euo pipefail

suite=${1:?usage: build-cluster-topology.sh <suite> <collection> <os> <os_ver> <arch>}
collection=${2:?usage: build-cluster-topology.sh <suite> <collection> <os> <os_ver> <arch>}
os=${3:?usage: build-cluster-topology.sh <suite> <collection> <os> <os_ver> <arch>}
os_ver=${4:?usage: build-cluster-topology.sh <suite> <collection> <os> <os_ver> <arch>}
arch=${5:-x86_64}

script_dir=$(dirname "${BASH_SOURCE[0]}")
project_config=$("${script_dir}/project-config.sh" "${suite}" "${collection}")

base_vms=$(jq -c '.vms' <<<"${project_config}")
server_capable_os=$(jq -c '."server-capable-os"' <<<"${project_config}")
server_fallback_os=$(jq -c '."server-fallback-os"' <<<"${project_config}")

vms=$base_vms

if [[ "$suite" == "openvox" ]]; then
  native_pair=$(jq -cn --arg n "$os" --arg v "$os_ver" '[$n, $v]')
  if ! jq -e --argjson p "$native_pair" 'any(. == $p)' <<<"$server_capable_os" >/dev/null; then
    fb_name=$(jq -r '.[0]' <<<"$server_fallback_os")
    fb_ver=$(jq -r '.[1]' <<<"$server_fallback_os")
    echo "OS ${os}-${os_ver} has no server build in ${collection}; running the server on ${fb_name}-${fb_ver}." >&2
    # The nested_vms cluster default OS stays native (inherited by the agent);
    # the primary/server is pinned to the fallback OS via a per-vm os override.
    vms=$(jq -c \
      --arg fn "$fb_name" --arg fv "$fb_ver" --arg fa "$arch" \
      'map(if .role == "primary"
            then . + {os: {name: $fn, version: $fv, arch: $fa}}
            else . end)
       + [{role: "agent", count: 1, cpus: 2, mem_mb: 4096}]' \
      <<<"$base_vms")
  fi
fi

jq -cn \
  --arg os "$os" \
  --arg os_version "$os_ver" \
  --arg os_arch "$arch" \
  --argjson vms "$vms" \
  '{os: $os, os_version: $os_version, os_arch: $os_arch, vms: $vms}'
