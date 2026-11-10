# Releases

Each folder is one version: the patch (`patch.json`, only the bytes Caduceus for OM-3 adds to OM's firmware), the
card files it needs, the expected checksums, and short notes. No OM firmware is stored here.

| Version | What's new | Status |
|---|---|---|
| [v0.26.2](v0.26.2/NOTES.md) | Films load at power-on (no half-press); the super control panel dials step through the films; fixes: Film Grain with RAW+JPEG froze the camera, FILM N missing from the shooting screen when COLOR n itself was changed, bad bytes in `EDITS.BIN` | Camera-tested |
| [v0.26.1](v0.26.1/NOTES.md) | WB shift −7..+7 in `LOOKS.BIN` (v0.26 refused a file past ±5); the 20 film sims tuned from colour-checker photos (optional `LOOKS.BIN`) | Camera-tested (firmware) |
| [v0.26](v0.26/NOTES.md) | Split toning (Shadows and Highlights wheel pages, shown in live view; new `TONES.BIN`); fix for a restart after changing the drive mode; the 20 film sims with light split tones (optional `LOOKS.BIN`) | Camera-tested (firmware) |
| [v0.25](v0.25/NOTES.md) | Fast colour film grain with every setting; WB grid row (OK opens the camera's WB fine-tune screen); Glow row (+ Glow / − Clarity); Shading back; settings and the film kept over power off; no Art Effects; 20 new film sims (optional `LOOKS.BIN`) | Camera-tested (firmware) |
| [v0.24.1](v0.24.1/NOTES.md) | Films in the Picture Mode list (FILM n, name as title, changes kept, hold OK = as built); the Extras as Picture Mode rows; Glow / Clarity and Art Effects off and the Shading row hidden for now. Replaces v0.24 (withdrawn: Film Grain High rebooted the camera) | Camera-tested |
| [v0.22](v0.22/NOTES.md) | Sharp per look (Extras sector 10, −5 Off..+2); the stock Sharpness row leaves the COLOR screen | Camera-tested |
| [v0.21](v0.21/NOTES.md) | Grain on COLOR, VigFix, hold OK on the Film page saves a look, `*` = differs from factory, WB shift with Auto WB | Camera-tested |
| [v0.20](v0.20/NOTES.md) | Film page, Extras page (NR, Glow/Clarity, WB, Art Effects, Blacks/Whites) with labels, live-view effects, white Frame | Camera-tested |
| [v0.19](v0.19/NOTES.md) | Profiles are now Looks: the Looks page, `LOOKS.BIN` (reads your `PROFILES.BIN`) | Camera-tested |
| [v0.18](v0.18/NOTES.md) | The wheel opens on the Profiles page | Camera-tested |
| [v0.17](v0.17/NOTES.md) | Profile names on the Profiles page (`NAMES.BIN`) | Camera-tested |
| [v0.16](v0.16/NOTES.md) | Profile bank: 5 profiles per COLOR, Profiles dial 0–5 | Camera-tested |

The launchers (`Make SD card files (Mac).command` / `(Windows).bat`) make the newest version and ask whether you
want an older one. From a terminal: `python3 firmware/patch.py --release v0.16`.

**Going back to an older version:** make its files, copy `DCOLYMP` to the card and flash as usual. Keep your
`OM3MOD` files; every version reads `BUNDLES.BIN`. The look bank is `LOOKS.BIN` from v0.19 and `PROFILES.BIN` in
v0.16–v0.18: going back from v0.19 or later, copy `LOOKS.BIN` to `PROFILES.BIN` so the older version sees your latest looks.
Always copy the version's own `GUIDES.BIN` (from v0.20 it carries code made for that firmware); older versions ignore `LABELS.BIN`. Files a version doesn't know (for example
`NAMES.BIN` on v0.16) are ignored.

**Going back to stock:** flash `SD card files/restore/E1479999.BIN`, the official firmware the patcher saved.

Each version is also published on the repo's **Releases** page (tag `v0.16` … `v0.26.2`) with the whole project as
it was at that version: a GitHub Action (`.github/workflows/releases.yml`) publishes every folder here once, so a
new version only needs its folder.
See [CHANGELOG.md](../CHANGELOG.md) for the full history.
