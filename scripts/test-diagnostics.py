import importlib.util
import json
import unittest
import uuid

spec = importlib.util.spec_from_file_location('agent', 'scripts/diagnostics-agent.py')
agent = importlib.util.module_from_spec(spec); spec.loader.exec_module(agent)

class DiagnosticBoundaryTests(unittest.TestCase):
    def packet(self):
        return dict(schemaVersion=1, reportID=str(uuid.uuid4()), runID=str(uuid.uuid4()), sourceCommit='local', hardwareValidated=False,
                    records=[dict(event='captureStarted', sequence=1, elapsedMs=10, metrics={'width':1920})])
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
