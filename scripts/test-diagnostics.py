import importlib.util
import json
import unittest
from unittest import mock
import pathlib
import tempfile
import subprocess
import sys
import shutil
import contextlib
import io
import uuid

spec = importlib.util.spec_from_file_location('agent', 'scripts/diagnostics-agent.py')
agent = importlib.util.module_from_spec(spec); spec.loader.exec_module(agent)

class DiagnosticBoundaryTests(unittest.TestCase):
    def packet(self):
        return dict(schemaVersion=1, reportID=str(uuid.uuid4()), runID=str(uuid.uuid4()), sourceCommit='local', hardwareValidated=False,
                    records=[dict(event='captureStarted', sequence=1, elapsedMs=10, metrics={'width':1920})])
    def test_git_publication_isolated_idempotent_and_conflict_safe(self):
        with tempfile.TemporaryDirectory(prefix='clips-git-test-') as temporary:
            root=pathlib.Path(temporary); remote=root/'remote.git'; repo=root/'repo'; outbox=root/'outbox'; outbox.mkdir()
            def run(*args): return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
            run('git','init','--bare','--initial-branch=main',str(remote))
            run('git','init','--initial-branch=main',str(repo))
            for key,value in [('user.name','Clips Test'),('user.email','test@example.invalid')]: run('git','-C',str(repo),'config',key,value)
            (repo/'README.md').write_text('Fixture repository')
            run('git','-C',str(repo),'add','README.md');run('git','-C',str(repo),'commit','-m','Initial fixture')
            run('git','-C',str(repo),'remote','add','origin',str(remote));run('git','-C',str(repo),'push','origin','main')
            main=run('git','-C',str(repo),'rev-parse','HEAD')
            packet=self.packet();file=outbox/(packet['reportID']+'.json');file.write_text(json.dumps(packet))
            original_git=agent.git
            def transport(repo,*args):
                # Exercise real local Git; only origin identity discovery is substituted. No network call is made.
                if args==('remote','get-url','origin'): return 'https://github.com/eidos-agi/eidos-clips.git'
                return original_git(repo,*args)
            argv=['diagnostics-agent.py','--repo',str(repo),'--outbox',str(outbox),'--publish']
            with mock.patch.object(agent,'git',side_effect=transport),mock.patch.object(sys,'argv',argv),contextlib.redirect_stdout(io.StringIO()):
                agent.main();self.assertFalse(file.exists());self.assertTrue((outbox/'Sent'/file.name).exists())
                branch=run('git','--git-dir',str(remote),'rev-parse','diagnostics/local-reports')
                shutil.copyfile(outbox/'Sent'/file.name,file);agent.main()
                self.assertEqual(run('git','--git-dir',str(remote),'rev-parse','diagnostics/local-reports'),branch)
                packet['records'][0]['metrics']['width']=1280;file.write_text(json.dumps(packet))
                with self.assertRaises(ValueError):agent.main()
                self.assertTrue(file.exists())
                self.assertEqual(run('git','--git-dir',str(remote),'rev-parse','main'),main)
                self.assertEqual(run('git','-C',str(repo),'status','--porcelain'),'')
    def test_valid_minimal(self):
        self.assertEqual(agent.validate(json.dumps(self.packet()))['records'][0]['event'], 'captureStarted')
    def test_content_and_malformed_fields_rejected(self):
        for key, value in [('path', '/Users/private'), ('screenshot', 'data:'), ('token', 'secret')]:
            packet=self.packet(); packet['records'][0][key]=value
            with self.assertRaises(ValueError): agent.validate(json.dumps(packet))
        for value in ['secret', True, float('nan'), float('inf')]:
            packet=self.packet(); packet['records'][0]['metrics']['width']=value
            with self.assertRaises(ValueError): agent.validate(json.dumps(packet))
    def test_duplicate_keys_and_false_hardware_claim_rejected(self):
        raw=json.dumps(self.packet()).replace('"schemaVersion": 1', '"schemaVersion": 1, "schemaVersion": 1')
        with self.assertRaises(ValueError): agent.validate(raw)
        packet=self.packet(); packet['hardwareValidated']=True
        with self.assertRaises(ValueError): agent.validate(json.dumps(packet))

unittest.main()
