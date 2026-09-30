#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-iptv-discovery-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Shared/Core/IPTV/IPTVDiskCache.swift Shared/Core/IPTV/IPTVDiscoverySnapshotStore.swift Tests/IPTVDiscoveryChecks.swift -o "$check_dir/checks"
"$check_dir/checks" "$@"
