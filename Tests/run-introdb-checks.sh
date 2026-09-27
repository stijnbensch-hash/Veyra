#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-introdb-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 \
  Shared/Playback/IntroDBClient.swift Tests/IntroDBChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
