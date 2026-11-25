---
name: build-run-test
description: How to build, run and test this repo. Read before any build, run or test command, before running research/setup.sh or emu_test.py, before adding a Makefile target. Make targets, firmware workspace, tool versions, ports, gotchas.
---

# Build, run, test

`make` lists targets. Root `Makefile` echoes each native command.

## Firmware workspace

- One-time: `make setup-manual STOCK=/path/to/OLY_E_147_1100_0000_0000.BIN` (runs `research/setup.sh`). Stock BIN is the person's own copy, never in repo. Ask the person where it is.
- Existing workspace (`~/om3-work/venv/bin/python` present): skip, pass no STOCK.
- Builds GNU binutils 2.42 `mn10300-elf`, venv `~/om3-work/venv` (numpy, pillow, scipy), om-emu at `tools/emulator/om-emu.pin`, `~/om3-work/env.sh`. Fresh run takes minutes (binutils compile). Needs network: archive.ubuntu.com, GitHub, PyPI.
- `OM3_WORK=DIR` puts the workspace elsewhere. A setup run rewrites `$OM3_WORK/env.sh` with `OM3_REPO` = the checkout it ran from.
- System `python3` lacks numpy. Use `~/om3-work/venv/bin/python` or `. ~/om3-work/env.sh` (puts venv on PATH).

## Targets

- `build-firmware`: package into `BUILD_DIR` (default `~/om3-work/out-make`), about 240 MB. `build.json` `package_sha256`.
- `test-emu`: emulator suite on `BUILD_DIR`. 130 tests, jobs from cores and free memory (4 on 12-core 32 GB Mac), about 15 min. Exit 1 on any `FAIL`. Run on a clean committed tree to record the pass `tools/test/pr_gate.py` needs.
- Never run two emulator suites or a toolchain build side by side: CPU and memory contention, OOM risk.
- `test-unit`: 21 unittest cases, seconds, needs workspace venv.
- `test-webapp`: vitest, 116 tests, offline. Needs `python3` on PATH (`om3.test.ts` runs `card/mkprofiles.py`). 3 tone tests skip: E-P7 tools absent.
- `build-webapp`: `tsc --noEmit` + `vite build` into `webapp/dist`.
- `run`: Vite dev server http://localhost:5173.
- `looklab`: rebuild published `looklab/` from `webapp/dist`, removes old `index-*.js` / `index-*.css`. Same source gives same hashes.

## Gotchas

- Node 22 recommended (Dockerfile `node:22-alpine`), 20.19+ works. No `.nvmrc`.
- `VITE_DEFAULT_CAMERA=om3` in older docs is unused. `npm run build` gives the same output.
- `npm run gen-library` needs E-P7 checkout inputs. Outputs are committed.
- `releases/vX` rebuild: `python3 firmware/patch.py --stock $OM3_STOCK --release vX --out DIR`, compare `SHA256SUMS`. macOS build of `main` never matches the release: Pillow / FreeType / raqm draw pictures differently, addresses shift. Byte match needs Docker `ubuntu:24.04` (`python3-pil` 10.2.0, `fonts-dejavu-core` 2.37), see `research/NOTES.md` "Build environment (macOS".
- CI: `.github/workflows/test.yml` runs LookLab `npm test` + `npm run build` on each PR. No firmware CI: needs stock BIN. `releases.yml` publishes `releases/`.
- Docker: `cd webapp && docker compose up -d --build`, http://localhost:8080, `/healthz`.
