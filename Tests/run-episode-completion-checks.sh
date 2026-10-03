#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-episode-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -emit-library -emit-module -module-name AetherEngine Tests/Support/AetherEpisodeEndFixture.swift \
 -o "$check_dir/libAetherEngine.dylib" -emit-module-path "$check_dir/AetherEngine.swiftmodule"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -I "$check_dir" -L "$check_dir" -lAetherEngine -Xlinker -rpath -Xlinker "$check_dir" \
 Shared/Playback/VeyraEpisodeCompletion.swift Tests/EpisodeCompletionChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
