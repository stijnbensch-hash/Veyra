#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-memory-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -enable-upcoming-feature NonisolatedNonsendingByDefault \
 Shared/Core/Memory/VeyraBoundedCache.swift Shared/Components/VeyraAsyncImage.swift \
 Shared/Core/IPTV/IPTVDiskCache.swift Shared/Core/IPTV/IPTVProviderPreferences.swift \
 Shared/Core/IPTV/IPTVProviderEnablement.swift Tests/MemoryStabilityChecks.swift \
 -o "$check_dir/checks"
"$check_dir/checks"
