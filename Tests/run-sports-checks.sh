#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-sports-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Veyra/Sports/SportsModels.swift Veyra/Sports/SportsStore.swift Tests/SportsChecks.swift -o "$check_dir/checks"
"$check_dir/checks" "$@"
