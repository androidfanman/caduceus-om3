# src

LookLab TypeScript source. `main.ts` UI entry, `style.css` / `theme.css`.

- `om3.ts` — profile bank, looks, card files, photo-code import
- `pack.ts` — pack model `caduceus-pack/1`, parsing
- `preview.ts`, `tone.ts`, `curves.ts`, `split.ts` — preview model fitted to camera
- `om3films.ts` — film sims from `data/om3films.json`
- `convert.ts` — LUT or Lightroom preset to film
- `curvesbin.ts`, `om3names.ts`, `zip.ts` — card file writers (`CURVES.BIN`, `NAMES.BIN`, zip)
- `photos.ts`, `photostore.ts` — own photos, kept in IndexedDB
- `saved.ts`, `history.ts`, `reset.ts` — user film sims, undo, reset
- `recipe.ts`, `rapidraw.ts` — readable recipe `.json`, `.rrpreset` export

## Subdirectories

- [`data/`](data/CLAUDE.md) — generated JSON data
- [`fonts/`](fonts/CLAUDE.md) — self-hosted UI fonts
