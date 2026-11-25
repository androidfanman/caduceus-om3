---
name: parallel-work
description: Which parts of this repo are safe to edit at the same time. Read before splitting work across parallel agents, git worktrees or subagents here, and before a change touching both firmware and LookLab. Independent areas, shared state, collision hotspots.
---

# Parallel work

## Independent

- `webapp/` (LookLab) vs `firmware/` + `card/`: separate worktrees fine, except card formats below.
- `research/` subdirs: independent of each other.
- `docs/` user pages vs code: independent, except shared files below.

## Coupled

- Card file formats: `card/*.py` writers and `webapp/src` readers and writers (`curvesbin.ts`, `curves.ts`, `om3films.ts`, `split.ts`, `main.ts`). `webapp/tests/om3.test.ts` checks `PROFILES.BIN` byte for byte against `card/mkprofiles.py`. One branch changes both.
- Firmware code space: `firmware/src/editor.s`, `xblock.s`, `editor.ld`. Section tails ext1–ext10 and section 6 extension are one budget. Two branches adding code collide on addresses even when the text merges clean. Serialize, or agree ranges first.
- Hook sites: `tools/test/static_check.py` hook list. Parallel branches each adding a hook conflict there.
- `tools/test/emu_test.py`: every fix and feature adds a test. Expect merge conflicts, keep both tests.

## Shared files, edit on one branch only

- `CHANGELOG.md`, `ROADMAP.md`, `README.md` "Latest" line, `releases/README.md`, `docs/FILM_SIMULATION_ROADMAP.md`, `docs/DEVELOPER_NOTES.md`.
- `research/NOTES.md`: append-only dated sections. Parallel appends conflict at file end. Resolve by keeping both.
- `looklab/`: hashed asset names. Rebuild (`make looklab`) only on the release branch, never in feature branches.

## Workspace `~/om3-work`

- One workspace for all worktrees. Never run `research/setup.sh` from a worktree: it rewrites `env.sh` `OM3_REPO` to that worktree.
- Give each worktree its own `BUILD_DIR` (`make build-firmware BUILD_DIR=~/om3-work/out-NAME`). Default `out-make` is shared.
- Never run two emulator suites or a toolchain build at once: CPU and memory contention, OOM risk.
- PR gate pass record (`emu-test-pass.json`) lives in each worktree's own git dir. Safe.
- Ports: Vite 5173 moves to the next free port. Docker compose 8080 fixed (`CADUCEUS_PORT` overrides).
