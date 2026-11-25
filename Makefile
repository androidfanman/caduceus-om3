# Agent and developer entry points. `make` lists targets.
# Firmware targets need the workspace from `make setup-manual` (research/setup.sh).

OM3_WORK  ?= $(HOME)/om3-work
PY        := $(OM3_WORK)/venv/bin/python
OM3_STOCK ?= $(OM3_WORK)/stock/OLY_E_147_1100_0000_0000.BIN
TOOLCHAIN := $(OM3_WORK)/toolchain/build
OM3_EMU   ?= $(OM3_WORK)/om-emu/emu
BUILD_DIR ?= $(OM3_WORK)/out-make
STOCK     ?=
NODE_MIN  := 20

NO_WORKSPACE := Missing firmware workspace $(OM3_WORK). Run: make setup-manual STOCK=/path/to/OLY_E_147_1100_0000_0000.BIN

.DEFAULT_GOAL := help
.PHONY: help setup setup-manual check-workspace build build-firmware build-webapp run test test-unit test-webapp test-emu looklab

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "%-14s %s\n", $$1, $$2}'

setup: ## Install LookLab deps (npm ci), check firmware workspace
	@command -v node >/dev/null || { echo "Missing node. Install: brew install node@22"; exit 1; }
	@node -e 'process.exit(+process.versions.node.split(".")[0] >= $(NODE_MIN) ? 0 : 1)' || { echo "Node $(NODE_MIN)+ needed (22 recommended). Install: brew install node@22"; exit 1; }
	cd webapp && npm ci
	@[ -x $(PY) ] && echo "[ok] firmware workspace $(OM3_WORK)" || echo "[skip] $(NO_WORKSPACE)"

setup-manual: ## One-time firmware workspace (toolchain, emulator). STOCK=path to own firmware BIN
	research/setup.sh $(STOCK)

check-workspace:
	@[ -x $(PY) ] && [ -f $(OM3_STOCK) ] && [ -d $(TOOLCHAIN) ] || { echo "$(NO_WORKSPACE)"; exit 1; }

build: build-firmware build-webapp ## Build firmware package and LookLab

build-firmware: check-workspace ## Firmware package into BUILD_DIR (default ~/om3-work/out-make)
	$(PY) firmware/build.py --stock $(OM3_STOCK) --toolchain $(TOOLCHAIN) --out $(BUILD_DIR)

build-webapp: ## LookLab typecheck + vite build into webapp/dist
	cd webapp && npm run build

run: ## LookLab dev server, http://localhost:5173
	cd webapp && npm run dev

test: test-unit test-webapp test-emu ## All tests (emulator suite needs build-firmware first)

test-unit: check-workspace ## Python unit tests for the PR gate and provenance
	$(PY) -m unittest tools/test/test_pr_gate.py tools/test/test_provenance.py

test-webapp: ## LookLab vitest suite
	cd webapp && npm test

test-emu: check-workspace ## Emulator suite on BUILD_DIR (pass / known / FAIL lines)
	@[ -f $(BUILD_DIR)/E1479999.BIN ] || { echo "No build in $(BUILD_DIR). Run: make build-firmware"; exit 1; }
	OM3_EMU=$(OM3_EMU) $(PY) tools/test/emu_test.py $(BUILD_DIR) --stock $(OM3_STOCK)

looklab: build-webapp ## Rebuild the published looklab/ from webapp/dist
	rm -f looklab/assets/index-*.js looklab/assets/index-*.css
	cp -R webapp/dist/. looklab/
