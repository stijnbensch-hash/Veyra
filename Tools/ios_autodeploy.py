#!/usr/bin/python3
"""Build saved Veyra-iOS changes and deploy only successful, current builds to a
paired iPhone/iPad. Generalized version of woonkamer_autodeploy.py: the target
device name and UDID are passed as arguments so the same script drives one
LaunchAgent per physical device (iPad, iPhone van Stijn, ...)."""
import argparse, fcntl, hashlib, json, os, signal, subprocess, time
from pathlib import Path

PROJECT = Path('/Users/stinus/Developer/Veyra')
BUNDLE = 'com.veyra.Veyra-iOS'
SCHEME = 'Veyra-iOS'
CHILD = None
STOP = False

def signal_stop(*_):
    global STOP
    STOP = True
    if CHILD and CHILD.poll() is None:
        try: os.killpg(CHILD.pid, signal.SIGTERM)
        except ProcessLookupError: pass

signal.signal(signal.SIGTERM, signal_stop)
signal.signal(signal.SIGINT, signal_stop)

def status(state, device_name, message, **extra):
    value = dict(status=message, updated_at=time.strftime('%Y-%m-%d %H:%M:%S'), project=str(PROJECT), device=device_name, **extra)
    temp = state / 'status.tmp'
    temp.write_text(json.dumps(value, indent=2))
    temp.replace(state / 'status.json')
    print(value['updated_at'] + ' ' + message, flush=True)

def fingerprint():
    files = []
    for base in [PROJECT/'Veyra-iOS', PROJECT/'Shared', PROJECT/'Veyra.xcodeproj']:
        for p in base.rglob('*'):
            if p.is_file() and not any(x in p.parts for x in ['xcuserdata', '.git']) and p.name != '.DS_Store':
                files.append(p)
    files += list(PROJECT.glob('*.xcconfig'))
    h = hashlib.sha256()
    for p in sorted(files):
        h.update(str(p.relative_to(PROJECT)).encode())
        h.update(p.read_bytes())
    return h.hexdigest()

def run(state, args, filename, timeout):
    global CHILD
    with (state/filename).open('w') as log:
        CHILD = subprocess.Popen(args, cwd=PROJECT, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try: result = CHILD.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(CHILD.pid, signal.SIGTERM)
            try: CHILD.wait(timeout=10)
            except subprocess.TimeoutExpired:
                os.killpg(CHILD.pid, signal.SIGKILL); CHILD.wait()
            result = 124
        finally: CHILD = None
    return result == 0 and not STOP

def build(state, derived):
    status(state, state.name, 'Bouwen')
    return run(state, ['/usr/bin/xcodebuild', '-project', str(PROJECT/'Veyra.xcodeproj'), '-scheme', SCHEME,
        '-configuration', 'Debug', '-destination', 'generic/platform=iOS',
        '-derivedDataPath', str(derived), '-disableAutomaticPackageResolution', '-skipPackageUpdates', '-allowProvisioningUpdates', 'build'], 'build.log', 1800)

def deploy(state, derived, device_udid):
    app = derived/'Build/Products/Debug-iphoneos/Veyra-iOS.app'
    if not app.exists(): return False
    status(state, state.name, f'Installeren op {state.name}')
    if not run(state, ['/usr/bin/xcrun','devicectl','device','install','app','--device',device_udid,str(app),'--timeout','90'], 'install.log', 120):
        status(state, state.name, 'Installatie niet gelukt; opnieuw proberen zodra toestel bereikbaar is')
        return False
    if not run(state, ['/usr/bin/xcrun','devicectl','device','process','launch','--device',device_udid,'--terminate-existing',BUNDLE,'--timeout','45'], 'launch.log', 60):
        status(state, state.name, 'Geinstalleerd; automatisch starten niet gelukt')
        return False
    return True

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('device_name')
    parser.add_argument('device_udid')
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()

    state = Path.home() / 'Library/Application Support/Veyra' / args.device_name
    derived = state / 'Build'
    os.umask(0o077); state.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (state/'worker.lock').open('w') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: return 0
        deployed_file = state/'deployed.sha256'
        deployed = deployed_file.read_text().strip() if deployed_file.exists() else ''
        built = ''; failed = ''; observed = ''; changed_at = time.monotonic(); retry_at = 0
        while not STOP:
            if (state/'PAUSED').exists():
                if args.once: return 1
                time.sleep(3); continue
            try: current = fingerprint()
            except OSError:
                time.sleep(3); continue
            if current != observed:
                observed=current; changed_at=time.monotonic()
            if current == deployed:
                if args.once: status(state, args.device_name, f'{args.device_name} is bijgewerkt'); return 0
            elif current != failed and (args.once or time.monotonic()-changed_at >= 8):
                if current != built:
                    if not build(state, derived):
                        failed=current; status(state, args.device_name, 'Build mislukt; bestaande app behouden')
                        if args.once: return 1
                        continue
                    built=current
                # Never install a snapshot if another save occurred during compilation.
                if fingerprint() != current or (state/'PAUSED').exists():
                    if args.once: status(state, args.device_name, 'Wijzigingen tijdens build; volgende build nodig'); return 1
                    continue
                if time.monotonic() >= retry_at:
                    if deploy(state, derived, args.device_udid):
                        deployed=current; deployed_file.write_text(deployed)
                        status(state, args.device_name, f'Bijgewerkt en gestart op {args.device_name}')
                        if args.once: return 0
                    else:
                        retry_at=time.monotonic()+60
                        if args.once: return 1
            time.sleep(3)
        status(state, args.device_name, 'Automatisch bijwerken gestopt')
        return 0

if __name__ == '__main__': raise SystemExit(main())
