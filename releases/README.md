# Releases

Each folder is one version: the patch (`patch.json`, only the bytes Caduceus for OM-3 adds to OM's firmware), the
card files it needs, the expected checksums, and short notes. No OM firmware is stored here.

| Version | What's new | Status |
|---|---|---|
| [v0.40.2](v0.40.2/NOTES.md) | v0.40.1 plus smoother colour grain with less red-green speckle (made on every row), and the grain made faster so long bursts with Film Grain keep up | Camera-tested (as the grain colour test build, faster) |
| [v0.40.1](v0.40.1/NOTES.md) | v0.40 plus round film grain with fewer repeats, and a film's WB Compensation as the camera's own so the super control panel shows it (#88); a new film set gives the camera the film's WB straight away | Camera-tested (as the combined test build fix #88 + grain g4) |
| [v0.40](v0.40/NOTES.md) | v0.30.3 plus everything from the v0.40 test versions: crop modes (XPan, 21:9, 5:4) back at switch-on, a black or white Border per film at every ratio, our own film grain (1–5, Grain Size), looks in live view as you adjust them, your own choice of screen info, faster looks and Halation, Picture Mode open 30 s, focus stacking with more lenses, our version on the Firmware Version screen; fixes for #72, #85, #86 and #68 | Camera-tested (as v0.40-beta3) |
| [v0.40-beta3](v0.40-beta3/NOTES.md) | Test version of v0.40: v0.40-beta2 plus quick single shots with the debug log (#85) or Halation on, and a new film set replacing the films cleanly in custom modes too (#86) | Test version (pre-release), camera-tested |
| [v0.40-beta2](v0.40-beta2/NOTES.md) | Test version of v0.40: v0.40-beta plus three more screen-info rows (Subject Detection, Exposure Level Meter, Image Aspect), each hidden on its own | Test version (pre-release), camera-tested |
| [v0.40-beta](v0.40-beta/NOTES.md) | Test version of v0.40: v0.40-alpha plus the crop back at switch-on (#83) with the frame lines at its edges, looks shown in live view as you adjust them, black borders and the border at every ratio, your own choice of screen info, faster grain, our version on the Firmware Version screen, PR #82 (faster looks, two fixes, by crombach) and PR #79 (focus stacking with more lenses, by Bensonson) | Test version (pre-release), camera-tested |
| [v0.40-alpha](v0.40-alpha/NOTES.md) | Test version of v0.40: v0.30.4-alpha plus crop modes (XPan, 21:9, 5:4), a white Border per film with a live-view frame line, our own film grain (strength 1–5, Grain Size), safer start-up, and Picture Mode open 30 s (#75, by crombach) | Test version (pre-release), camera-tested |
| [v0.30.4-alpha](v0.30.4-alpha/NOTES.md) | Test version of v0.30.4: v0.30.3 plus the fix for the reboot when switching films fast (#72), the color wheel's label naming the page (#64, by crombach) and our looks kept out of video and S&Q (#68, by crombach) | Test version (pre-release), camera-tested |
| [v0.30.3](v0.30.3/NOTES.md) | v0.30.2 plus faster halation with a smoother fade, every dial click counted on the RGB / Mix pages with faster looks and saves (#69, by crombach), and a debug log that doesn't slow the shutter | Camera-tested |
| [v0.30.2](v0.30.2/NOTES.md) | v0.30.1 plus one fix: with Image Review on, Glow / Clarity / Halation photos no longer give a black review or freeze live view at the switch to a standard picture mode (#65) | Camera-tested |
| [v0.30.1](v0.30.1/NOTES.md) | v0.30 plus one fix: no more one-frame flash when leaving the B/W or WB Compensation row (#66, by crombach) | Camera-tested |
| [v0.30](v0.30/NOTES.md) | v0.29.5 plus Color Mix and RGB curves (photos), the 20 films regraded with them (`CURVES.BIN`, optional), a new Picture Mode order, films ready at switch-on, fixes for live dial turns (#54), a video freeze (#53) and Noise Filter's "*" | Camera-tested |
| [v0.29.5](v0.29.5/NOTES.md) | v0.29.4 plus custom modes that keep their own copy of everything (films, all their changes, the picture settings); Assign › Reset puts one back to the films as built | Camera-tested |
| [v0.29.4](v0.29.4/NOTES.md) | v0.29.3 plus fixes: Picture Mode stars and saving on leaving it, "FILM n*" on the shooting screen (by crombach); a film's Custom WB Kelvin kept in the WB screen (by buburun) | Camera-tested |
| [v0.29.3](v0.29.3/NOTES.md) | v0.29.2 plus a remappable Delete button: in photo and video mode Delete takes any Fn function (by crombach) | Camera-tested |
| [v0.29.2](v0.29.2/NOTES.md) | v0.29.1 with one fix: custom modes (C1–C5) no longer change your films, and each brings back the films it was assigned with (Save Settings: Hold and Recall too) | Camera-tested |
| [v0.29.1](v0.29.1/NOTES.md) | v0.29 with one fix: the films load with no card in the camera (from the camera's own memory) | Camera-tested |
| [v0.29](v0.29/NOTES.md) | Films, edits and Extras kept in the camera's own memory, so any card works; GUIDES / LABELS / TONES built into the firmware (no card files); a card brings in only films the camera never had; no copies on the card; the colour-matched standard 20 (optional `LOOKS.BIN`) | Camera-tested |
| [v0.29-beta](v0.29-beta/NOTES.md) | Test version of v0.29: films, edits and Extras kept in the camera's own memory, so any card works; GUIDES / LABELS / TONES built into the firmware (no card files); a card brings in only films the camera never had; the 20 films redesigned (optional `LOOKS.BIN`) | Test version (firmware camera-tested) |
| [v0.28](v0.28/NOTES.md) | Halation row; split toning 0–10 with a Tone Balance row; WB remembered per film and COLOR; Blacks / Whites as one grid (±7); the film as set in each photo's code; the Control Panel knows all of it | Camera-tested |
| [v0.28-alpha](v0.28-alpha/NOTES.md) | Test version of v0.28: Halation row; split toning 0–10 with a Tone Balance row; WB remembered per film and COLOR; Blacks / Whites as one grid (±7). The Control Panel isn't updated for these yet | Test version (firmware camera-tested) |
| [v0.27.1](v0.27.1/NOTES.md) | v0.27 without the automatic film load at switch-on (films load at the first half-press), fixing a rare freeze at start-up | Camera-tested |
| [v0.27](v0.27/NOTES.md) | All four arrow keys in Button Function; Creative Dial modes (CRT / ART / COLOR / MONO per position, a film per COLOR position); the film's name and recipe code (om3.1) in each JPEG's EXIF; optional extras: `DEBUG.TXT` (debug log) and the photo code kit for developers | Camera-tested |
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

Each version is also published on the repo's **Releases** page (tag `v0.16` … `v0.27.1`) with the whole project as
it was at that version: a GitHub Action (`.github/workflows/releases.yml`) publishes every folder here once, so a
new version only needs its folder. Optional extras in a folder (`DEBUG.TXT`, `*.zip`, from v0.27) are attached too (`CURVES.BIN`, from v0.30, by hand);
the launchers never copy them to the card.
**v0.28-alpha** is a test version: it is published by hand as a GitHub pre-release from `feature/v0.28-halation`
(not from `main`), and the launchers in its download make it by default. **v0.29-beta** is published the same way from
`feature/films-in-camera`; it has no card files (they are built into the firmware). **v0.30.4-alpha** likewise from
`try/v0.30.4`, **v0.40-alpha** from `try/v0.40-alpha`, and **v0.40-beta**, **v0.40-beta2** and **v0.40-beta3** from `try/v0.40-beta`.
See [CHANGELOG.md](../CHANGELOG.md) for the full history.
