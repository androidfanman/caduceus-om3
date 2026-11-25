---
name: camera-card
description: How to put files on the owner's OM-3 SD card. Read before sending a firmware package or card files to the owner, writing to /Volumes/OM SYSTEM, or reading the card's debug log.
---

# Camera card

- Ask owner before writing anything to card. Back up debug log first.
- Before card: one read of the change for camera harm (hooks and stock bytes, code space, start-up freeze or lag, video, no card / no films), rebuild matching package sha256. Real risk: tell owner plainly. Rest: owner's camera test.
- Firmware: `DCOLYMP/E1479999.BIN`, never card root. Card files: `OM3MOD/`. Flash: hold OK while powering on.
- Send files with file-sending tool. Device bridge connected (`/Volumes/OM SYSTEM`): also write to card, verify sha256 on card.
- Pair firmware package with `GUIDES.BIN` from same build.
- Never copy `BUNDLES.BIN`, `LOOKS.BIN`, `EDITS.BIN` to owner's card.
