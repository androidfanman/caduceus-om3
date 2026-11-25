# Agentify recommendations

These items came up during the 2026-11-24 agentify run and are still open. Each one says what, why and what to do.

## Build

- **A firmware build depends on the fonts of the machine that makes it.** `firmware/mkicons.py` and `card/mkguides.py`
  look for DejaVu Sans Condensed under `/usr/share/fonts/truetype/dejavu/`. On a Mac that path does not exist, so
  Pillow falls back to whatever copy it finds. The camera pictures and labels then come out a little different, every
  address after them moves, and the package sha256 changes. So a build of `main` on this Mac never matches v0.40.3,
  although the source is the same. `firmware/patch.py --release vX` still matches, because it applies `patch.json`
  and does not rebuild. To make builds match on every machine, put the font file in the repo (its license allows that)
  and point the makers at it. The pictures may change a little against the current release, so this is the owner's
  call.
- **The owner should look at the `research/setup.sh` changes.** They make a fresh Mac set-up work: a workspace venv,
  an `nproc` fallback, and `--with-system-zlib` for binutils 2.42 on macOS. The step 6 message now says why a build
  can differ from the release.
- **Two tone tests skip without the E-P7 tools.** `webapp/tests/tone.test.ts` needs `tools/ep7_tone.py` and
  `tools/ep7_tone_model.py` from the Caduceus for E-P7 project. Copying them in means taking cakelesscoder's code, so
  this is the owner's call.
- **The emulator suite takes about 17 minutes.** #110 picks the job count from the machine and #111 replaces the
  fixed wait after each step, about 14% faster. When both are in `main`, update the run time and job count in
  `research/TESTING.md` and in the `build-run-test` skill.
