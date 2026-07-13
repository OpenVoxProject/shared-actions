#!/usr/bin/env bash
#
# Build the GitHub Actions job matrix for the acceptance job.
#
# Calls through to project-config.sh, and then combines the base OS list with
# any extra OSes (os-add), injects the guest arch as a third element of each
# [os, version] pair, and folds in shard tags when the suite defines them.
#
# Usage:
#   build-job-matrix.sh <suite> <collection> [<arch>] [<qemu>]
#
#   suite       openvox | openvox-agent | openvox-server | openvoxdb
#   collection  openvox collection (openvox9 -> main, openvox8 -> 8.x, else main)
#   arch        architecture of guest VMs to run. Defaults to x86_64.
#   qemu        "true" when running arm64 guests under qemu (limits the matrix)
#
# Example:
#   ./scripts/build-job-matrix.sh openvox-server openvox9 | jq .
#
# Prints the job matrix JSON, e.g.
#   {"os":[["almalinux","9","x86_64"], ...]}
#   {"os":[...],"tags":["shard:group1", ...]}   # when shard tags are present
set -euo pipefail

suite=${1:?usage: build-job-matrix.sh <suite> <collection> [<arch>] [<qemu>]}
collection=${2:?usage: build-job-matrix.sh <suite> <collection> [<arch>] [<qemu>]}
arch=${3:-x86_64}
qemu=${5:-false}

script_dir=$(dirname "${BASH_SOURCE[0]}")
project_config=$("${script_dir}/project-config.sh" "${suite}" "${collection}" "${qemu}")

os=$(jq -c '.os' <<<"${project_config}")
os_add=$(jq -c '."os-add"' <<<"${project_config}")
shard_tags=$(jq -c '."acceptance-shard-tags"' <<<"${project_config}")

# Concatenate base + extra OSes, de-dupe, and append the arch to each 2-element
# [os, version] pair.
os_with_arch=$(jq -cn \
  --argjson os "${os}" \
  --argjson add "${os_add:-'[]'}" \
  --arg arch "${arch}" \
  '($os + $add) | unique | map(if length == 2 then . + [$arch] else . end)')

# Only include "tags" in the matrix when there are shard tags to fan out on;
# otherwise GitHub would create a spurious empty tag dimension.
jq -cn \
  --argjson os "$os_with_arch" \
  --argjson tags "$shard_tags" \
  'if ($tags | length) == 0 then {os: $os} else {os: $os, tags: $tags} end'
