#!/usr/bin/env python3
"""Verify a fixed component revision using the xUnit v3 XML reporter."""
import fnmatch
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def run(config, env=None):
    keys = {'repository', 'remote', 'commit', 'runner', 'project', 'class_filter'}
    if not isinstance(config, dict) or set(config) != keys or any(not isinstance(config[k], str) or not config[k].strip() for k in keys):
        raise ValueError('invalid component configuration')
    repo = Path(config['repository'])
    rev = config['commit']
    project = Path(config['project'])
    if not repo.is_absolute() or not re.fullmatch(r'[0-9a-f]{40}', rev) or config['runner'] != 'xunit-v3':
        raise ValueError('unsupported repository, revision or runner')
    if project.is_absolute() or '..' in project.parts or project.suffix != '.csproj' or config['class_filter'].startswith('-'):
        raise ValueError('invalid project or class filter')
    process_env = dict(env if env is not None else os.environ)
    for key in ('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_OBJECT_DIRECTORY', 'GIT_CONFIG'):
        process_env.pop(key, None)
    def git(*args, cwd=repo):
        try:
            return subprocess.check_output(['git', '-C', str(cwd), *args], text=True, stderr=subprocess.PIPE, env=process_env, timeout=60).strip()
        except (subprocess.SubprocessError, OSError) as exc:
            raise ValueError('git operation failed') from exc
    if git('remote', 'get-url', 'origin') != config['remote'] or git('rev-parse', '--verify', rev + '^{commit}') != rev:
        raise ValueError('component origin or commit mismatch')
    tree = git('rev-parse', rev + '^{tree}')
    with tempfile.TemporaryDirectory(prefix='forge-component-story-') as temporary:
        root = Path(temporary)
        clone = root / 'checkout'
        try:
            subprocess.run(['git', 'clone', '--quiet', '--no-checkout', '--no-hardlinks', '--', str(repo), str(clone)], check=True, capture_output=True, env=process_env, timeout=120)
            subprocess.run(['git', '-C', str(clone), 'checkout', '--quiet', '--detach', rev], check=True, capture_output=True, env=process_env, timeout=120)
        except (subprocess.SubprocessError, OSError) as exc:
            raise ValueError('component checkout failed') from exc
        if git('rev-parse', 'HEAD', cwd=clone) != rev or git('rev-parse', 'HEAD^{tree}', cwd=clone) != tree:
            raise ValueError('component checkout mismatch')
        target = clone / project
        if not target.is_file() or target.is_symlink() or not target.resolve().is_relative_to(clone.resolve()):
            raise ValueError('component test project not found')
        report = root / 'report.xml'
        argv = ['dotnet', 'run', '--project', str(project), '--', '-class', config['class_filter'], '-result-xml', str(report)]
        try:
            result = subprocess.run(argv, cwd=clone, env=process_env, capture_output=True, text=True, timeout=600)
        except (subprocess.SubprocessError, OSError) as exc:
            raise ValueError('component test execution failed') from exc
        if result.returncode != 0 or report.is_symlink() or not report.is_file():
            raise ValueError('component tests failed or report missing')
        try:
            xml = ET.parse(report).getroot()
            assemblies = xml.findall('assembly') if xml.tag == 'assemblies' else []
            counts = [{key: int(a.attrib[key]) for key in ('total', 'passed', 'failed', 'errors', 'skipped', 'not-run')} for a in assemblies]
        except (ET.ParseError, ValueError, KeyError, OSError) as exc:
            raise ValueError('invalid xunit report') from exc
        tests = [t for a in assemblies for t in a.iter('test')]
        passed = sum(a['passed'] for a in counts)
        if not assemblies or passed < 1 or any(a['failed'] or a['errors'] or a['skipped'] or a['not-run'] or a['passed'] != a['total'] for a in counts) or len(tests) != sum(a['total'] for a in counts) or sum(t.attrib.get('result') == 'Pass' for t in tests) != passed or any(not fnmatch.fnmatchcase(t.attrib.get('type', ''), config['class_filter']) for t in tests):
            raise ValueError('no matching passing tests or invalid counts')
        if git('rev-parse', 'HEAD', cwd=clone) != rev or git('diff', '--quiet', cwd=clone) or git('diff', '--cached', '--quiet', cwd=clone):
            raise ValueError('component changed during execution')
        return {'repository': config['remote'], 'commit': rev, 'tree': tree, 'runner': 'xunit-v3', 'project': str(project), 'class_filter': config['class_filter'], 'passed': passed}

def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result: raise ValueError('duplicate component configuration key')
        result[key] = value
    return result

if __name__ == '__main__':
    try:
        config = json.load(sys.stdin, object_pairs_hook=reject_duplicate_keys)
        print(json.dumps(run(config), ensure_ascii=False))
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(f'FAIL (component story: {exc})', file=sys.stderr)
        sys.exit(1)
