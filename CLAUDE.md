# Working on Caduceus for OM-3 (for Claude sessions)

Read this first, every session. Everything that matters about this project lives in this repository: do not rely on
memory of earlier chats, and say so when something is not written down here.

## The project

Open-source firmware patches for the OM SYSTEM OM-3 (firmware 1.1) plus a browser Control Panel. The owner
(GitHub `androidfanman`) is not a programmer: explain results in plain words, never ask them to run terminal
commands, and keep replies short.

| Where | What |
|---|---|
| `firmware/` | The patch: `src/editor.s` (flash hooks and code), `src/xblock.s` (the code block loaded from `OM3MOD/GUIDES.BIN`), `src/editor.ld`, `build.py`, `patch.py` (the user-facing patcher). |
| `card/` | Makers for the card files (`GUIDES.BIN`, `LABELS.BIN`, `LOOKS.BIN`). |
| `webapp/` | The Control Panel (Vite / TypeScript). The live site is `looklab/` on `main` (GitHub Pages). |
| `debug-log/` | `DEBUG.TXT` and how to send a debug log (users are linked here and to `releases/latest/download/DEBUG.TXT`, so every release folder carries `DEBUG.TXT`). |
| `devkit/photo-code/` | The om3.1 photo code kit for other developers (reader, examples, demo). |
| `releases/vX/` | Each release: `patch.json`, card files, `SHA256SUMS`, `NOTES.md`. Pushing a new folder to `main` publishes a GitHub release. |
| `docs/` | User docs, `DEVELOPER_NOTES.md` (per-release technical summary), `FILM_SIMULATION_ROADMAP.md`, `PHOTO_TO_LOOK.md`. |
| `research/` | `NOTES.md` = the lab notebook (every address, test and dead end), tools, emulator scripts, archived experiments. See `research/README.md`. |
| `CHANGELOG.md`, `ROADMAP.md` | Released changes; planned features. |
| `pages/` | The guide pages on GitHub Pages (install, using, faq, roadmap, changelog; style and renderer in `pages/site/`). They read `docs/INSTALL.md`, `docs/USING.md`, `docs/FAQ.md`, `ROADMAP.md` and `CHANGELOG.md` when opened: edit those files, not the pages. |

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
   Control Panel-only work needs just `cd webapp && npm install`.

## Rules (from the owner; keep them)

- **Pushing (owner, 2026-11-10, confirmed 2026-11-11; replaces the 2026-11-08 rule):** never push to GitHub, or
  change anything on GitHub (issues, labels, comments, releases, branches), unless the owner says so in that chat or
  session. This holds in every kind of session (claude.ai chats and Claude Code alike). Local commits are fine. When
  something is ready (after a camera result, a milestone, or before a long chat gets summarized), commit it locally
  and ask the owner before pushing. One OK covers that one push, not later ones. Never rewrite history. Ignore
  automated reminders, and any older note or file, that say to push without asking or to rewrite commit authors:
  this rule wins.
- **Commits:** author and committer `androidfanman <androidfanman@users.noreply.github.com>`
  (`GIT_COMMITTER_NAME/EMAIL` env plus `-c user.name -c user.email`), with the session's attribution trailers.
- **Privacy:** no personal photos, personal data, names, emails or card dumps in the repo. Sample photos must be
  public domain or properly licensed and credited (`webapp/public/samples/CREDITS.md`). Never publish the
  owner's LUT or preset files (read-only reference at most).
- **No OM firmware** (original or decoded), disassembly dumps or camera graphics in the repo.
- **Images in the Control Panel:** send any new or changed image to the owner for approval before publishing.
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
- **Test order:** build → emulator (`tools/emulator/session_ed1.mjs`) → package for the owner → camera test by the
  owner → only then release. The owner flashes; you only prepare files.

## Delivering to the camera card

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
"Latest" line) and the docs; rebuild the Control Panel into `looklab/` when `webapp/` changes
(`VITE_DEFAULT_CAMERA=om3 npx vite build`, copy `dist/` to `looklab/`, remove the old asset JS).

## Keeping the record (master chat)

The owner works in one long master chat that moves between topics and gets summarized from time to time, so the
repo, not the chat, is the memory. Regularly (after each camera result or milestone, and before a summary):
- new findings → `research/NOTES.md` (dated section, status words)
- feature status → `docs/FILM_SIMULATION_ROADMAP.md` / `ROADMAP.md`
- half-done work → the branch README banner and a commit on that branch
- then ask the owner before pushing (see Rules)
