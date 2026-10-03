#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/veyra-background-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
# Compile actual shared UI in an isolated harness; no app build, install or launch.
# Same-file probes can inspect private page state without exposing a production API.
python3 - "$check_dir" <<'PYTHON'
from pathlib import Path
import sys
out = Path(sys.argv[1])
source = Path('Shared/Components/VeyraBackdrop.swift').read_text()
hero = Path('Shared/Bento/VeyraHeroSpotlightView.swift').read_text()
source += '\n' + hero[hero.index('struct VeyraHeroAmbientBackdrop: View {'):]
source += '\n' + Path('Tests/DynamicBackgroundChecks.swift').read_text()
(out / 'ProductionChecks.swift').write_text(source)
PYTHON
xcrun swiftc -parse-as-library -swift-version 5 -default-isolation MainActor \
 "$check_dir/ProductionChecks.swift" Shared/Theme/VeyraColors.swift \
 Tests/Support/DynamicBackgroundImageFixture.swift -o "$check_dir/checks"
"$check_dir/checks"
