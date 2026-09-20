#!/bin/zsh
set -eu
cd /Users/stinus/Developer/Veyra
/usr/bin/python3 - <<'PYTHON'
from pathlib import Path
import os, shutil, subprocess
state = Path.home() / 'Library/Application Support/Veyra/iPhone'
state.mkdir(parents=True, exist_ok=True)
plist = Path.home() / 'Library/LaunchAgents/com.veyra.iphone.autodeploy.plist'
plist.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile('Tools/iphone-autodeploy.plist', plist)
service = f'gui/{os.getuid()}/com.veyra.iphone.autodeploy'
subprocess.run(['launchctl', 'enable', service], check=True)
if subprocess.run(['launchctl', 'print', service], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
    subprocess.run(['launchctl', 'bootstrap', f'gui/{os.getuid()}', str(plist)], check=True)
(state / 'PAUSED').unlink(missing_ok=True)
print('AAN: opgeslagen wijzigingen worden automatisch gebouwd, geinstalleerd en gestart op iPhone van Stijn.')
print('Een lopende afspeelsessie kan hierdoor opnieuw starten.')
PYTHON
read '?Druk Enter om dit venster te sluiten.'
