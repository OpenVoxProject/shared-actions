#!/usr/bin/env bash
#
# Build the GitHub Actions job matrix for the acceptance job.
#
# Combines the base OS list with any extra OSes (os-add), injects the guest arch
# as a third element of each [os, version] pair, and folds in shard tags when
# the suite defines them.
#
# Usage:
#   build-job-matrix.sh <os_json> <os_add_json> <arch> <shard_tags_json>
#
# Prints the job matrix JSON, e.g.
#   {"os":[["almalinux","9","x86_64"], ...]}
#   {"os":[...],"tags":["shard:group1", ...]}   # when shard tags are present
set -euo pipefail

os=${1:?usage: build-job-matrix.sh <os_json> <os_add_json> <arch> <shard_tags_json>}
os_add=${2:-'[]'}
arch=${3:?usage: build-job-matrix.sh <os_json> <os_add_json> <arch> <shard_tags_json>}
shard_tags=${4:-'[]'}

# Concatenate base + extra OSes, de-dupe, and append the arch to each 2-element
# [os, version] pair.
os_with_arch=$(jq -cn \
  --argjson os "$os" \
  --argjson add "$os_add" \
  --arg arch "$arch" \
  '($os + $add) | unique | map(if length == 2 then . + [$arch] else . end)')

# Only include "tags" in the matrix when there are shard tags to fan out on;
# otherwise GitHub would create a spurious empty tag dimension.
jq -cn \
  --argjson os "$os_with_arch" \
  --argjson tags "$shard_tags" \
  'if ($tags | length) == 0 then {os: $os} else {os: $os, tags: $tags} end'
