#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-trakt-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  Shared/Core/MediaItem.swift Shared/Core/Configuration/VeyraAPIKeyStore.swift Shared/Core/Configuration/AppConfiguration.swift \
  Shared/Core/Trakt/TraktModels.swift Shared/Core/Trakt/TraktWatchedStatus.swift Shared/Core/Trakt/TraktKeychain.swift Shared/Core/Trakt/TraktClient.swift Shared/Core/Trakt/TraktStore.swift \
  Tests/TraktIntegrationChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
