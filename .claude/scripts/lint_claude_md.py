#!/usr/bin/env python3
"""Plan and check a repository's bottom-up CLAUDE.md navigation tree.

One file on purpose: agentified repos vendor it into `.claude/scripts/` so their
`make lint-docs` and CI work with nothing installed, and a single file is a single
thing to re-copy when this one changes.

Subcommands:

  plan       <root>   JSON plan of the tree: every meaningful directory, deepest
                      first, with its direct files, its meaningful children, and
                      precomputed markdown link parts. Drives the writing step.
  structure  <root>   Findings where the tree does not match the plan.
  dupes      <root>   Findings where a parent link restates its child's summary.
  length     <root>   Findings where a file's own prose exceeds the word ceiling.
  check      <root>   structure, dupes, length, all three always run.
  count      <path>.. Words, headroom, and the heaviest blocks. Takes files,
                      directories, or `-` to measure a draft on stdin before it
                      is written. Exit 1 when anything is over.

`<root>` defaults to ".". Exit 0 = clean, 1 = findings, 2 = could not run.

A directory is "meaningful" (gets its own CLAUDE.md) when it is the repo root,
directly contains 2+ files, contains a Claude-functionality marker file (a skill
`SKILL.md` etc., see CLAUDE_MARKER_FILES), or has at least one meaningful
descendant. The marker rule ensures a skill/hook/plugin directory is always
indexed even when it holds a single manifest file. This skips near-empty leaf
folders that would only add noise. Test and build-support directories (gradle
wrapper etc.) are excluded: only source, script, and documentation directories are
indexed. Pass-through directories (no direct files of their own, any number of
children, e.g. `skills/` or a Java/Kotlin package prefix) are collapsed: they get
no CLAUDE.md and parents link through them.

File scope comes from `git ls-files` when available, which respects .gitignore and
lists only tracked files. Otherwise it falls back to os.walk with a skip list.
"""

import json
import os
import re
import subprocess
import sys

# Directory names never traversed, even if not gitignored (e.g. committed deps).
SKIP_DIRS = {
    "node_modules", "vendor", "dist", "build", "target", "out",
    "__pycache__", ".venv", "venv", ".tox", ".mypy_cache", ".pytest_cache",
    "coverage", ".next", ".nuxt", ".gradle", "bin", "obj",
}

# Test directories excluded from the tree: index source, scripts, and docs only.
TEST_DIRS = {
    "test", "tests", "__tests__", "spec", "specs", "e2e",
    "testdata", "test-data", "__mocks__", "integration-tests",
}

# Build-support directories excluded from the tree (wrappers, build tooling).
SUPPORT_DIRS = {"gradle", "buildSrc", "mvn"}

# Marker files that denote a Claude-functionality directory (skill, plugin,
# etc.). A directory containing any of these is always meaningful, even with
# fewer than 2 files, so its CLAUDE.md documents the unit for navigation.
CLAUDE_MARKER_FILES = {"SKILL.md"}

CLAUDE_MD = "CLAUDE.md"


# --- file scope ------------------------------------------------------------


