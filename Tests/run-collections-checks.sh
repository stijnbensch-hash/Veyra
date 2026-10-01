#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-collections-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
  Shared/Core/MediaItem.swift \
  Shared/Core/Collections/VeyraCollectionModels.swift Shared/Core/Collections/VeyraCollectionStore.swift \
  Tests/CollectionsChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
