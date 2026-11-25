---
paths:
  - "firmware/**"
  - "card/**"
---

# Firmware safety

- Code space proven only: section tails ext1–ext10 (`firmware/editor.ld`, sizes checked by `build.py`), GUIDES.BIN code block (16448 B malloc cap), section 6 extension 0x60f49800..0x60f99800.
- Gaps between sections NOT loaded on camera, though emulator maps them.
- Section 6 extension usable only by raising section 6 loaded-end word, never past 0x60f99800 (`experiment/firmware-space-probe-64k`, `-256k`). `.ext11` (sliders) starts 0x60f49800: put new code after it. Details `research/NOTES.md`.
- `call f,[regs],N` writes return address at `(0,sp)`, overwrites MDR (`research/NOTES.md`, "Picture-mode sliders").
