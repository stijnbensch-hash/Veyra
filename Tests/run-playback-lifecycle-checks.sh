#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-playback-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -emit-library -emit-module -module-name AetherEngine Tests/Support/AetherLifecycleFixture.swift \
 -o "$check_dir/libAetherEngine.dylib" -emit-module-path "$check_dir/AetherEngine.swiftmodule"
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -enable-upcoming-feature NonisolatedNonsendingByDefault \
 -I "$check_dir" -L "$check_dir" -lAetherEngine -Xlinker -rpath -Xlinker "$check_dir" \
 Shared/ViewModels/PlaybackViewModel.swift Tests/PlaybackLifecycleChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
