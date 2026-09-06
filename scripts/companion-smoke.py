#!/usr/bin/env python3
"""Launch the actual companion in iPad Simulator. This does not exercise Pencil hardware or pairing."""
import json
import pathlib
import subprocess
import time


def run(*args, timeout=120):
    return subprocess.check_output(args, text=True, timeout=timeout)


def main():
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))['devices']
    candidates = [device for runtime, values in devices.items() if '.iOS-' in runtime for device in values if device['name'].startswith('iPad') and device.get('isAvailable')]
    if not candidates:
        raise RuntimeError('No available iPad simulator; companion UI evidence cannot be claimed')
    device = candidates[0]; identifier = device['udid']
    if device['state'] != 'Booted':
        run('xcrun', 'simctl', 'boot', identifier)
    try:
        run('xcrun', 'simctl', 'bootstatus', identifier, '-b', timeout=180)
        run('xcrun', 'simctl', 'install', identifier, 'dist/Clips Draw Simulator.app')
        run('xcrun', 'simctl', 'launch', '--terminate-running-process', identifier, 'org.eidos.clips.draw')
        time.sleep(3)
        run('xcrun', 'simctl', 'io', identifier, 'screenshot', 'dist/ui-ipad-pairing.png')
        run('xcrun', 'simctl', 'launch', '--terminate-running-process', identifier, 'org.eidos.clips.draw', '--ui-smoke-drawing')
        time.sleep(2)
        run('xcrun', 'simctl', 'io', identifier, 'screenshot', 'dist/ui-ipad-drawing.png')
        for name in ['ui-ipad-pairing.png', 'ui-ipad-drawing.png']:
            if pathlib.Path('dist', name).stat().st_size < 10_000:
                raise RuntimeError('Companion screenshot was empty')
        evidence = dict(simulatorLaunched=True, screenshots=['pairing', 'drawing fixture'], hardwareValidated=False, networkPaired=False, pencilInputExercised=False)
        pathlib.Path('dist/companion-smoke.json').write_text(json.dumps(evidence, indent=2))
        print(json.dumps(evidence))
    finally:
        run('xcrun', 'simctl', 'shutdown', identifier)


if __name__ == '__main__':
    main()
