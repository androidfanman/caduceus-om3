import json, pathlib, subprocess, sys, tempfile, unittest

TEST_DIR = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TEST_DIR))
import pr_gate  # noqa: E402

GIT = ['git', '-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'commit.gpgsign=false']
HOOK = TEST_DIR / 'pr_gate.py'
FIRMWARE_FILE = 'firmware/a.txt'
DOCS_FILE = 'docs/a.md'


def git(cwd, *args):
    subprocess.run([*GIT, *args], cwd=cwd, check=True, capture_output=True)


def commit(cwd, path):
    f = pathlib.Path(cwd, path)
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text('x\n')
    git(cwd, 'add', path)
    git(cwd, 'commit', '-q', '-m', f'change {path}')


def head(cwd):
    return pr_gate.git('rev-parse', 'HEAD', cwd=cwd)


class Repo(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.cwd = tmp.name
        git(self.cwd, 'init', '-q')
        git(self.cwd, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        commit(self.cwd, 'README.md')
        self.main_sha = head(self.cwd)
        git(self.cwd, 'checkout', '-q', '-b', 'feature')


class ReasonTests(Repo):
    def test_tested_change_without_pass_is_refused(self):
        commit(self.cwd, FIRMWARE_FILE)
        self.assertIn('has not passed', pr_gate.reason(self.cwd))

    def test_tested_change_with_pass_on_older_head_is_refused(self):
        commit(self.cwd, FIRMWARE_FILE)
        pr_gate.pass_path(self.cwd).write_text(json.dumps({'head': self.main_sha}))
        self.assertIn('last passed', pr_gate.reason(self.cwd))

    def test_tested_change_with_pass_on_head_is_allowed(self):
        commit(self.cwd, FIRMWARE_FILE)
        pr_gate.pass_path(self.cwd).write_text(json.dumps({'head': head(self.cwd)}))
        self.assertIsNone(pr_gate.reason(self.cwd))

    def test_untested_change_is_allowed(self):
        commit(self.cwd, DOCS_FILE)
        self.assertIsNone(pr_gate.reason(self.cwd))

    def test_missing_main_branch_is_refused(self):
        commit(self.cwd, FIRMWARE_FILE)
        git(self.cwd, 'branch', '-m', 'main', 'trunk')
        self.assertIn('no main branch', pr_gate.reason(self.cwd))


class OpensPrTests(unittest.TestCase):
    def test_bash_gh_pr_create_opens_pr(self):
        call = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr create --fill'}}
        self.assertTrue(pr_gate.opens_pr(call))

    def test_bash_chained_gh_pr_create_opens_pr(self):
        call = {'tool_name': 'Bash', 'tool_input': {'command': 'cd x && gh pr create'}}
        self.assertTrue(pr_gate.opens_pr(call))

    def test_bash_gh_pr_new_alias_opens_pr(self):
        self.assertTrue(pr_gate.opens_pr({'tool_name': 'Bash', 'tool_input': {'command': 'gh pr new --fill'}}))

    def test_bash_gh_repo_flag_pr_create_opens_pr(self):
        call = {'tool_name': 'Bash', 'tool_input': {'command': 'gh -R a/b pr create'}}
        self.assertTrue(pr_gate.opens_pr(call))

    def test_bash_gh_pr_list_then_echo_does_not_open_pr(self):
        call = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr list && echo pr create'}}
        self.assertFalse(pr_gate.opens_pr(call))

    def test_bash_ls_does_not_open_pr(self):
        self.assertFalse(pr_gate.opens_pr({'tool_name': 'Bash', 'tool_input': {'command': 'ls'}}))

    def test_bash_gh_pr_list_does_not_open_pr(self):
        call = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr list'}}
        self.assertFalse(pr_gate.opens_pr(call))

    def test_mcp_create_pull_request_opens_pr(self):
        self.assertTrue(pr_gate.opens_pr({'tool_name': 'mcp__github__create_pull_request', 'tool_input': {}}))

    def test_read_tool_does_not_open_pr(self):
        self.assertFalse(pr_gate.opens_pr({'tool_name': 'Read', 'tool_input': {'file_path': 'a.txt'}}))


class HookTests(Repo):
    def test_hook_denies_gh_pr_create_for_untested_head(self):
        commit(self.cwd, FIRMWARE_FILE)
        payload = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr create --fill'}, 'cwd': self.cwd}
        r = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload),
                           capture_output=True, text=True, check=True)
        out = json.loads(r.stdout)['hookSpecificOutput']
        self.assertEqual(out['permissionDecision'], 'deny')
        self.assertIn('has not passed', out['permissionDecisionReason'])

    def test_hook_denies_when_check_crashes(self):
        commit(self.cwd, FIRMWARE_FILE)
        pr_gate.pass_path(self.cwd).write_text('"not an object"')
        payload = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr create'}, 'cwd': self.cwd}
        r = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload),
                           capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(r.stdout)['hookSpecificOutput']['permissionDecision'], 'deny')


NO_NUMPY = 'import sys, runpy; sys.modules["numpy"] = None; runpy.run_path(sys.argv[1], run_name="__main__")'


class StdlibOnlyTests(Repo):
    def test_hook_needs_no_numpy(self):
        commit(self.cwd, FIRMWARE_FILE)
        payload = {'tool_name': 'Bash', 'tool_input': {'command': 'gh pr create --fill'}, 'cwd': self.cwd}
        r = subprocess.run([sys.executable, '-c', NO_NUMPY, str(HOOK)], input=json.dumps(payload),
                           capture_output=True, text=True, check=True)
        why = json.loads(r.stdout)['hookSpecificOutput']['permissionDecisionReason']
        self.assertNotIn('check itself failed', why)
        self.assertIn('has not passed', why)

    def test_constants_match_emu_test(self):
        try:
            import emu_test
        except ImportError:
            self.skipTest('emu_test needs numpy')
        self.assertEqual(pr_gate.TESTED_PATHS, emu_test.TESTED_PATHS)
        self.assertEqual(pr_gate.PASS_FILE, emu_test.PASS_FILE)


if __name__ == '__main__':
    unittest.main()
