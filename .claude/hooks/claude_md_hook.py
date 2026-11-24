#!/usr/bin/env python3
"""PreToolUse hook: nudge Claude to bring the CLAUDE.md search tree current before it ships.

Pairs with the agentify-docs skill. Fires on `git commit` and on `git push`, and
injects one reminder naming the CLAUDE.md files the new files affect.

Commit time, not edit time: a directory summary is only wrong once the work is
done, and one reminder per commit costs a fraction of one per edit. Push is the
backstop for commits this hook never saw, made by hand or by a script.

The two triggers read different sources. A commit is judged from the working tree
(staged additions plus untracked files), a push from the files the branch adds
over its upstream. Either way a directory is dropped once the same change touches
the CLAUDE.md that covers it, so a documented addition never nags.

Deliberately ignores in-place edits to existing files: rewriting a function body
rarely changes a one-line directory summary. The hook only detects. Claude judges
whether the summary needs to change and rewrites it.

Self-gating: silent when the command is neither, when cwd is not a git repo, when
nothing was added, or when no ancestor directory has a CLAUDE.md (tree never
built). Never decides the permission, so the command always proceeds. Any
unexpected error exits 0 silently so the hook never blocks a tool call.
"""

import json
import os
import subprocess
import sys

CLAUDE_MD = "CLAUDE.md"
COMMIT_TRIGGER = "git commit"
PUSH_TRIGGER = "git push"
# Porcelain codes for a file that did not exist before: untracked, staged add.
NEW_CODES = {"??", "A ", "AM"}
# Enough dirs to act on, few enough to stay a nudge.
MAX_DIRS = 10
# Named once: every reminder is tagged by emit(), so a skill rename touches one line.
SKILL_TAG = "(agentify-docs skill)"


def git(root, *args):
    return subprocess.run(
        ["git", "-C", root, *args],
        capture_output=True, text=True, check=True,
    ).stdout


def emit(context):
    """Print PreToolUse additionalContext, skill-tagged, and exit.

    No permissionDecision, so the normal permission flow runs and the command
    is never blocked.
    """
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "additionalContext": "%s %s" % (context, SKILL_TAG),
        }
    }))
    sys.exit(0)


def working_tree_changes(root):
    """(paths added, CLAUDE.md paths touched) in the working tree."""
    # -z avoids porcelain's quoting of unusual paths. A rename or copy entry
    # carries its source path as an extra NUL-separated field.
    fields = git(root, "status", "--porcelain", "-z",
                 "--untracked-files=all").split("\0")
    added, touched_md = [], set()
    i = 0
    while i < len(fields):
        entry = fields[i]
        i += 1
        if len(entry) < 4:
            continue
        code, path = entry[:2], entry[3:]
        if code[0] in ("R", "C"):
            i += 1
        if os.path.basename(path) == CLAUDE_MD:
            touched_md.add(path)
            continue
        # --untracked-files=all expands every untracked directory except one git
        # will not descend into, i.e. a nested repo or linked worktree. Those
        # arrive as a single trailing-slash entry and index nothing here.
        if code in NEW_CODES and not path.endswith("/"):
            added.append(path)
    return added, touched_md


def upstream_base(root):
    """Ref the branch will be pushed onto, or None when there is nothing to compare."""
    for args in (("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"),
                 ("rev-parse", "--abbrev-ref", "origin/HEAD")):
        try:
            ref = git(root, *args).strip()
        except subprocess.CalledProcessError:
            continue
        if ref:
            return ref
    return None


def branch_changes(root):
    """(paths added, CLAUDE.md paths touched) by the commits the push would send."""
    base = upstream_base(root)
    if base is None:
        return [], set()
    # Three-dot: only what this branch added since it forked, so a branch that
    # trails its upstream does not answer for the other side's files.
    def names(*extra):
        out = git(root, "diff", "--name-only", "-z", *extra,
                  "%s...HEAD" % base)
        return [p for p in out.split("\0") if p]

    added = [p for p in names("--diff-filter=A")
             if os.path.basename(p) != CLAUDE_MD]
    touched_md = {p for p in names() if os.path.basename(p) == CLAUDE_MD}
    return added, touched_md


def nearest_claude_md(file_dir, root):
    """Closest CLAUDE.md at or above file_dir, stopping at the repo root."""
    d = file_dir
    while True:
        candidate = os.path.join(d, CLAUDE_MD)
        if os.path.isfile(candidate):
            return candidate
        if d == root:
            return None
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return
    payload = json.loads(raw)

    command = (payload.get("tool_input") or {}).get("command") or ""
    # A commit inside a longer command line wins: the working tree sees
    # everything the push would carry, and more.
    if COMMIT_TRIGGER in command:
        collect, occasion = working_tree_changes, "commit"
    elif PUSH_TRIGGER in command:
        collect, occasion = branch_changes, "push"
    else:
        return

    cwd = payload.get("cwd") or os.getcwd()
    try:
        # realpath so paths share a symlink-resolved prefix with git's toplevel
        # (e.g. macOS /var -> /private/var), keeping relative paths clean.
        root = os.path.realpath(git(cwd, "rev-parse", "--show-toplevel").strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return  # not a git repo

    added, touched_md = collect(root)
    covered, uncovered = {}, {}
    for rel_file in added:
        rel_dir = os.path.dirname(rel_file)
        # lint_claude_md.py never indexes a dot-directory, so nothing under one
        # can need a CLAUDE.md. `.claude/skills/` in particular is written by the
        # build, contrib, and boundaries phases. Judged relative to the repo
        # root, so a checkout that itself lives under a dot-directory
        # (~/.local/src/repo) still gets nudges.
        if any(part.startswith(".") for part in rel_dir.split(os.sep) if part):
            continue
        if rel_dir in covered or rel_dir in uncovered:
            continue
        file_dir = os.path.join(root, rel_dir) if rel_dir else root
        nearest = nearest_claude_md(file_dir, root)
        if nearest is None:
            continue  # no CLAUDE.md tree here, skill hasn't been run
        rel_md = os.path.relpath(nearest, root)
        if rel_md in touched_md:
            continue  # already answered for, in this same change
        # A hit in the file's own directory means that directory is indexed.
        if os.path.dirname(nearest) == file_dir:
            covered[rel_dir] = rel_md
        else:
            uncovered[rel_dir] = rel_md

    lines = []
    for rel_dir, rel_md in sorted(covered.items()):
        lines.append(
            f"- `{rel_dir or '.'}/` gained files and is indexed by `{rel_md}`. "
            f"Update that summary if it is now inaccurate."
        )
    for rel_dir, rel_md in sorted(uncovered.items()):
        lines.append(
            f"- `{rel_dir}/` gained files and has no CLAUDE.md, but sits under "
            f"the tree indexed by `{rel_md}`. If it is now a meaningful "
            f"directory, add a CLAUDE.md there and link it from `{rel_md}`."
        )
    if not lines:
        return

    dropped = len(lines) - MAX_DIRS
    lines = lines[:MAX_DIRS]
    if dropped > 0:
        lines.append(f"- ...and {dropped} more directories.")

    tail = ("Bring those files current before committing."
            if occasion == "commit" else
            "Bring those files current and commit them before pushing.")
    emit(
        f"About to {occasion}. New files landed in directories the CLAUDE.md "
        "search tree covers:\n" + "\n".join(lines) +
        f"\n{tail} Edit only what is now inaccurate."
    )


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never let a hook error block the tool call.
        sys.exit(0)
