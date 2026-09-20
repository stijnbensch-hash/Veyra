import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('autodeploy',Path(__file__).with_name('woonkamer_autodeploy.py'))
worker=importlib.util.module_from_spec(spec);spec.loader.exec_module(worker)

class DeploymentChecks(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        worker.STATE=Path(self.temp.name)
        worker.STOP=False
        worker.status=lambda *a,**k:None
        sys.argv=['test','--once']
        self.installations=[]
        worker.deploy=lambda: self.installations.append(True) or True
    def tearDown(self): self.temp.cleanup()
    def test_failed_build_never_installs(self):
        worker.fingerprint=lambda:'one';worker.build=lambda:False
        self.assertEqual(worker.main(),1);self.assertEqual(self.installations,[])
    def test_changed_sources_during_build_never_install_stale_binary(self):
        values=iter(['one','two']);worker.fingerprint=lambda:next(values);worker.build=lambda:True
        self.assertEqual(worker.main(),1);self.assertEqual(self.installations,[])
    def test_success_records_only_deployed_snapshot(self):
        worker.fingerprint=lambda:'one';worker.build=lambda:True
        self.assertEqual(worker.main(),0);self.assertEqual(len(self.installations),1)
        self.assertEqual((worker.STATE/'deployed.sha256').read_text(),'one')
    def test_failed_install_is_not_recorded_as_success(self):
        worker.fingerprint=lambda:'one';worker.build=lambda:True;worker.deploy=lambda:False
        self.assertEqual(worker.main(),1);self.assertFalse((worker.STATE/'deployed.sha256').exists())
    def test_unchanged_snapshot_does_not_reinstall(self):
        (worker.STATE/'deployed.sha256').write_text('one');worker.fingerprint=lambda:'one'
        worker.build=lambda:self.fail('Unchanged source was rebuilt')
        self.assertEqual(worker.main(),0);self.assertEqual(self.installations,[])

unittest.main(argv=['test'])
