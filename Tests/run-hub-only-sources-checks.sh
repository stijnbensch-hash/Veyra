#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-hub-only-sources-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Shared/Core/MediaItem.swift Shared/MediaServers/MediaServerModels.swift \
 Shared/MediaServers/VeyraHubNativeClient.swift Shared/Addons/AddonManifest.swift \
 Shared/Addons/AddonStore.swift Shared/Addons/AddonRegistry.swift \
 Shared/Playback/Sources/MediaSourceProvider.swift Shared/Theme/SourceOrderSettings.swift \
 Tests/HubOnlySourcesChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
