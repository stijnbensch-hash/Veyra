#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-regional-i18n-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Shared/Core/Regional/RegionalReleaseModels.swift \
 Shared/Core/Regional/RegionalReleaseProvider.swift \
 Shared/Core/Regional/RegionalReleaseProviderRegistry.swift \
 Shared/Core/Regional/MockRegionalReleaseProvider.swift \
 Tests/RegionalReleaseInternationalizationChecks.swift -o "$check_dir/checks"
"$check_dir/checks" "$@"