def tracked_files(root):
    """Return repo-relative file paths from git, or None if not a git repo."""
    try:
        out = subprocess.run(
            ["git", "-C", root, "ls-files"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return [line for line in out.splitlines() if line]


def excluded(name):
    """True for a directory the tree never enters."""
    return (name.startswith(".") or name in SKIP_DIRS
            or name in TEST_DIRS or name in SUPPORT_DIRS)


def in_skipped_path(rel_path):
    """True if any segment of the path is an excluded directory."""
    return any(excluded(part) for part in rel_path.split(os.sep))


def walk_in_scope(root):
    """Yield (repo-relative dir, filenames) per in-scope dir, excluded ones pruned."""
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not excluded(d)]
        rel = os.path.relpath(dirpath, root)
        yield ("" if rel == "." else rel), filenames


def plan_files(root):
    """Files the plan considers: git's list when there is one, minus exclusions."""
    files = tracked_files(root)
    if files is None:
        files = [os.path.join(rel, name) if rel else name
                 for rel, names in walk_in_scope(root) for name in names]
    return [f for f in files if not in_skipped_path(f)]


def claude_md_dirs(root):
    """In-scope dirs holding a CLAUDE.md, read from disk so uncommitted ones count."""
    return [rel for rel, names in walk_in_scope(root) if CLAUDE_MD in names]


# --- plan ------------------------------------------------------------------


def build(root):
    """The tree plan: meaningful dirs deepest-first, with files and child links."""
    # Map each directory -> its direct files (relative names only).
    direct_files = {}
    all_dirs = set([""])  # "" is the repo root
    for f in plan_files(root):
        base = os.path.basename(f)
        if base == CLAUDE_MD:
            continue
        d = os.path.dirname(f)
        direct_files.setdefault(d, []).append(base)
        # Register every ancestor directory.
        parts = d.split(os.sep) if d else []
        for i in range(len(parts) + 1):
            all_dirs.add(os.sep.join(parts[:i]))

    # Immediate children of each directory.
    children = {d: [] for d in all_dirs}
    for d in all_dirs:
        if d == "":
            continue
        children[os.path.dirname(d)].append(d)

    def depth(d):
        return 0 if d == "" else d.count(os.sep) + 1

    # Deepest first, path as a stable tiebreaker so output is deterministic
    # (all_dirs is a set, whose iteration order varies with hash seeding).
    ordered = sorted(all_dirs, key=lambda d: (-depth(d), d))

    # Meaningful: 2+ direct files, a marker file, any meaningful descendant, or
    # the root. Computed bottom-up, so a child's verdict is already known.
    meaningful = {}
    for d in ordered:
        has_files = len(direct_files.get(d, [])) >= 2
        has_marker = any(f in CLAUDE_MARKER_FILES for f in direct_files.get(d, []))
        has_meaningful_child = any(meaningful.get(c) for c in children[d])
        meaningful[d] = d == "" or has_files or has_marker or has_meaningful_child

    # Collapse pass-through dirs: a non-root dir with no direct files gets no
    # CLAUDE.md of its own, and its parent links straight through to whatever is
    # below (e.g. src/main/kotlin/com/yahoo -> the real package root).
    #
    # Any child count, not just one. A dir with nothing of its own to describe can
    # only restate its children, which is a hop that costs a file read and adds no
    # information. `skills/` holding four skill dirs is the case in point.
    def collapsed(d):
        return d != "" and not direct_files.get(d)

    def resolve(d):
        """The dirs a parent should link in place of child d, post-collapse."""
        if not collapsed(d):
            return [d]
        out = []
        for c in children[d]:
            if meaningful[c]:
                out.extend(resolve(c))
        return out

    result = []
    for d in ordered:
        if not meaningful[d] or collapsed(d):
            continue
        kids = sorted({k for c in children[d] if meaningful[c] for k in resolve(c)})
        abs_dir = root if d == "" else os.path.join(root, d)
        # Precomputed markdown link parts, relative to this dir. Collapsed
        # pass-through chains make these multi-segment (kotlin/com/yahoo/...).
        child_links = [
            {
                "path": c,
                "text": "%s/" % os.path.relpath(c, d or "."),
                "href": "%s/%s" % (os.path.relpath(c, d or "."), CLAUDE_MD),
            }
            for c in kids
        ]
        result.append({
            "path": d,
            "files": sorted(direct_files.get(d, [])),
            "children": kids,
            "child_links": child_links,
            "has_claude_md": os.path.isfile(os.path.join(abs_dir, CLAUDE_MD)),
        })

    return {"root": os.path.abspath(root), "dirs": result}


# --- structure -------------------------------------------------------------

HEADING = "## Subdirectories"
ANY_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def structure_findings(root):
    """Where the tree on disk does not match the plan.

    Companion to the duplication check. That one catches a parent repeating a
    child's summary. This one catches a parent not linking the child at all,
    which is what breaks navigation.
    """
    tree = build(root)
    problems = []

    for entry in tree["dirs"]:
        rel = entry["path"]
        md = os.path.join(root, rel, CLAUDE_MD) if rel else os.path.join(root, CLAUDE_MD)
        where = (rel + "/" if rel else "") + CLAUDE_MD

        if not os.path.isfile(md):
            problems.append("%s: missing, but the dir is meaningful" % where)
            continue

        links = entry["child_links"]
        if not links:
            continue

        with open(md, encoding="utf-8") as fh:
            text = fh.read()
        hrefs = set(ANY_LINK.findall(text))

        if HEADING not in text:
            problems.append("%s: has %d child dir(s) but no `%s` heading"
                            % (where, len(links), HEADING))

        for link in links:
            if link["href"] not in hrefs:
                problems.append("%s: does not link child `%s` (expected `%s`)"
                                % (where, link["text"], link["href"]))

        # A link is only navigation if its target exists.
        for href in sorted(hrefs):
            if not href.endswith(CLAUDE_MD):
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(md), href))
            if not os.path.isfile(target):
                problems.append("%s: link `%s` points at a file that does not exist"
                                % (where, href))

    # The other direction: a CLAUDE.md the plan never asked for, in a dir that was
    # collapsed or called too thin. Its content is a hop the parent could hold.
    # Excluded dirs (dot-dirs, tests, build support) are out of scope either way.
    listed = {e["path"] for e in tree["dirs"]}
    for rel in claude_md_dirs(root):
        if rel not in listed:
            problems.append("%s: in a dir the plan skipped, so fold it into the "
                            "parent and delete it" % os.path.join(rel, CLAUDE_MD))

    return problems


