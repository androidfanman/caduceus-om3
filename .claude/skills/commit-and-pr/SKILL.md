---
name: commit-and-pr
description: This repo's commit and PR conventions. Read before writing any git commit message, `gh pr create`/`gh pr edit` title, or PR body here. Header format, ticket key placement, scope vocabulary, PR template.
---

# Commits and pull requests

- Commit subject + PR title, one format: `<type>(<scope>)?!?: [<issue>]? <imperative summary>`. Conventional Commits types. `!` = breaking.
- Scope = module (`firmware`, `looklab`, `card`, `docs`, `release`, `research`, `tools`). `[<issue>]` = main ticket ID: `feat(auth): [YCOM-21] add device-code login`.
- Old subjects before 2026-11-24 used `LookLab:`, `NOTES:`, `vX:`. Now: `feat(looklab):` or `fix(looklab):`, `docs(research):`, `chore(release):`.
- PR body: build from `.github/pull_request_template.md`, write over its comments. `--body`/`--body-file` skip prefill.
- PR body links every ticket work belongs to, title's key first. Hook only sees branch's key, rest is on you. No ticket: link nothing, never invent key.
- PR body length: under 256 words, bullets one line each. Only what a reviewer needs to review the diff. No ticket retelling, no history, no counts or benchmark numbers, no per-file walkthrough, no self-assessment. Headings, an attribution footer, embedded screenshots and recordings don't count against the budget.
- Commit body: only a why subject can't carry.
- Prose in a subject, commit body, or PR body: ASD-STE100 Simplified Technical English, and Zinsser's simplicity, brevity, clarity, humanity. Active voice, imperative, simple tenses. One idea per sentence, no sentence over 20 words. No `-ing` form as a noun. Condition before action. Same word for the same thing. Short common word over long one. Max three nouns in a row. Keep articles. Serial comma before the `and` or `or` closing a list. No slang, idiom, metaphor, em-dash, semicolon, or aside.
- The hook denies the cap, the word swaps and the `-ing` nouns, in a subject, a `-m` body, and a PR body. The rest is yours to judge.
- Enforced by `.claude/hooks/check_conventions.py`, `.github/workflows/pr-title.yml`.
- No bypass. Rewrite text, don't work around hook.

## Tests before a pull request

- PR touching `firmware/`, `card/`, `tools/emulator/` or `tools/test/`: commit, build that commit, run `python3 tools/test/emu_test.py BUILD_DIR --stock STOCK_BIN` (`research/TESTING.md`), paste pass / known / FAIL lines in PR body. Open only on exit 0. `FAIL` blocks.
- Never add to `KNOWN_FAILURES` to pass. Never `static_check.py --write-hooks` to pass `static:hook-list` or `static:changed-bytes`: review new hook or patch site for camera harm, name it in PR body. `tools/test/pr_gate.py` hook blocks `gh pr create` until suite passed on HEAD.
- Every bug fix and feature adds one deterministic `tools/test/emu_test.py` test in same branch, one behavior, checked via debug log.
  - Bug fix: `emu_test.py BUILD --without OLD_BUILD --only TEST` prints `caught`, full run passes on fixed build. Both in PR body. Remove its `KNOWN_FAILURES` entry.
  - Feature: test new behavior plus untouched behavior. Result in PR body.
  - om-emu cannot show it ("What stays camera-only", `research/TESTING.md`): say so in PR body. Bug: add "Past regressions" row with `No`.
