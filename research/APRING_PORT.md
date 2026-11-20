# Panasonic / DJI aperture ring (branch `feature/aperture-ring`, 2026-11-20)

Status: **beta**.
- **Camera-tested on one OM-3 (firmware 1.1) with one ring lens**, a DJI MFT 15mm F1.7 ASPH. The ring sets the aperture
  in A and M from switch-on (stills only). It does nothing in P, S or video; the dial works there.
- **No Panasonic ring lens tested on this code yet.** p-eh's ring1, which this ports, was camera-tested with a Leica DG
  Summilux 15 mm f/1.7 on v0.27.
- Code: `firmware/src/apring.s`. Tests:
  - eight `aperture-ring-*` tests in `tools/test/emu_test.py`, using a scratch ring lens
    (`tools/emulator/session_ed1.mjs`, `RING_LENS`);
  - `research/apring/ncall_ring.py` (native cases).

## Origin

Port of p-eh's ring1 (`p-eh/caduceus-om3` branch `feature/aperture-ring`, c92db7a, on v0.27; issue #29). p-eh
camera-tested it on 2026-11-11 with a Leica DG Summilux 15 mm f/1.7. p-eh learned the protocol and the OM-3 sites from
azqeurio/om-c-firmware 0.3.2 (read as data; no licence, no code taken), om-emu's analysis of it,
cakelesscoder/caduceus-ep7 and fishcu/oly_fw_analysis PR #4. The hook sites are ring1's. Their stock bytes were
re-read from the 1.1 image, and none is used by v0.40.2.

| Hook | Site | Stock | Role |
|---|---|---|---|
| `hook_rq` | 0x603049f6 (7 B) | `asr 8,d0; mov d1,a0; movbu d0,(a0)` | the lens frame builder: R+21 = p2 >> 8; ours sets bit 0 for 69 / 75 / 84 / 90 |
| `hook_ps` | 0x602fc5ed (6 B) | `extbu d2; mov d2,(24,sp); btst 2,d2` | the lens state parser at the reply's +12: the u16 ring word |
| `hook_rl` | 0x60305322 (9 B) | `mov d0,d2; mov d2,d3; call 0x603106eb,[],4` | the count helper all six reply handlers call first: the length check |
| `hook_av` | 0x605ac5f1 (7 B) | `call 0x60063380,[d2,d3],12` | the 0x80CA "selected aperture" getter: the ring's value in A / M |

## What was checked in the stock code (disassembly, 2026-11-20)

- **No stock length check.** The reply handlers (0x60304da1..0x60304f44) call the count helper and then the parser
  without comparing the received count R+24 to anything. The helper (0x60305322) only clamps n. So stock reads a short
  reply blindly. om-c added a check; ring1's hook at the helper's entry is that check.
- **The ring word sits at a fixed +12.** The parser reaches the hook after 4 + 1 + 1 + 2 + 2 + 1 + 1 bytes on every
  path. Nothing before it depends on the command (K) or on R+21. The handlers for 75, 88 and 90 call the parser twice
  on the same buffer. Both calls start at +0 with the same R+21, so both read the ring word consistently.
- **The length equation.** After +12, the parser reads: 16 B for R+21 0x02; 2 * max(n, 1); 4 for 0x08. It reads 1 for
  0x80 only when the lens record +1676 has 0x02, 0x602f95f7(0) == 1, 0x602f9616(0) >= 5130 and K & 6 != 2. It reads 1
  for 0x10 only when +1676 has 0x20, and 5 for 0x20 only when +1676 has 0x80. For K & 6 == 4 (84, 90) it then reads a
  last u16, without moving a2 (0x602fc84e). For K & 6 == 0 (69, 75) nothing more is read. ring1 / om-c counted the
  three optional blocks from R+21 alone. The port mirrors the parser's conditions.
- **Measured (emulator, `ncall_ring.py` part 1):** the stock parser was run on 30,720 synthetic replies. The cases
  covered every R+21 value with the ring bit clear, n 0 / 1 / 3, the K of 69 / 75 / 84 / 90, selectors 0 / 8 / 16 /
  32, record bits off / on, and the lens-info answers either way. **30,720 / 30,720** read exactly the port's expected
  length less the 2 ring bytes (84 / 90 counted with their last u16).
- **Stock error path not used.** om-c returns 0x6507 through the callback's error branch 0x6030528c; stock's
  0x60301c65 then retries the exchange. But the callback has already reset stock's retry count (0x62996138 at
  0x60304d4a) before this check runs. A frame resent and found short again could then be retried for ever.
- **Section order.** The camera's own ready mask is SEC_READY 0xa32de58c (stock 0x60045e39). ring1 tested SECBITS
  0xa32de590, the copy bits. This project's crop round 7 boot-looped the camera by reaching section 6 early
  (`research/NOTES.md`). The port's four stubs use the gate form `static_check.py` proves.

## Changes from ring1

1. The stubs enter section 6 behind SEC_READY bit 5, not SECBITS.
2. The expected length mirrors the parser (above).
3. **Any short reply stops the asking for that lens** until its ID changes (`ap_st` 2). A reply exactly 2 short means
   the lens ignored the bit. Any other short reply is out of step. That one reply is read as stock reads a short reply:
   bit 0 cleared, the ring word not read. ring1 kept asking after an out-of-step reply, so such a lens was misread at
   every poll.
