#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-subtitle-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Veyra/Core/MediaItem.swift Veyra/Subtitles/SubtitlePreferences.swift \
 Veyra/Subtitles/OpenSubtitlesModels.swift Veyra/Subtitles/OpenSubtitlesClient.swift \
 Tests/SubtitlePreferencesChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
