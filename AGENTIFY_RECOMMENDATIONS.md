# Agentify recommendations

These items came up during the 2026-11-24 agentify run and were not acted on. Each one says what, why and what to do.

## Docs

- **Root `CLAUDE.md` sits over the tree's word ceiling.** It has 681 counted words against a ceiling of 128. What is left is the owner's rules, firmware safety, card delivery and how work is organized. They should load every session, so they stayed. Leave it as it is, or move the card and firmware-safety rules into a skill if the owner accepts that they load only when relevant.

## Build

- **The PR gate hook crashes under the system `python3`.** `.claude/settings.json` runs `python3 tools/test/pr_gate.py` on every Bash call that mentions `gh pr create`. The script imports numpy through `emu_test.py`, and Homebrew's `python3` has no numpy. The hook then blocks with `ModuleNotFoundError`. Run the hook with `~/om3-work/venv/bin/python`, or make `pr_gate.py` import nothing that needs numpy.
- **`research/setup.sh` now works on a fresh Mac, which needs a camera-free check.** The run fixed three faults: no `nproc` on macOS, `pip` installing into a different Python than `python3`, and the bundled zlib in binutils 2.42 failing to compile against the current macOS SDK. Setup now makes `$OM3_WORK/venv`, `env.sh` puts it on PATH, and configure passes `--with-system-zlib` on macOS. A fresh workspace built `package_sha256` 6842de71…, the same as the existing workspace. The owner should look at this change, because it changes how the workspace is set up.
- **A build of `main` does not match v0.40.3.** `main` builds 6842de71…, but v0.40.3 is 1545404e…. Nothing in `firmware/` or `card/` has changed since the release commit. `patch.py --release v0.40.3` still matches (`static:release-rebuild`). Most likely the release package is built from its own `COMMIT` or recipe. Confirm that this is expected.
- **The emulator suite runtime in `research/TESTING.md` is old.** The doc says about 85 s. A run alongside a toolchain build took 17.5 min. Put in a time measured on an idle machine.
- **The om-emu pin is 9 days old.** Run `tools/emulator/bump_om_emu.sh` (see `research/TESTING.md`).
- **Two tone tests skip without telling anyone.** `webapp/tests/tone.test.ts` needs `tools/ep7_tone.py` and `tools/ep7_tone_model.py` from the E-P7 project. Vendor those files under their license, or remove the tests.
- **No CI runs a build or test.** Only `releases.yml` exists. A workflow that runs `make test-webapp` on pull requests would catch LookLab breakage. Firmware tests need the stock BIN, so they cannot run in CI.

## Contrib

- **Commit and PR titles must now follow Conventional Commits.** The gate was added on request. Only 1 of the last 100 subjects follows the format today (`LookLab: …`, `NOTES: …`, `v0.40.3-beta4: …`). Map the old prefixes like this: `LookLab:` becomes `feat(looklab):` or `fix(looklab):`, `NOTES:` becomes `docs(research):`, and `vX:` becomes `chore(release):`. Contributor PRs whose titles do not follow the format will fail the `pr-title` check.
- **The conventions hook did not deny one sample in `setup_contrib.py verify`.** That sample was a PR body with a 21-word sentence. The template says "20 words max", and the hook may look for a different phrase. The fault is in the agentify-contrib assets, not this repo.
- **The PR title workflow first runs on the next PR.** Only a PR opened in the web UI uses the template prefill.
