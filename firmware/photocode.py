#!/usr/bin/env python3
"""The film's settings as a short code in a JPEG's UserComment (v0.27, editor.s ex_cd1; spec docs/PHOTO_CODE.md):
"Caduceus FILM n Name om3.1.<43 characters>".

om3.1 = a 64-byte LOOKS.BIN record of the film (card/mkprofiles.py; webapp/src/om3.ts profilesBin), one nibble
each (value & 15), two to a byte (32 bytes), base64url without padding. Signed fields are -8..7, unsigned ones 0..15
(UNSIGNED). Another camera (E-P7) would use its own name ("ep7.1.").
v0.27: the film as built (its LOOKS.BIN record); bytes 57..63 spare (0).
v0.28 (pc1): the film as set when the photo was taken (with the changes made on the camera and the camera's WB);
bytes 57 Halation 0..5, 58 Tone Balance -5..5, 59 / 60 Custom WB Kelvin and 61 / 62 the WB mode (each pair
v = lo + 11 hi: Kelvin = 2000 + 100 (v + 60) for Custom WB, mode = the camera's 13-mode list, 0 Auto). Split toning
stays in v0.26 steps (bytes 54 / 56: 0..5, or -5..-1 = the opposite colour in a v0.26 / v0.27 photo) so older readers
keep working; v0.28's half steps are in byte 63 (bit 0 Shadows, bit 1 Highlights): strength 0..10 = 2 v + bit.
v0.40: byte 48 is the Border -5..5 (minus black, plus white, 0 none), read signed. It was the Art Effect byte, gone
since v0.25, so every older code has 0 there. Byte 51 stays the grain level 0..3: v0.40's Film Grain 1..5 is written as
1-2 Low, 3 Medium, 4-5 High (the camera's gs_lv); Grain Size is not in the code.
Halation Radius (branch halation/v0.40-radius): byte 63 bits 2..3 = the COLOR's radius, 0 Bloom (and every older
code), 1 Tight, 2 Medium, 3 Wide; older readers read bits 0..1 only.

om3.2 (2026-11-24, owner: a new code that carries every Picture Mode row; the UserComment is the code alone, no
"Caduceus", film number or name): "om3.2.<60 characters>" = 45 bytes, base64url (no padding needed):
  bytes 0..31   the 64 values of om3.1, unchanged (so every rule above holds for them)
  bytes 32..43  24 more values coded the same way, a curves slot as the camera keeps it: 0..5 the red curve, 6..11
                green, 12..17 blue, -7..+7 each, a curve's 5 points (0 / 25 / 50 / 75 / 100 %) being its values 0, 2,
                3, 4, 5 (value 1 is spare: write 0, don't read it); 18..23 the colour mix -7..+7 (hue R, strength R,
                hue G, strength G, hue B, strength B)
  byte 44       the grain byte, whole: bit 7 set = given, bits 0..2 Film Grain strength 1..5 (0: the level's),
                bits 3..4 Grain Size 0 Fine, 1 Medium, 2 Coarse. Bit 7 clear (a film as built) or value 51 = 0 (Off):
                the level's strength (Low 2, Medium 3, High 5), Medium.
A longer code (more groups of 4 characters) may come: read the bytes you know. decode() reads both codes.
"""
import base64

PREFIX = 'om3.1.'
PREFIX2 = 'om3.2.'
POINTS = [0, 2, 3, 4, 5]          # om3.2: a curve's 5 points among its 6 values
GRAIN_SIZES = ['Fine', 'Medium', 'Coarse']
LEVEL_STRENGTH = [0, 2, 3, 5]    # value 51's level -> Film Grain strength (the camera's gs_dv)
UNSIGNED = {36, 49, 50, 51, 53, 55, 57, 63}   # v0.40: 48 (the Border) is signed
WB_MODES = ['Auto', 'Sunny', 'Shade', 'Cloudy', 'Incandescent', 'Fluorescent', 'Underwater', 'Flash',
            'One-touch 1', 'One-touch 2', 'One-touch 3', 'One-touch 4', 'Custom WB']


def encode(rec: bytes) -> str:
    nib = [b & 15 for b in rec[:64]]
    data = bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(32))
    return PREFIX + base64.urlsafe_b64encode(data).decode().rstrip('=')


