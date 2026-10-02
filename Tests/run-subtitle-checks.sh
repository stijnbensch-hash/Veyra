#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-subtitle-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 Shared/Core/MediaItem.swift Shared/Playback/Subtitles/SubtitlePreferences.swift \
 Shared/Playback/Subtitles/OpenSubtitlesModels.swift Shared/Playback/Subtitles/OpenSubtitlesClient.swift \
 Tests/SubtitlePreferencesChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
