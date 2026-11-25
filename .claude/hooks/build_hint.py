#!/usr/bin/env python3
"""PreToolUse hook: point Claude at the repo's build-run-test skill.

Pairs with the agentify-build skill. The skill holds what a Makefile target name
cannot carry: toolchain versions, ports, prereqs, offline-test handling. A
skill only loads when the model picks it. This hook makes that pick deterministic:
before the first build-shaped Bash command of a session it injects one line naming
the skill.

Never blocks. The command runs either way. The hook only adds context.

Fires once per session, keyed on session_id, so a build-fix loop costs one
reminder. Silent when the skill is absent, when the command is not build-shaped,
and on any error.
"""

import json
import os
import re
import sys
import tempfile

# The skill this hook advertises. Renaming it touches this line only.
SKILL_NAME = "build-run-test"
SKILL_REL = os.path.join(".claude", "skills", SKILL_NAME, "SKILL.md")

# Build tools whose every invocation is build-shaped. Deliberately generic and
# deliberately wide: what this hook has to catch is an agent typing `./gradlew
# test` on instinct in a repo it has not read yet. Narrowing the table to the
# build systems a repo actually uses would miss exactly that case, and a false
# positive here costs one line, once per session.
BUILD_HEADS = {"make", "gmake", "gradle", "gradlew", "mvn", "mvnw", "sbt",
               "bazel", "buck", "ninja", "cmake", "tox", "nox", "pytest",
               "rake", "meson", "scons", "just", "task", "earthly", "jest",
               "vitest", "rspec", "phpunit", "tsc", "nx", "turbo", "lerna"}
# Tools that are build-shaped only under certain subcommands: `go test` is,
# `go fmt` is not, and `python3 deploy.py` is not a build at all.
BUILD_SUBCOMMANDS = {
    "cargo": {"build", "test", "run", "check", "bench"},
    "go": {"build", "test", "run", "install"},
    "dotnet": {"build", "test", "run", "publish"},
    "swift": {"build", "test", "run"},
    "npm": {"run", "test", "start", "ci", "install", "build"},
    "pnpm": {"run", "test", "start", "install", "build"},
    "yarn": {"run", "test", "start", "install", "build"},
    "bun": {"run", "test", "install", "build"},
    "docker": {"build", "compose"},
    "podman": {"build", "compose"},
    "poetry": {"run", "install", "build"},
    "uv": {"run", "sync", "build"},
    "pdm": {"run", "install", "build"},
    "bundle": {"exec", "install"},
    "mix": {"test", "compile", "run"},
    "stack": {"build", "test", "run"},
    "python": {"-m"},
    "python3": {"-m"},
}
# `python -m X` is a build only for these modules.
PYTHON_MODULES = {"pytest", "unittest", "build", "tox", "nox", "py_compile"}

SEPARATORS = re.compile(r"&&|\|\||;|\||&|\n")
ENV_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=\S*\s+")
# Wrappers Claude Code strips before matching. Strip them here for the same reason.
WRAPPERS = {"timeout", "time", "nice", "nohup", "stdbuf", "command", "builtin",
            "noglob", "xargs", "env", "sudo"}
DURATION = re.compile(r"^\d+(\.\d+)?[smhd]?$")
SAFE_ID = re.compile(r"[^A-Za-z0-9._-]")


def head_and_rest(part):
    """Bare command name and its remaining words, wrappers and env vars removed."""
    while True:
        part = part.strip()
        while ENV_ASSIGN.match(part):
            part = ENV_ASSIGN.sub("", part, count=1).strip()
        words = part.split()
        if not words:
            return "", []
        base = os.path.basename(words[0].rstrip("/")) or words[0]
        if base not in WRAPPERS:
            return base, words[1:]
        rest = words[1:]
        while rest and rest[0].startswith("-"):
            rest.pop(0)
        if base in ("timeout", "nice") and rest and DURATION.match(rest[0]):
            rest.pop(0)
        part = " ".join(rest)


def is_build_command(command):
    """True when any part of a compound command builds, runs, or tests the repo."""
    for part in SEPARATORS.split(command):
        base, rest = head_and_rest(part)
        if not base:
            continue
        if base in BUILD_HEADS:
            return True
        wanted = BUILD_SUBCOMMANDS.get(base)
        if not wanted:
            continue
        # The first non-flag word, except for `python -m <module>`.
        verb = next((w for w in rest if not w.startswith("-")), "")
        if base in ("python", "python3"):
            if "-m" in rest and verb in PYTHON_MODULES:
                return True
            continue
        if verb in wanted:
            return True
    return False


def skill_root(start):
    """The project holding the skill, or None.

    Claude Code sets CLAUDE_PROJECT_DIR for hooks, and the skill always sits at
    the repo root, so that answers it outright. Walking up from cwd is the
    fallback, and it stops at the project rather than running to `/`: above the
    project any hit belongs to some other checkout, and the relative path this
    hook prints would not resolve from here.
    """
    project = os.environ.get("CLAUDE_PROJECT_DIR")
    if project:
        project = os.path.realpath(project)
        return project if os.path.isfile(os.path.join(project, SKILL_REL)) else None

    directory = os.path.realpath(start or ".")
    while True:
        if os.path.isfile(os.path.join(directory, SKILL_REL)):
            return directory
        if os.path.isdir(os.path.join(directory, ".git")) or os.path.isfile(
                os.path.join(directory, ".git")):
            return None                  # repo root reached, no skill here
        parent = os.path.dirname(directory)
        if parent == directory:
            return None
        directory = parent


def already_fired(session_id):
    """True when this session was already reminded. Marks it when it was not."""
    if not session_id:
        return False
    marker = os.path.join(tempfile.gettempdir(),
                          "agentify-build-hint-%s" % SAFE_ID.sub("_", session_id))
    if os.path.exists(marker):
        return True
    with open(marker, "w") as handle:
        handle.write("")
    return False


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        return
    payload = json.loads(raw)
    if payload.get("tool_name") != "Bash":
        return
    command = (payload.get("tool_input") or {}).get("command") or ""
    if not command or not is_build_command(command):
        return
    if not skill_root(payload.get("cwd")):
        return                       # skill not installed here, nothing to point at
    if already_fired(payload.get("session_id")):
        return

    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext":
            "This repo documents how it builds, runs, and tests in the "
            "`%s` skill (%s): toolchain versions, ports, prereqs, and gotchas a "
            "command name does not carry. Load it before going further. "
            "(agentify-build skill)" % (SKILL_NAME, SKILL_REL)}}))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # Never let a hook error block the tool call.
        sys.exit(0)