def encode2(rec: bytes, curves=None, mix=None, grain=None, size='Medium') -> str:
    """om3.2. rec: the 64 values; curves: {'r': 5 values, 'g': ..., 'b': ...} (missing = flat); mix: 6 values; grain:
    the Film Grain strength 1..5, or None for not given (then size is not written either)."""
    nib = [b & 15 for b in rec[:64]] + [0] * 18 + [v & 15 for v in (mix or [0] * 6)]
    for k, c in enumerate('rgb'):
        for p, v in zip(POINTS, (curves or {}).get(c, [0] * 5)):
            nib[64 + 6 * k + p] = v & 15
    g = 0 if grain is None else 0x80 | GRAIN_SIZES.index(size) << 3 | grain
    data = bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(44)) + bytes([g])
    return PREFIX2 + base64.urlsafe_b64encode(data).decode()


def _body2(code: str):
    """om3.2's bytes (45 or more), or None when the text holds no om3.2 code."""
    i = code.find(PREFIX2)
    if i < 0:
        return None
    j = i = i + len(PREFIX2)
    while j < len(code) and (code[j].isalnum() or code[j] in '-_') and ord(code[j]) < 128:
        j += 1
    if j - i < 60 or (j - i) % 4:
        raise ValueError('an om3.2 code has 60 characters (or more, in groups of 4)')
    return base64.urlsafe_b64decode(code[i:j])


def extras(code: str) -> dict:
    """-> {'curves': {'r','g','b': 5 values}, 'mix': 6 values, 'grain': strength 0..5, 'size': name}; an om3.1 code
    gives flat curves, no mix, its level's strength and Medium."""
    rec, b = decode(code), _body2(code)
    level = LEVEL_STRENGTH[min(rec[51], 3)]
    if b is None:
        return {'curves': {c: [0] * 5 for c in 'rgb'}, 'mix': [0] * 6, 'grain': level, 'size': 'Medium'}
    x = [v if v < 8 else v - 16 for y in b[32:44] for v in (y >> 4, y & 15)]
    g = b[44] if b[44] & 0x80 and rec[51] else 0
    return {'curves': {c: [x[6 * k + p] for p in POINTS] for k, c in enumerate('rgb')}, 'mix': x[18:24],
            'grain': g & 7 if 1 <= g & 7 <= 5 else level,
            'size': GRAIN_SIZES[(g >> 3) & 3] if g and (g >> 3) & 3 < 3 else 'Medium'}


def decode(code: str) -> bytes:
    """-> the 64 values, from an om3.1 or an om3.2 code."""
    b = _body2(code)
    if b is not None:
        data = b[:32]
    else:
        i = code.index(PREFIX) + len(PREFIX)
        data = base64.urlsafe_b64decode(code[i:i + 43] + '=')
    nib = [x for b in data for x in (b >> 4, b & 15)]
    return bytes((v if i in UNSIGNED or v < 8 else v - 16) & 255 for i, v in enumerate(nib))


def split_steps(rec: bytes):
    """-> ((shadow colour, strength 0..10), (highlight colour, strength 0..10)) on the camera's v0.28 scale; a v0.26 /
    v0.27 minus becomes the opposite colour (6 on)."""
    s8 = lambda i: rec[i] - 256 if rec[i] > 127 else rec[i]
    out = []
    for col, st, bit in ((53, 54, 0), (55, 56, 1)):
        v = s8(st)
        out.append(((rec[col] + 6) % 12, -2 * v) if v < 0 else (rec[col], 2 * v + ((rec[63] >> bit) & 1)))
    return tuple(out)


RADII = ['Bloom', 'Tight', 'Medium', 'Wide']


def halation_radius(rec: bytes) -> str:
    """-> 'Bloom' (also for codes from before the Halation Radius), 'Tight', 'Medium' or 'Wide'."""
    return RADII[(rec[63] >> 2) & 3]


def film_wb(rec: bytes):
    """-> (mode name, Kelvin or None); ('Auto', None) also for codes from before v0.28."""
    s8 = lambda i: rec[i] - 256 if rec[i] > 127 else rec[i]
    m, k = s8(61) + 11 * s8(62), s8(59) + 11 * s8(60)
    name = WB_MODES[m] if 0 <= m < len(WB_MODES) else 'Auto'
    return name, (2000 + 100 * (k + 60) if name == 'Custom WB' else None)


if __name__ == '__main__':
    import sys
    r = decode(sys.argv[1])
    print(list(r)); print('border', r[48] - 256 if r[48] > 127 else r[48], 'halation', r[57], 'tone balance', r[58] - 256 if r[58] > 127 else r[58], 'split', split_steps(r), 'WB', film_wb(r))
