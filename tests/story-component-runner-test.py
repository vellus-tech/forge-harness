import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'template/.forge/scripts/lib/component-story-runner.py'
spec = importlib.util.spec_from_file_location('component_runner', MODULE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)

class ComponentRunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'source'
        self.repo.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Teste')
        self.git('config', 'user.email', 'teste@example.invalid')
        self.git('remote', 'add', 'origin', 'https://example.invalid/team/repo.git')
        (self.repo / 'test.csproj').write_text('fixed revision')
        self.git('add', 'test.csproj')
        self.git('commit', '-qm', 'fixture')
        self.revision = self.git('rev-parse', 'HEAD')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        executable = self.bin / 'dotnet'
        executable.write_text('''#!/usr/bin/env python3
import os,sys
from pathlib import Path
args=sys.argv[1:]
if os.environ.get('TEST_EXIT'): raise SystemExit(7)
if not Path('test.csproj').read_text() == 'fixed revision': raise SystemExit(8)
if os.environ.get('TEST_NO_REPORT'): raise SystemExit(0)
report=Path(args[args.index('-result-xml')+1])
report.write_text(os.environ.get('TEST_XML', '<assemblies><assembly total="1" passed="1" failed="0" errors="0" skipped="0" not-run="0"><test type="Example.DomainTests" result="Pass"/></assembly></assemblies>'))
''')
        executable.chmod(0o755)
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'])
        self.config = {'repository':str(self.repo), 'remote':'https://example.invalid/team/repo.git', 'commit':self.revision, 'runner':'xunit-v3', 'project':'test.csproj', 'class_filter':'*DomainTests*'}
    def tearDown(self): self.tmp.cleanup()
    def git(self, *args): return subprocess.check_output(['git', '-C', str(self.repo), *args], text=True).strip()
    def execute(self, config=None, env=None): return runner.run(config or self.config, env=env or self.env)
    def test_pins_commit_and_ignores_uncommitted_changes(self):
        (self.repo / 'test.csproj').write_text('uncommitted')
        result = self.execute()
        self.assertIsNotNone(result)
        self.assertEqual(result['commit'], self.revision)
        self.assertEqual(result['tree'], self.git('rev-parse', self.revision + '^{tree}'))
        self.assertEqual(result['passed'], 1)
        self.assertEqual((self.repo / 'test.csproj').read_text(), 'uncommitted')
    def test_rejects_malformed_revision_remote_and_project(self):
        for key, value in [('commit', self.revision[:8]), ('remote', 'https://other.invalid/repo'), ('project', '../outside.csproj'), ('class_filter', '')]:
            with self.subTest(key=key), self.assertRaises(ValueError): self.execute(dict(self.config, **{key:value}))
    def test_checkpoint_records_component_and_preserves_global(self):
        forge = self.root / 'aggregate' / '.forge'
        change = forge / 'specs' / 'active' / 'demo'
        stories = change / 'stories'
        stories.mkdir(parents=True)
        (forge / 'FORGE.md').write_text('---\nruntime:\n  test: "false"\n---\n')
        (change / 'manifest.yaml').write_text('status: implementing\ntype: feature\n')
        (change / 'tasks.md').write_text('## Wave 1\n- [X] TASK-01 — feita (rastreia: REQ-01; paths: src/a; depende: —)\n## Wave 2\n- [ ] TASK-02 — pendente (rastreia: REQ-01; paths: src/b; depende: TASK-01)\n')
        (stories / 'STORY-01.md').write_text('---\nstory_id: STORY-01\nstatus: in_progress\ndepends_on: []\ncomponent_test: true\n---\n- [X] TASK-01 — feita\n')
        (stories / 'STORY-02.md').write_text('---\nstory_id: STORY-02\nstatus: todo\ndepends_on: [STORY-01]\n---\n- [ ] TASK-02 — pendente\n')
        config = stories / 'STORY-01.component.json'
        config.write_text(json.dumps(self.config))
        (change / 'verification.yaml').write_text('global sentinel\n')
        verify = MODULE.parents[1] / 'spec-verify.sh'
        env = dict(self.env, FORGE_ROOT=str(forge.parent))
        def check(): return subprocess.run(['bash', str(verify), 'demo', '--story', 'STORY-01'], env=env, capture_output=True, text=True)
        result = check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = json.loads((stories / 'STORY-01.verification.yaml').read_text())
        self.assertEqual(receipt['component']['commit'], self.revision)
        self.assertEqual(receipt['component']['passed'], 1)
        self.assertEqual((change / 'verification.yaml').read_text(), 'global sentinel\n')
        config.unlink()
        self.assertNotEqual(check().returncode, 0)
        self.assertFalse((stories / 'STORY-01.verification.yaml').exists())
        config.write_text(json.dumps(dict(self.config, commit=self.revision[:8])))
        self.assertNotEqual(check().returncode, 0)
        self.assertEqual((change / 'verification.yaml').read_text(), 'global sentinel\n')
        global_result = subprocess.run(['bash', str(verify), 'demo'], env=env, capture_output=True, text=True)
        self.assertNotEqual(global_result.returncode, 0)

    def test_fails_closed_on_bad_results(self):
        for var, val in [('TEST_EXIT','1'), ('TEST_NO_REPORT','1'), ('TEST_XML','<assemblies><assembly total="0" passed="0" failed="0" errors="0" skipped="0" not-run="0"/></assemblies>'), ('TEST_XML','<assemblies><assembly total="1" passed="0" failed="1" errors="0" skipped="0" not-run="0"/></assemblies>'), ('TEST_XML','not xml')]:
            with self.subTest(var=var,val=val), self.assertRaises(ValueError): self.execute(env=dict(self.env, **{var:val}))

if __name__ == '__main__': unittest.main()
