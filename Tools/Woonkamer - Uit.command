#!/bin/zsh
set -eu
cd /Users/stinus/Developer/Veyra
/usr/bin/python3 - <<'PYTHON'
from pathlib import Path
import os, subprocess, json, datetime, time
state = Path.home() / 'Library/Application Support/Veyra/Woonkamer'
state.mkdir(parents=True, exist_ok=True)
(state / 'PAUSED').touch()
service = f'gui/{os.getuid()}/com.veyra.woonkamer.autodeploy'
subprocess.run(['launchctl', 'disable', service], check=True)
result = subprocess.run(['launchctl', 'bootout', service], capture_output=True)
for attempt in range(20):
    if subprocess.run(['launchctl', 'print', service], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        break
    time.sleep(0.5)
else:
    raise SystemExit('Stoppen niet bevestigd. Laat dit venster open voor controle.')
(state / 'status.json').write_text(json.dumps({'status':'Automatisch bijwerken uitgeschakeld door gebruiker','updated_at':datetime.datetime.now().isoformat(timespec='seconds'),'device':'Woonkamer'}, indent=2))
print('UIT: automatisch bouwen en installeren is gestopt, ook na opnieuw aanmelden.')
PYTHON
read '?Druk Enter om dit venster te sluiten.'
