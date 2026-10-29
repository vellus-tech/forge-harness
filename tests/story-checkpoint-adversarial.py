import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'template/.forge/scripts/spec-verify.sh'

class CheckpointTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='forge-story-adv-')
        self.root = Path(self.temp.name)
        self.d = self.root / '.forge/specs/active/demo'
        self.stories = self.d / 'stories'
        self.stories.mkdir(parents=True)
        (self.root / '.forge/FORGE.md').write_text('---\nruntime:\n  test: "true"\n---\n')
        (self.d / 'manifest.yaml').write_text('status: implementing\ntype: feature\n')
        (self.d / 'tasks.md').write_text('## Wave 1\n- [X] TASK-01 — feita (depende: —)\n## Wave 2\n- [X] TASK-02 — feita (depende: TASK-01)\n')
        self.story('01', 'done', [], '01')
        self.story('02', 'in_progress', ['STORY-01'], '02')
        (self.d / 'verification.yaml').write_text('global sentinel\n')
        self.env = {**os.environ, 'FORGE_ROOT': str(self.root)}

    def tearDown(self):
        self.temp.cleanup()

    def story(self, number, status, dependencies, task):
        (self.stories / f'STORY-{number}.md').write_text(f'---\nstory_id: STORY-{number}\nstatus: {status}\ndepends_on: [{", ".join(dependencies)}]\n---\n- [X] TASK-{task} — tarefa\n')

    def run_story(self, number='02'):
        return subprocess.run(['bash', str(SCRIPT), 'demo', '--story', f'STORY-{number}'], env=self.env, text=True, capture_output=True, timeout=45)

    def test_quoted_command_produces_valid_yaml(self):
        result = self.run_story()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = self.stories / 'STORY-02.verification.yaml'
        check = subprocess.run(['node', '-e', 'require("yaml").parse(require("fs").readFileSync(process.argv[1],"utf8"))', str(receipt)], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)

    def test_transitive_open_task_rejected(self):
        (self.d / 'tasks.md').write_text('## Wave 1\n- [ ] TASK-01 — aberta (depende: —)\n## Wave 2\n- [X] TASK-02 — feita (depende: TASK-01)\n## Wave 3\n- [X] TASK-03 — feita (depende: TASK-02)\n')
        self.story('01', 'todo', [], '01')
        self.story('02', 'done', ['STORY-01'], '02')
        self.story('03', 'in_progress', ['STORY-02'], '03')
        self.assertNotEqual(self.run_story('03').returncode, 0)

    def test_malformed_and_duplicate_frontmatter_rejected(self):
        s = self.stories / 'STORY-01.md'
        original = s.read_text()
        for data in [original.replace('depends_on: []\n', '') + '\ndepends_on: []\n', original.replace('status: done', 'status: done\nstatus: blocked'), original.replace('depends_on: []', 'depends_on: []\ndepends_on: [STORY-99]')]:
            with self.subTest(data=data):
                s.write_text(data)
                self.assertNotEqual(self.run_story().returncode, 0)

    def test_invalid_checkbox_rejected(self):
        with (self.d / 'tasks.md').open('a') as f:
            f.write('- [?] TASK-03 — inválida\n')
        self.assertNotEqual(self.run_story().returncode, 0)

    def test_symlink_inserted_during_check_cannot_overwrite_global_receipt(self):
        ready, release = self.root / 'ready', self.root / 'release'
        os.mkfifo(ready)
        os.mkfifo(release)
        (self.root / '.forge/FORGE.md').write_text(f'---\nruntime:\n  test: echo ready > {ready}; cat {release}\n---\n')
        proc = subprocess.Popen(['bash', str(SCRIPT), 'demo', '--story', 'STORY-02'], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        with ready.open() as f:
            self.assertEqual(f.read().strip(), 'ready')
        (self.stories / 'STORY-02.verification.yaml').symlink_to(self.d / 'verification.yaml')
        release.write_text('release\n')
        proc.communicate(timeout=45)
        self.assertEqual((self.d / 'verification.yaml').read_text(), 'global sentinel\n')

if __name__ == '__main__':
    unittest.main(verbosity=2)
