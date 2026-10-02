#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-artwork-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
# Compile actual model/protocol/provider sections with isolated service fixtures.
python3 - "$check_dir/ArtworkSource.swift" <<'PY'
import sys
from pathlib import Path
trakt=Path('Shared/Bento/VeyraBentoTrakt.swift').read_text()
adapters=Path('Shared/Bento/VeyraBentoAdapters.swift').read_text()
source='import Foundation\nimport Observation\n'
source+=trakt[trakt.index('// MARK: - Domeinmodellen'):trakt.index('// MARK: - Trakt DTO')]
source+=trakt[trakt.index('// MARK: - ViewModel'):trakt.index('// MARK: - Voorbeelddata')]
source+=adapters[adapters.index('// MARK: - TMDB-artwork'):adapters.index('// MARK: - Sport-menu')]
Path(sys.argv[1]).write_text(source)
PY
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 -enable-upcoming-feature NonisolatedNonsendingByDefault \
 "$check_dir/ArtworkSource.swift" Tests/ArtworkSpeedChecks.swift -o "$check_dir/checks"
"$check_dir/checks"
