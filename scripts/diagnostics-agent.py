#!/usr/bin/env python3
"""Validate Clips' content-free outbox and optionally commit reports through local git authentication."""
import argparse
import json
import math
import pathlib
import re
import subprocess
import tempfile
import uuid

EVENTS = set('appLaunch commandAccepted commandRejected capturePreparing captureStarted capturePaused captureResumed captureStopped captureFailed permissionResult captureConfiguration inputSummary encoderWait queueOverload segmentCommitted exportStarted exportCompleted exportFailed moduleEnabled moduleDisabled drawingAccepted drawingRejected deviceConnected deviceDisconnected pairingRejected reportCreated eventsDropped'.split())
METRICS = set('durationMs count width height microphone systemAudio camera region complete incomplete queueDepth waitMs bytes revision success'.split())


def unique_object(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError('Duplicate JSON field')
        result[key] = value
    return result


def valid_uuid(value):
    if not isinstance(value, str) or str(uuid.UUID(value)).lower() != value.lower():
        raise ValueError('Invalid report identifier')


def validate(data):
    if len(data) > 5_000_000:
        raise ValueError('Report too large')
    report = json.loads(data, object_pairs_hook=unique_object)
    if not isinstance(report, dict) or set(report) != {'schemaVersion', 'reportID', 'runID', 'sourceCommit', 'hardwareValidated', 'records'}:
        raise ValueError('Unapproved report fields')
    if type(report['schemaVersion']) is not int or report['schemaVersion'] != 1 or report['hardwareValidated'] is not False:
        raise ValueError('Unsupported report version or evidence claim')
    valid_uuid(report['reportID']); valid_uuid(report['runID'])
    if not isinstance(report['sourceCommit'], str) or not re.fullmatch(r'(?:local|[0-9a-fA-F]{40})', report['sourceCommit']):
        raise ValueError('Invalid source commit')
    if not isinstance(report['records'], list) or len(report['records']) > 4096:
        raise ValueError('Invalid records')
    previous = 0
    for row in report['records']:
        required = {'event', 'sequence', 'elapsedMs', 'metrics'}
        if not isinstance(row, dict) or not required <= set(row) <= required | {'operationID'}:
            raise ValueError('Unapproved event fields')
        if row['event'] not in EVENTS:
            raise ValueError('Unapproved event')
        if type(row['sequence']) is not int or row['sequence'] <= previous or type(row['elapsedMs']) is not int or row['elapsedMs'] < 0:
            raise ValueError('Invalid event ordering')
        previous = row['sequence']
        if 'operationID' in row and row['operationID'] is not None:
            valid_uuid(row['operationID'])
        if not isinstance(row['metrics'], dict) or not set(row['metrics']) <= METRICS:
            raise ValueError('Unapproved metrics')
        for value in row['metrics'].values():
            if type(value) not in (int, float) or not math.isfinite(value) or abs(value) > 1e15:
                raise ValueError('Unapproved metric value')
    return report


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=pathlib.Path, required=True)
    parser.add_argument('--outbox', type=pathlib.Path, default=pathlib.Path.home() / 'Movies/Eidos Clips/Diagnostic Outbox')
    parser.add_argument('--publish', action='store_true', help='Commit validated reports to diagnostics/local-reports using existing git credentials')
    args = parser.parse_args()
    files = sorted(args.outbox.glob('*.json'))
    if len(files) > 20:
        raise ValueError('Outbox exceeds 20 reports; archive old reports first')
    reports = []
    for file in files:
        if file.is_symlink() or not file.is_file() or file.stat().st_size > 5_000_000:
            raise ValueError('Only bounded regular report files are accepted')
        report = validate(file.read_bytes())
        if file.stem.lower() != report['reportID'].lower():
            raise ValueError('Report filename does not match its identifier')
        reports.append((file, report))
    print(f'Validated {len(reports)} report(s). Recording media, notes, paths and text attachments are not accepted.')
    if not args.publish or not reports:
        return
    remote = git(args.repo, 'remote', 'get-url', 'origin')
    if remote not in ('https://github.com/eidos-agi/eidos-clips.git', 'https://github.com/eidos-agi/eidos-clips', 'git@github.com:eidos-agi/eidos-clips.git'):
        raise ValueError('Origin is not the Eidos Clips repository')
    if (args.outbox / 'Sent').is_symlink():
        raise ValueError('Sent receipt directory must not be a link')
    branch = 'diagnostics/local-reports'
    git(args.repo, 'fetch', 'origin', 'main')
    exists = git(args.repo, 'ls-remote', '--heads', 'origin', branch)
    base = git(args.repo, 'rev-parse', 'FETCH_HEAD')
    if exists:
        git(args.repo, 'fetch', 'origin', branch)
        base = git(args.repo, 'rev-parse', 'FETCH_HEAD')
    with tempfile.TemporaryDirectory(prefix='clips-report-') as temporary:
        worktree = pathlib.Path(temporary) / 'checkout'
        git(args.repo, 'worktree', 'add', '--detach', str(worktree), base)
        try:
            folder = worktree / 'diagnostics' / 'reports'
            # Never follow repository-provided links into unrelated files.
            if (worktree / 'diagnostics').is_symlink() or folder.is_symlink():
                raise ValueError('Diagnostic destination must not be a link')
            folder.mkdir(parents=True, exist_ok=True)
            for _, report in reports:
                path = folder / (report['reportID'] + '.json')
                canonical = json.dumps(report, sort_keys=True, indent=2, allow_nan=False) + '\n'
                if path.is_symlink():
                    raise ValueError('Diagnostic destination must not be a link')
                if path.exists() and path.read_text() != canonical:
                    raise ValueError('A different report already uses this identifier')
                path.write_text(canonical)
            git(worktree, 'add', '--', 'diagnostics/reports')
            if git(worktree, 'diff', '--cached', '--name-only'):
                git(worktree, 'commit', '-m', 'Add validated Clips diagnostic reports')
            sha = git(worktree, 'rev-parse', 'HEAD')
            git(worktree, 'push', 'origin', f'HEAD:refs/heads/{branch}')
            remote_sha = git(worktree, 'ls-remote', '--heads', 'origin', branch).split()[0]
            if remote_sha != sha:
                raise ValueError('Remote changed; reports remain in the outbox for retry')
            sent = args.outbox / 'Sent'
            sent.mkdir(exist_ok=True)
            for file, report in reports:
                destination = sent / file.name
                if destination.exists():
                    if validate(destination.read_bytes()) != report:
                        raise ValueError('Sent receipt conflict')
                    file.unlink()
                else:
                    file.rename(destination)
            print(f'Published and verified https://github.com/eidos-agi/eidos-clips/commit/{sha}')
        finally:
            git(args.repo, 'worktree', 'remove', '--force', str(worktree))


if __name__ == '__main__':
    main()
