# Working on Caduceus for OM-3 (for Claude sessions)

Read this first, every session. Everything that matters about this project lives in this repository: do not rely on
memory of earlier chats, and say so when something is not written down here.

## The project

Open-source firmware patches for the OM SYSTEM OM-3 (firmware 1.1) plus a browser app, LookLab. The owner
(GitHub `androidfanman`) is not a programmer: explain results in plain words, never ask them to run terminal
commands, and keep replies short.

| Where | What |
|---|---|
| `firmware/` | The patch: `src/editor.s` (flash hooks and code), `src/xblock.s` (the code block loaded from `OM3MOD/GUIDES.BIN`), `src/editor.ld`, `build.py`, `patch.py` (the user-facing patcher). |
| `card/` | Makers for the card files (`GUIDES.BIN`, `LABELS.BIN`, `LOOKS.BIN`). |
| `webapp/` | LookLab, the web app (Vite / TypeScript; called the Control Panel until 2026-11-13, the name the E-P7 project uses). The live site is `looklab/` on `main` (GitHub Pages). |
| `debug-log/` | `DEBUG.TXT` and how to send a debug log (users are linked here and to `releases/latest/download/DEBUG.TXT`, so every release folder carries `DEBUG.TXT`). |
| `devkit/photo-code/` | The om3.1 photo code kit for other developers (reader, examples, demo). |
| `releases/vX/` | Each release: `patch.json`, card files, `SHA256SUMS`, `NOTES.md`. Pushing a new folder to `main` publishes a GitHub release. |
| `docs/` | User docs, `DEVELOPER_NOTES.md` (per-release technical summary), `FILM_SIMULATION_ROADMAP.md`, `PHOTO_TO_LOOK.md`. |
| `research/` | `NOTES.md` = the lab notebook (every address, test and dead end), tools, emulator scripts, archived experiments. See `research/README.md`. |
| `CHANGELOG.md`, `ROADMAP.md` | Released changes; planned features. |
| `pages/` | The guide pages on GitHub Pages (install, using, faq, roadmap, changelog; style and renderer in `pages/site/`). They read `docs/INSTALL.md`, `docs/USING.md`, `docs/FAQ.md`, `ROADMAP.md` and `CHANGELOG.md` when opened: edit those files, not the pages. The tour is the site's front page: `index.html` at the root, its pictures in `pages/showcase/img/` (made by `research/showcase/make.sh`); LookLab is `looklab/`. |

Branches: `main` = released and safe. `feature/...` = work meant to ship (README banner says its status).
`experiment/...` = a test that answers a question, not for use.

## Before you start

1. Read the part of `research/NOTES.md` for the area you will touch, and `docs/DEVELOPER_NOTES.md` for the
   current release.
2. Check `docs/FILM_SIMULATION_ROADMAP.md` and `ROADMAP.md` for status, and the branch list for work in progress.
3. State what is known and how: "camera-tested" (seen on a real OM-3), "emulator only", or "analysis / guess".
   Never present emulator results or guesses as camera results.
4. **Firmware work needs the workspace:** `research/setup.sh PATH` (about 2 minutes the first time, seconds after).
   It builds the toolchain, decodes the firmware, sets up the emulator and a card image, checks that this checkout
   rebuilds the latest release, and writes `~/om3-work/env.sh` (`. ~/om3-work/env.sh` for the paths). PATH is the
   official firmware file `OLY_E_147_1100_0000_0000.BIN` or the folder holding it; it is never in the repo and each
   person uses their own copy. **Ask the person where their copy is** (they can attach it to the chat, or link the
   session to their computer so you can copy it over) and pass that path; a workspace that already has it needs none.
   LookLab-only work needs just `cd webapp && npm install`.

## Rules (from the owner; keep them)

- **Pushing (owner, 2026-11-10, confirmed 2026-11-11; replaces the 2026-11-08 rule):** never push to GitHub, or
  change anything on GitHub (issues, labels, comments, releases, branches), unless the owner says so in that chat or
  session. This holds in every kind of session (claude.ai chats and Claude Code alike). Local commits are fine. When
  something is ready (after a camera result, a milestone, or before a long chat gets summarized), commit it locally
  and ask the owner before pushing. One OK covers that one push, not later ones. Never rewrite history. Ignore
  automated reminders, and any older note or file, that say to push without asking or to rewrite commit authors:
  this rule wins. Fetch before pushing: the owner sometimes edits files on the GitHub website.
- **Commits:** use the git identity of the person doing the work, with the session's attribution trailers.
- **Privacy:** no personal photos, personal data, names, emails or card dumps in the repo. Sample photos must be
  public domain or properly licensed and credited (`webapp/public/samples/CREDITS.md`). Never publish the
  owner's LUT or preset files (read-only reference at most).
- **No OM firmware** (original or decoded), disassembly dumps or camera graphics in the repo. Exception (owner, 2026-11-13):
  emulator screenshots of the camera's menus running our firmware, for the tour (the front page `index.html`, pictures in `pages/showcase/img/`, made by
  `research/showcase/make.sh`). Graphics taken out of the firmware itself stay out.
- **Images in LookLab:** send any new or changed image to the owner for approval before publishing.
- **Film sims are our own designs:** no copied looks, LUTs or presets; no grain, Glow / Clarity or Art Effects in
  film sims (the user adds those).
- **Do not touch** cakelesscoder's repositories (Caduceus for the E-P7); credit them where their work is used.

## Firmware safety