def report_structure(root):
    problems = structure_findings(root)
    if not problems:
        print("OK: every meaningful dir has a CLAUDE.md indexing its children")
        return 0
    print("CLAUDE.md tree structure problems:")
    for p in problems:
        print("  - " + p)
    return 1


# --- duplication -----------------------------------------------------------

# A "pointer" longer than this many chars is almost certainly a pasted summary.
MAX_POINTER_CHARS = 70
# Word-overlap (Jaccard) at or above this between pointer and child summary =
# near-copy. A correct short pointer reuses the child's role words (child leads
# with the same phrase), so a subset alone is fine. Only high overlap = a copy.
JACCARD_FLAG = 0.6

# - [`child/`](child/CLAUDE.md) — description text
SUB_LINK = re.compile(r"^\s*-\s*\[[^\]]+\]\(([^)]+)\)\s*[-—:]+\s*(.*\S)\s*$")
STOP = {
    "a", "an", "the", "and", "or", "of", "for", "to", "in", "on", "by", "with",
    "per", "via", "its", "plus",
}


def words(text):
    """Lowercase content words, punctuation, and stop words dropped."""
    toks = re.findall(r"[A-Za-z0-9_]+", text.lower())
    return {t for t in toks if t not in STOP and len(t) > 1}


def summary_line(path):
    """First non-empty body line of a CLAUDE.md (the dir's own summary)."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        return None
    for line in lines:
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        return s
    return None


def sub_links(path):
    """(child_claude_md_path, description) for each Subdirectories link."""
    out = []
    in_sub = False
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.strip()
            if s.startswith("## "):
                in_sub = s.lower().startswith("## subdirectories")
                continue
            if not in_sub:
                continue
            m = SUB_LINK.match(line)
            if m:
                out.append((m.group(1), m.group(2)))
    return out


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def report_dupes(root):
    """Flag parent links that restate the child's own summary.

    The tree's rule: a directory's authoritative summary lives only in its own
    CLAUDE.md. A parent's Subdirectories link must be a SHORT POINTER (the
    child's role in a few words), never a paste of the child's summary. Agents
    writing the tree keep violating that by prose alone, hence this backstop.
    """
    findings = []
    for rel in claude_md_dirs(root):
        parent = os.path.join(root, rel, CLAUDE_MD)
        for href, desc in sub_links(parent):
            child_summary = summary_line(
                os.path.normpath(os.path.join(root, rel, href)))
            if child_summary is None:
                continue
            dw, cw = words(desc), words(child_summary)
            j = jaccard(dw, cw)
            too_long = len(desc) > MAX_POINTER_CHARS
            if j >= JACCARD_FLAG or too_long:
                reason = (
                    "identical words" if dw == cw
                    else "%.0f%% word overlap" % (j * 100) if j >= JACCARD_FLAG
                    else "%d chars (pointer should be <= %d)"
                    % (len(desc), MAX_POINTER_CHARS)
                )
                findings.append((parent, href, reason, desc, child_summary))

    if not findings:
        print("OK: no parent/child duplication found")
        return 0

    print("Duplication found in %d link(s):\n" % len(findings))
    for parent, href, reason, desc, child_summary in findings:
        print("  %s" % parent)
        print("    link -> %s  (%s)" % (href, reason))
        print("    parent pointer: %s" % desc)
        print("    child summary : %s" % child_summary)
        print("    fix: shorten the parent pointer to the child's role only.\n")
    return 1


# --- length ----------------------------------------------------------------

# Floor on a CLAUDE.md's own prose, in words, and the whole budget for a file that
# describes nothing item by item. Exempt: the Subdirectories list and the root's
# maintenance note, which grow with the repo rather than with what the file chose to
# say. A ceiling, not a target. Most files stay far under it: a one-line summary plus
# links is the format.
BODY_WORD_LIMIT = 128

# A leaf index earns room per file it describes, since its length is set by how many
# files sit beside it rather than by how much it chose to say. A flat ceiling taxed
# exactly the files doing their job: on this repo the six index files sat at 118 to
# 120 and every edit to one had to buy its words back out of another entry.
#
# Sixteen is one line: a name, then a clause or two saying what it is for. The base
# covers any sentence before the list. A file that lists nothing gets the floor and
# nothing more, so prose cannot buy room by adding bullets.
ENTRY_BASE = 48
ENTRY_WORDS = 16

# An item that describes a file, which is a bullet opening with a code span. Prose
# bullets do not earn room, since they are what the floor is already for.
DESCRIBED = re.compile(r"^\s*[-*+]\s+`")

# The names at the head of such a bullet, before the dash that starts its description.
# One line often covers a family, and charging it for one file while it describes four
# is the flat ceiling again in miniature. Stopping at the dash is what keeps a code
# span inside the description from earning room: `--out DIR` in a clause is the file
# explaining itself, not another file.
NAMED = re.compile(r"`([^`\n]+)`")
HEAD = re.compile(r"\s+[\u2014-]\s")

EXEMPT_HEADINGS = {"subdirectories", "maintaining this tree"}

HEADING_RE = re.compile(r"^(#+)\s+(.*\S)\s*$")

LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+")


def counted_lines(text):
    """The lines that count toward the ceiling, in order.

    A heading at level 1 or 2 opens or closes an exemption. Deeper headings stay
    inside whatever section they belong to.

    No heading counts, at any level. A section title is navigation rather than
    something the file chose to say, and charging for it taxes the split that makes
    a file readable: three short sections cost more than one long one saying the
    same. `lint_readme.py` has always dropped them, and this is the same rule.
    """
    kept = []
    exempt = False
    for line in text.splitlines():
        heading = HEADING_RE.match(line.strip())
        if heading and len(heading.group(1)) <= 2:
            exempt = heading.group(2).lower() in EXEMPT_HEADINGS
        if not exempt and not heading:
            kept.append(line)
    return kept


def text_words(text):
    """Word count of a CLAUDE.md's own prose."""
    return sum(len(line.split()) for line in counted_lines(text))


