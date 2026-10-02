#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-sports-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Shared/Core/Configuration/VeyraEndpoints.swift Shared/Sports/SportsFavorites.swift Shared/Sports/SportsDisplayPreferences.swift Shared/Sports/SportsModels.swift Shared/Sports/SportsStore.swift Tests/SportsChecks.swift -o "$check_dir/checks"
"$check_dir/checks" "$@"