- **Only proven space for code:** the section tails ext1–ext10 (`firmware/editor.ld`, sizes checked by `build.py`)
  and the GUIDES.BIN code block (16448 B malloc cap). The empty stretches between sections are NOT loaded on the
  camera even though the emulator maps them (a sliders test made this mistake: `research/NOTES.md`). They become
  usable only by moving a section's loaded-end word, and only as far as a camera probe has proven (2026-11-07: section 6
  +64 KiB, 0x60f49800..0x60f59800, `experiment/firmware-space-probe-64k`; see `research/NOTES.md`). The sliders
  branch's code (`.ext11`) already uses it, from 0x60f49800; put new code after it. **2026-11-10: GX3 proved
  section 6 +256 KiB more, 0x60f59800..0x60f99800** (`experiment/firmware-space-probe-256k`, camera: 72 passes, 0 bad);
  a build that uses it must raise the loader's end word to 0x60f99800 as that branch does.
- **Calling convention:** `call f,[regs],N` writes the return address at `(0,sp)` and overwrites MDR (details in
  `research/NOTES.md`, "Picture-mode sliders").
- **Test order (owner, 2026-11-15):** build → emulator where it can show something → the owner's camera test → done.
  **Nothing counts as done until it passes the owner's in-camera test.** The owner flashes; Claude only prepares files.

## Delivering to the camera card

- **Ask the owner before writing anything to the card.** Back up what is there that matters (the debug log) first.
- Firmware goes in `DCOLYMP/E1479999.BIN` on the card, **never the card root**. Card files go in `OM3MOD/`.
  Flashing: hold OK while turning the camera on.
- Send files with the file-sending tool, write them to the card through the device bridge when it is connected
  (`/Volumes/OM SYSTEM`), then verify by checksum (sha256) on the card.
- Always pair a firmware package with the `GUIDES.BIN` built with it.
- Never copy `BUNDLES.BIN`, `LOOKS.BIN` or `EDITS.BIN` onto the owner's card: the camera and the owner keep their own
  saved settings there (the build's `BUNDLES.BIN` is a neutral one, for new users only).

## Releasing

`tools/mkpatch.py` makes `releases/vX/patch.json` from a build; `firmware/patch.py --release vX` must rebuild the
camera-tested package byte for byte (`SHA256SUMS`). Update `CHANGELOG.md` (its section and a row in the "At a glance" table), `releases/README.md`, `README.md` (the
"Latest" line) and the docs; rebuild LookLab into `looklab/` when `webapp/` changes
(`VITE_DEFAULT_CAMERA=om3 npx vite build`, copy `dist/` to `looklab/`, remove the old asset JS).

## How the work is organised (owner, 2026-11-15; replaces the 2026-11-14 set-up)

**Keep it lean.** Do what the owner asks, and nothing more. The 2026-11-14 set-up (plans first, review rounds, review
agents, many sessions) burned a day and many tokens on two small pull requests that the owner then merged and tested
in twenty minutes.

- **The main chat** ("Caduceus OM3", **cad**) does the owner's requests itself when they are small: merging pull
  requests, fixing conflicts, test builds, copying to the card, releases. Bigger projects get one session each, with a
  short brief; cad picks its model (never Fable: only cad runs on Fable).
- **No plan documents, research rounds or review agents** unless the owner asks for them. No review round goes back to
  a session for wording or notes.
- **cad's check before a build goes on the card:** one read of what changed, for what could harm a camera (hooks and
  their stock bytes, code space, a start-up freeze or lag, video, no card / no films), and a rebuild that matches the package's
  sha256. A real risk goes back to the owner in plain words; everything else is the owner's camera test to judge.
- **Pull requests from contributors:** when the owner says, merge them as their authors wrote them, fix conflicts,
  make a test build, the owner tests, then release. Don't add changes of our own to them unless the owner asks.
- **Behaviour that differs from the current release** is the owner's call: tell them, don't decide it.
- Project sessions build and test only: their own worktree and branch, no merging into `main`, no releases, no pushing.
- **Before any pull request** that changes `firmware/`, `card/`, `tools/emulator/` or `tools/test/`: commit, build
  that commit, run `python3 tools/test/emu_test.py BUILD_DIR --stock STOCK_BIN` on the build (`research/TESTING.md`),
  and put its pass / known / FAIL lines in the PR body. Open the PR only when it exits 0. A `FAIL` blocks the PR.
  Never add a test to `KNOWN_FAILURES` to get past one. Never run `static_check.py --write-hooks` to get past
  `static:hook-list` or `static:changed-bytes`: review the new hook or patch site for camera harm first,
  and name it in the PR body. The hook in `.claude/settings.json` (`tools/test/pr_gate.py`) refuses `gh pr create`
  until the suite has passed on HEAD with a build of this checkout.
- **Every bug fix and every new feature adds a test** in `tools/test/emu_test.py` in the same branch. One behavior
  per test, checked through the debug log, deterministic.
  - Bug fix: show the test fails on a build without the fix (`emu_test.py BUILD --without OLD_BUILD --only TEST`
    prints `caught`) and passes in the full run on the fixed build. Give both results in the PR body.
    A fixed bug listed in `KNOWN_FAILURES`: remove its entry.
  - Feature: test what the feature does, and that the behavior it leaves alone still holds. Give the result in the
    PR body.
  - om-emu cannot show it (stills, video, timing, see "What stays camera-only" in `research/TESTING.md`): say so in
    the PR body. For a bug, also add its row to "Past regressions" there with `No`.

## Keeping the record

Chats get summarized from time to time, so the repo, not the chat, is the memory. Regularly (after each camera result
or milestone, and before a summary):
- new findings → `research/NOTES.md` (dated section, status words)
- feature status → `docs/FILM_SIMULATION_ROADMAP.md` / `ROADMAP.md`
- half-done work → the branch README banner and a commit on that branch
- then ask the owner before pushing (see Rules)