def described(text):
    """How many files this CLAUDE.md describes, counting names rather than bullets."""
    return sum(len(NAMED.findall(HEAD.split(line, 1)[0]))
               for line in counted_lines(text) if DESCRIBED.match(line))


def budget(text):
    """This file's word budget: the floor, or an allowance per file it describes."""
    return max(BODY_WORD_LIMIT, ENTRY_BASE + ENTRY_WORDS * described(text))


def blocks(text):
    """Counting prose as [(words, first line)], heaviest first.

    A ceiling reports how far over a file is, which says nothing about where the
    weight sits, so a writer shaves a word at a time and re-runs. This says which
    block to cut, and one edit lands.
    """
    found, current = [], []

    def flush():
        if current:
            found.append((sum(len(l.split()) for l in current), current[0].strip()))
            del current[:]

    for line in counted_lines(text) + [""]:
        # A list item is its own block. Without this every bullet in a run merges
        # into one, and the report says the list is heavy rather than which bullet.
        if LIST_ITEM.match(line):
            flush()
        elif not line.strip():
            flush()
            continue
        current.append(line)
    flush()
    return sorted(found, reverse=True)


def report_blocks(text, indent="    ", show=3):
    """Print the heaviest blocks, so one cut is enough."""
    heavy = [b for b in blocks(text) if b[0] > 1][:show]
    if not heavy:
        return
    print("%sheaviest blocks:" % indent)
    for words, first in heavy:
        snippet = first if len(first) <= 64 else first[:61] + "..."
        print("%s  %3d  %s" % (indent, words, snippet))


