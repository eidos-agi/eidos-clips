#!/usr/bin/env python3
"""Real AVFoundation encode/decode and process-kill checks on synthetic inputs only."""
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time

probe = str(Path(sys.argv[1] if len(sys.argv) > 1 else '.build/release/clips-probe').resolve())
evidence_path = Path(sys.argv[2] if len(sys.argv) > 2 else 'dist/foundation-evidence.json')
evidence = {'sourceCommit': os.environ.get('GITHUB_SHA'), 'platform': platform.platform(),
            'architecture': platform.machine(), 'hardwareValidated': False, 'checks': []}


def run(*args, success=True):
    result = subprocess.run([probe, *map(str, args)], text=True, capture_output=True, timeout=60)
    assert (result.returncode == 0) == success, (args, result.stdout, result.stderr)
    return [json.loads(line) for line in result.stdout.splitlines()] if success else result.stderr


def snapshot(package):
    return {str(p.relative_to(package)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in package.rglob('*') if p.is_file()}


with tempfile.TemporaryDirectory(prefix='Clips fixture $ unicode-🎬 ') as folder:
    root = Path(folder)
    normal = run('record', root / 'normal', 8, 'pause')
    package = Path(normal[0]['package'])
    assert normal[-1]['status'] == 'ready', normal
    before = snapshot(package)
    full = run('recover', package, root / 'full.mp4')[-1]
    assert abs(full['duration'] - 7) < 0.1, full
    assert full['videoFrames'] == 210, full
    assert full['audioSamples'] >= 6.9 * 48000, full
    trimmed = run('recover', package, root / 'trim.mp4', 1, 3)[-1]
    assert abs(trimmed['duration'] - 2) < 0.1, trimmed
    assert 59 <= trimmed['videoFrames'] <= 61, trimmed
    assert trimmed['audioSamples'] >= 1.9 * 48000, trimmed
    run('recover', package, root / 'full.mp4', success=False)
    assert snapshot(package) == before, 'Export mutated source package'
    evidence['checks'].append({'name': 'normal-stop-pause-three-tracks-trim-no-overwrite',
                               'passed': True, 'full': full, 'trim': trimmed})

    for checkpoint, extra_delay in [(0, 0), (1, 0.05), (3, 0.75)]:
        process = subprocess.Popen([probe, 'record', str(root / f'kill-{checkpoint}'), '30'],
                                   text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            killed_package = Path(json.loads(process.stdout.readline())['package'])
            deadline = time.monotonic() + 30
            while True:
                manifest = json.loads((killed_package / 'manifest.json').read_text())
                videos = [s for s in manifest['segments'] if s['kind'] == 'video']
                if len(videos) >= checkpoint:
                    break
                assert process.poll() is None, process.stderr.read()
                assert time.monotonic() < deadline, 'Checkpoint timed out'
                time.sleep(0.025)
            time.sleep(extra_delay)
            process.kill()
            process.wait(timeout=10)
            manifest = json.loads((killed_package / 'manifest.json').read_text())
            assert manifest['status'] == 'recording', manifest
            before = snapshot(killed_package)
            videos = [s for s in manifest['segments'] if s['kind'] == 'video']
            if not videos:
                run('recover', killed_package, root / f'kill-{checkpoint}.mp4', success=False)
                decoded = None
            else:
                decoded = run('recover', killed_package, root / f'kill-{checkpoint}.mp4')[-1]
                expected_frames = round(sum(s['duration'] for s in videos) * 30)
                assert abs(decoded['videoFrames'] - expected_frames) <= 1, (decoded, expected_frames)
            assert snapshot(killed_package) == before, 'Recovery mutated source'
            evidence['checks'].append({'name': f'process-kill-checkpoint-{checkpoint}', 'passed': True,
                'committedVideoSegments': len(videos), 'decoded': decoded, 'extraDelaySeconds': extra_delay})
        finally:
            if process.poll() is None:
                process.kill(); process.wait(timeout=10)

    manifest = json.loads((package / 'manifest.json').read_text())
    media = package / manifest['segments'][0]['file']
    data = bytearray(media.read_bytes()); data[len(data) // 2] ^= 1; media.write_bytes(data)
    corrupt_before = snapshot(package)
    error = run('recover', package, root / 'corrupt.mp4', success=False)
    assert 'integrity' in error.lower(), error
    assert not (root / 'corrupt.mp4').exists()
    assert snapshot(package) == corrupt_before
    evidence['checks'].append({'name': 'same-size-corruption-rejected-source-retained', 'passed': True})

evidence['unproven'] = ['screen capture', 'camera composition', 'microphone and system hardware',
    'permission prompts', 'echo and two-hour A/V drift', 'lock/sleep and device changes',
    'disk-full and power-loss recovery', 'fragmented vs segmented comparison',
    'macOS 14 runtime', 'Gatekeeper/notarized installation', 'accessibility and performance']
evidence_path.parent.mkdir(parents=True, exist_ok=True)
evidence_path.write_text(json.dumps(evidence, indent=2) + '\n')
print(json.dumps(evidence, indent=2))
