---
name: release
description: How to make a release of Caduceus for OM-3 or rebuild the published LookLab. Read before creating releases/vX, running tools/mkpatch.py, editing CHANGELOG.md for a release, or updating looklab/.
---

# Releasing

- Only a camera-tested build. Owner says when.
- `tools/mkpatch.py` makes `releases/vX/patch.json`. `firmware/patch.py --release vX` must rebuild the camera-tested package byte for byte (`SHA256SUMS`).
- Every release folder carries `DEBUG.TXT` (users linked to `releases/latest/download/DEBUG.TXT`).
- Update `CHANGELOG.md` (section plus "At a glance" row), `releases/README.md`, `README.md` "Latest" line, docs.
- `webapp/` changed: `make looklab` (rebuilds `looklab/` from `webapp/dist`, removes old asset JS and CSS).
- A new `releases/vX` folder pushed to `main` publishes a GitHub release (`.github/workflows/releases.yml`). Push only with the owner's OK in this session.