def length_findings(root):
    """(path, word count, budget) per CLAUDE.md over its own budget."""
    findings = []
    for rel in sorted(claude_md_dirs(root)):
        path = os.path.join(root, rel, CLAUDE_MD)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        count, allowed = text_words(text), budget(text)
        if count > allowed:
            findings.append((path, count, allowed))
    return findings


def report_length(root):
    findings = length_findings(root)
    if not findings:
        print("OK: every CLAUDE.md is within its word budget")
        return 0
    print("%d CLAUDE.md file(s) over budget:\n" % len(findings))
    for path, count, allowed in findings:
        print("  %s" % path)
        print("    %d words against %d, %d over (Subdirectories and the root's "
              "maintenance note excluded)" % (count, allowed, count - allowed))
        with open(path, encoding="utf-8") as fh:
            report_blocks(fh.read())
        print("    fix: cut prose, or move what is read only during one kind of "
              "work into a repo skill under .claude/skills/.")
        print("    draft first: `lint_claude_md.py count -` reads a draft on "
              "stdin, so a rewrite is measured before it lands.\n")
    return 1


# --- cli -------------------------------------------------------------------


def report_plan(root):
    print(json.dumps(build(root), indent=2))
    return 0


def report_check(root):
    """Every check, always all of them, so one invocation reports everything."""
    codes = [report_structure(root), report_dupes(root), report_length(root)]
    return 1 if any(codes) else 0


# A file this close to the ceiling has no room for the next edit, so it gets the
# same block breakdown a failure does. Landing at exactly the limit is what makes
# the next writer repeat the shave.
TIGHT = 10


def report_count(targets):
    """Words, headroom, and the heaviest blocks, for a draft or for files on disk.

    Exists so a rewrite is measured before it lands. Writing a file, running the
    linter, and shaving a word at a time is the loop this removes.
    """
    items = []
    for target in targets or ["."]:
        if target == "-":
            items.append(("(stdin)", sys.stdin.read()))
        elif os.path.isdir(target):
            for rel in sorted(claude_md_dirs(target)):
                path = os.path.join(target, rel, CLAUDE_MD)
                with open(path, encoding="utf-8") as fh:
                    items.append((path, fh.read()))
        elif os.path.isfile(target):
            with open(target, encoding="utf-8") as fh:
                items.append((target, fh.read()))
        else:
            print("error: no such file or directory: %s" % target, file=sys.stderr)
            return 2

    over = 0
    print("%6s %7s %6s  %s" % ("words", "budget", "left", "file"))
    for path, text in items:
        count, allowed = text_words(text), budget(text)
        left = allowed - count
        print("%6d %7d %6d  %s" % (count, allowed, left, path))
        if left < 0:
            over += 1
        if left <= TIGHT:
            report_blocks(text, indent="        ")
    if over:
        print("\n%d file(s) over budget." % over)
    return 1 if over else 0


COMMANDS = {
    "plan": report_plan,
    "structure": report_structure,
    "dupes": report_dupes,
    "length": report_length,
    "check": report_check,
}


def main(argv):
    if len(argv) > 1 and argv[1] in ("-h", "--help"):
        print(__doc__.strip())
        return 0
    # count takes files, directories, or `-`, where every other subcommand takes one
    # root, so it parses its own arguments.
    if len(argv) > 1 and argv[1] == "count":
        return report_count(argv[2:])
    if len(argv) < 2 or argv[1] not in COMMANDS:
        print("error: expected one of count, %s (try --help)"
              % ", ".join(COMMANDS), file=sys.stderr)
        return 2
    root = argv[2] if len(argv) > 2 else "."
    if not os.path.isdir(root):
        print("error: not a directory: %s" % root, file=sys.stderr)
        return 2
    return COMMANDS[argv[1]](root)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