4. A ring word that is neither 0x8000 nor 0..0x1000 also stops the asking (`ap_nodd`).
5. The getter reads our state only (ring1 re-keyed it from the getter's task too). It checks the value's range itself,
   so a value written in between by the lens task can never give 0x8000 as an aperture.
6. Live from switch-on, with the switch `OM3MOD/NORING.TXT` (any content) read once per power-on at the first shutter
   event behind the card gate `hl_ok` (`ap_chk` from `lg_pr`), turning the ring off from there. ring1 read it in the
   v0.26 power-on load, which is gone since v0.29. See "Start-up" below.
7. The debug log's NOW line: `Aperture ring: on|off (NORING.TXT)|not checked; ring lens yes|no; asked N, stops N, at A
   N, ignored N, short N, odd N; last word W, used in A/M yes|no`. The stops count counts parser reads, so the double
   parse of 75 / 88 / 90 counts twice.

Kept from ring1: the ring-lens gate (record +1096 bit 7: the Leica 8-18 has 0x40 and is never asked, per om-c's
0.2.5 note), the ID keying (no identity hook: a same-model swap keeps the old value until the next reply), no Av clamp
(no OM-3 source for the lens's zoom-dependent limits; words above 0x1000 are dropped), and the modes (0x603f088b: 2 A,
4 M; C1..C4 53..56 and C5 63 through the effective AE 0x6031c0eb: 4 A, 6 M).

## Space



## Start-up (a deliberate exception to "leave the camera's start-up alone": the maintainer's call)

The ring is live from switch-on. Before the first half-press it does no card access, writes no setting and starts no
task. It sets one bit in the lens requests the camera already sends and reads 2 more bytes of each reply, only behind
SEC_READY bit 5 and the lens gate. The start-up failures in `research/NOTES.md` were of another kind:
- the v0.26.2 SDLOAD card load;
- v0.27's settings writes at power-on;
- the films-at-switch-on dial mapping.

On the camera, start-up felt normal, and the aperture readout showed the ring's stop at switch-on.

The cost: `NORING.TXT` needs the card, so it switches the ring off from the first half-press, not from switch-on.

The alternative, if the maintainer prefers the rule as written: the ring off until the first half-press. That build
(ar1) was camera-tested too. The change is `ap_on` starting at 0 and `ap_chk` setting 1 (the first of the two commits'
behaviour).

## Space

ext1 1,660 / 1,744 B (84 B free). The ring's code and state are in ext13 (the debug log's area, in the GX4-proven
reserve loaded with section 6): v0.40.2's ext11 has no room. Nothing else moved.

## Emulator results

- `ncall_ring.py` part 1: the stock parser's consumption matches the port's length equation in **30,720 / 30,720**
  cases.
- Part 2: **391 / 391** hook cases on the ring build against v0.40.2 without it.
- Suite: the eight ring tests pass. The full-suite result on this branch's commit is in the pull request.
- om-emu never calls the 0x80CA getter in a boot: its two callers, 0x605a936d and 0x605aa6bd, do not run. So the
  getter's A / M use is shown by the native cases and on the camera only.

## Camera (2026-11-20; one OM-3, firmware 1.1)

This ring code ran on top of v0.40.2 plus the Halation Radius (PR #95), as test builds 0.40.2ar1 and ar2. The ring
code is the same as on this branch. The lens was the DJI MFT 15mm F1.7 ASPH (maker note LensType 08 00 01 10).

- **A and M:** the ring sets the aperture, from switch-on (ar2).
  - M: f/1.7, 1.8, 2.0 and 8.0, all at 1/100.
  - A: f/16 at 1/8, f/4 at 1/160 and f/1.7 at 1/800, so the exposure follows the ring.
  - The EXIF FNumber is right.
  - Log: `asked 62 (44 before the first half-press) ... short 0, odd 0; last word 391, used in A/M yes`.
- **P, S and video:** the ring is ignored, and the dial works.
- **Lenses without a ring:** a Panasonic 14 mm f/2.5, a Sigma 30 mm and an OM lens work with the dial, in photo and
  video.
- **Lens swap:** the DJI was set to f/8, taken off, its ring turned to f/2, and put back: the camera then showed f/2.
  Swapping lenses while switched on caused no issue.

## Not known (camera only)

- Panasonic ring lenses (Leica 15 / 10-25 / Nocticron ...) on this code.
- The real lens's 84 / 90 replies.
- Custom modes saved in A / M.
- NORING.TXT on the camera.
- The ring in video: not built; the movie aperture path has not been traced.

## For testers

Put DEBUG.TXT in OM3MOD so the log's NOW has the "Aperture ring:" line. Then:
1. Switch on with the ring at a stop, in A or M: the readout shows that stop.
2. Take photos at a few stops: the EXIF FNumber follows them, and in A so does the shutter.
3. Ring at A: the dial sets the aperture.
4. P / S and video: the ring should do nothing (video is not supported yet).
5. A custom mode saved in A.

Send the log line, plus the lens name and firmware.
