#!/usr/bin/python3
"""Build saved Veyra changes and deploy only successful, current builds to Woonkamer."""
import argparse, fcntl, hashlib, json, os, signal, subprocess, time
from pathlib import Path

PROJECT = Path('/Users/stinus/Developer/Veyra')
STATE = Path.home() / 'Library/Application Support/Veyra/Woonkamer'
DERIVED = STATE / 'Build'
DEVICE = '00008110-000A02290C11801E'
BUNDLE = 'com.veyra.Veyra'
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

def status(message, **extra):
    value = dict(status=message, updated_at=time.strftime('%Y-%m-%d %H:%M:%S'), project=str(PROJECT), device='Woonkamer', **extra)
    temp = STATE / 'status.tmp'
    temp.write_text(json.dumps(value, indent=2))
    temp.replace(STATE / 'status.json')
    print(value['updated_at'] + ' ' + message, flush=True)

def fingerprint():
    files = []
    for base in [PROJECT/'Veyra', PROJECT/'Shared', PROJECT/'Veyra.xcodeproj']:
        for p in base.rglob('*'):
            if p.is_file() and not any(x in p.parts for x in ['xcuserdata', '.git']) and p.name != '.DS_Store':
                files.append(p)
    files += list(PROJECT.glob('*.xcconfig'))
    h = hashlib.sha256()
    for p in sorted(files):
        h.update(str(p.relative_to(PROJECT)).encode())
        h.update(p.read_bytes())
    return h.hexdigest()

def run(args, filename, timeout):
    global CHILD
    with (STATE/filename).open('w') as log:
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

def build():
    status('Bouwen')
    return run(['/usr/bin/xcodebuild', '-project', str(PROJECT/'Veyra.xcodeproj'), '-scheme', 'Veyra',
        '-configuration', 'Debug', '-destination', 'generic/platform=tvOS',
        '-derivedDataPath', str(DERIVED), '-disableAutomaticPackageResolution', '-skipPackageUpdates', '-allowProvisioningUpdates', 'build'], 'build.log', 1800)

def deploy():
    app = DERIVED/'Build/Products/Debug-appletvos/Veyra.app'
    if not app.exists(): return False
    status('Installeren op Woonkamer')
    if not run(['/usr/bin/xcrun','devicectl','device','install','app','--device',DEVICE,str(app),'--timeout','90'], 'install.log', 120):
        status('Installatie niet gelukt; opnieuw proberen zodra Woonkamer bereikbaar is')
        return False
    if not run(['/usr/bin/xcrun','devicectl','device','process','launch','--device',DEVICE,'--terminate-existing',BUNDLE,'--timeout','45'], 'launch.log', 60):
        status('Geïnstalleerd; automatisch starten niet gelukt')
        return False
    return True

def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--once', action='store_true'); args=parser.parse_args()
    os.umask(0o077); STATE.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (STATE/'worker.lock').open('w') as lock:
        try: fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError: return 0
        deployed_file = STATE/'deployed.sha256'
        deployed = deployed_file.read_text().strip() if deployed_file.exists() else ''
        built = ''; failed = ''; observed = ''; changed_at = time.monotonic(); retry_at = 0
        while not STOP:
            if (STATE/'PAUSED').exists():
                if args.once: return 1
                time.sleep(3); continue
            try: current = fingerprint()
            except OSError:
                time.sleep(3); continue
            if current != observed:
                observed=current; changed_at=time.monotonic()
            if current == deployed:
                if args.once: status('Woonkamer is bijgewerkt'); return 0
            elif current != failed and (args.once or time.monotonic()-changed_at >= 8):
                if current != built:
                    if not build():
                        failed=current; status('Build mislukt; bestaande app op Woonkamer behouden')
                        if args.once: return 1
                        continue
                    built=current
                # Never install a snapshot if another save occurred during compilation.
                if fingerprint() != current or (STATE/'PAUSED').exists():
                    if args.once: status('Wijzigingen tijdens build; volgende build nodig'); return 1
                    continue
                if time.monotonic() >= retry_at:
                    if deploy():
                        deployed=current; deployed_file.write_text(deployed)
                        status('Bijgewerkt en gestart op Woonkamer')
                        if args.once: return 0
                    else:
                        retry_at=time.monotonic()+60
                        if args.once: return 1
            time.sleep(3)
        status('Automatisch bijwerken gestopt')
        return 0

if __name__ == '__main__': raise SystemExit(main())
