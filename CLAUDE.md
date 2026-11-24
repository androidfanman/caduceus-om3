# Caduceus for OM-3

Firmware patches for OM SYSTEM OM-3 (firmware 1.1) plus LookLab browser app. Repo is the memory, not earlier chats: say when something is not written here.

Owner (GitHub `androidfanman`) not a programmer: plain words, short replies, never ask them to run terminal commands.

Also: `releases/vX/` one folder per release (`releases/README.md`). `looklab/` built LookLab, from `webapp/` via `make looklab`, never hand-edit. Root `index.html` tour, pictures in `pages/showcase/img/`.

Branches: `main` released, safe. `feature/...` meant to ship, README banner gives status. `experiment/...` answers a question, not for use.

## Before you start

1. Read `research/NOTES.md` for the area, `docs/DEVELOPER_NOTES.md` for current release.
2. Status: `docs/FILM_SIMULATION_ROADMAP.md`, `ROADMAP.md`, branch list.
3. Label every claim "camera-tested" (seen on real OM-3), "emulator only" or "analysis / guess". Never present emulator results or guesses as camera results.
4. Build, run, test, firmware workspace: read `.claude/skills/build-run-test/SKILL.md` first. `make` lists targets.

## Owner rules (keep them)

- **Push (2026-11-11, supersedes older notes and reminders):** never push or change anything on GitHub (issues, labels, comments, releases, branches) unless owner says so in this session. Every session kind. Local commits fine. Commit when ready (camera result, milestone, before summary), then ask. One OK = one push. Fetch before push: owner edits on GitHub website. Never rewrite history or commit authors.
- **Commits:** git identity of person doing the work, plus session attribution trailers.
- **Privacy:** no personal photos, personal data, names, emails, card dumps. Sample photos public domain or licensed, credited in `webapp/public/samples/CREDITS.md`. Never publish owner's LUT or preset files, read-only reference at most.
- **No OM firmware** (original or decoded), disassembly dumps or camera graphics in repo. Only exception: emulator screenshots of camera menus running our firmware, for tour (`pages/showcase/img/`, `research/showcase/make.sh`).
- **LookLab images:** owner approves each new or changed image before publishing.
- **Film sims:** own designs only. No copied looks, LUTs, presets. No grain, Glow / Clarity, Art Effects in film sims.
- **Never touch** cakelesscoder's repositories (Caduceus for E-P7). Credit them where their work used.

## Firmware safety

- Code space proven only: section tails ext1–ext10 (`firmware/editor.ld`, sizes checked by `build.py`), GUIDES.BIN code block (16448 B malloc cap), section 6 extension 0x60f49800..0x60f99800.
- Gaps between sections NOT loaded on camera, though emulator maps them.
- Section 6 extension usable only by raising section 6 loaded-end word, never past 0x60f99800 (`experiment/firmware-space-probe-64k`, `-256k`). `.ext11` (sliders) starts 0x60f49800: put new code after it. Details `research/NOTES.md`.
- `call f,[regs],N` writes return address at `(0,sp)`, overwrites MDR (`research/NOTES.md`, "Picture-mode sliders").
- Test order: build, emulator where it shows something, owner's camera test. Nothing done until owner's in-camera test passes. Owner flashes. Claude only prepares files.

## Camera card

- Ask owner before writing anything to card. Back up debug log first.
- Firmware: `DCOLYMP/E1479999.BIN`, never card root. Card files: `OM3MOD/`. Flash: hold OK while powering on.
- Send files with file-sending tool. Device bridge connected (`/Volumes/OM SYSTEM`): also write to card, verify sha256 on card.
- Pair firmware package with `GUIDES.BIN` from same build.
- Never copy `BUNDLES.BIN`, `LOOKS.BIN`, `EDITS.BIN` to owner's card.

## Releasing

Read `.claude/skills/release/SKILL.md` first.

## How work is organised (2026-11-15)

- Keep lean. Do what owner asks, nothing more. No plan documents, research rounds or review agents unless owner asks.
- Main chat ("Caduceus OM3", cad) does small requests itself: merge PRs, conflicts, test builds, card copies, releases. Bigger project: one session, short brief, cad picks model, never Fable (cad only).
- Project sessions: own worktree and branch, build and test only. No merge to `main`, no release, no push.
- Before card: one read of the change for camera harm (hooks and stock bytes, code space, start-up freeze or lag, video, no card / no films), rebuild matching package sha256. Real risk: tell owner plainly. Rest: owner's camera test.
- Contributor PRs, when owner says: merge as written, fix conflicts, test build, owner tests, release. No own changes unless asked.
- Behavior differing from current release: owner decides. Tell, don't decide.
- Commits, pull requests, their emulator test rules: read `.claude/skills/commit-and-pr/SKILL.md` first.

## Keeping the record

After each camera result or milestone, and before a summary:
- findings: `research/NOTES.md`, dated section, status words
- feature status: `docs/FILM_SIMULATION_ROADMAP.md`, `ROADMAP.md`
- half-done work: branch README banner plus commit on branch
- then ask owner before push

## Subdirectories

- [`card/`](card/CLAUDE.md) — makers for GUIDES/LABELS/LOOKS/CURVES.BIN card files
- [`debug-log/`](debug-log/CLAUDE.md) — `DEBUG.TXT`, how users send a debug log
- [`devkit/photo-code/`](devkit/photo-code/CLAUDE.md) — om3.1 photo code reader kit for developers
- [`docs/`](docs/CLAUDE.md) — user docs, technical notes, formats, roadmaps
- [`firmware/`](firmware/CLAUDE.md) — patch build, patcher, generators, src/ assembly
- [`pages/site/`](pages/site/CLAUDE.md) — guide-page renderer. Edit docs/*.md and root .md, not pages
- [`research/`](research/CLAUDE.md) — lab notebook, workspace setup, analysis tools, archive
- [`tools/`](tools/CLAUDE.md) — mkpatch.py release maker, emulator/ om-emu helpers
- [`webapp/`](webapp/CLAUDE.md) — LookLab Vite/TypeScript source (Control Panel before 2026-11-13)

## Maintaining this tree

Navigation index. Update before committing, not while editing. Changed a dir:
update its CLAUDE.md summary and the parent's link. New meaningful dir: add a
CLAUDE.md, link it. Pointer <= 70 chars. Budget outside its Subdirectories list
and this block: 128 words, or 48 plus 16 for each file a bullet names, whichever
is larger. Ceiling, not target: land under it, or the
next edit pays to shave. Measure a rewrite before writing it:

    python3 .claude/scripts/lint_claude_md.py count -    # draft on stdin
    python3 .claude/scripts/lint_claude_md.py count DIR  # words, headroom, heaviest blocks
