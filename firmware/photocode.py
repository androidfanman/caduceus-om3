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
"""
import base64

PREFIX = 'om3.1.'
UNSIGNED = {36, 48, 49, 50, 51, 53, 55, 57, 63}
WB_MODES = ['Auto', 'Sunny', 'Shade', 'Cloudy', 'Incandescent', 'Fluorescent', 'Underwater', 'Flash',
            'One-touch 1', 'One-touch 2', 'One-touch 3', 'One-touch 4', 'Custom WB']


def encode(rec: bytes) -> str:
    nib = [b & 15 for b in rec[:64]]
    data = bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(32))
    return PREFIX + base64.urlsafe_b64encode(data).decode().rstrip('=')


def decode(code: str) -> bytes:
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


def film_wb(rec: bytes):
    """-> (mode name, Kelvin or None); ('Auto', None) also for codes from before v0.28."""
    s8 = lambda i: rec[i] - 256 if rec[i] > 127 else rec[i]
    m, k = s8(61) + 11 * s8(62), s8(59) + 11 * s8(60)
    name = WB_MODES[m] if 0 <= m < len(WB_MODES) else 'Auto'
    return name, (2000 + 100 * (k + 60) if name == 'Custom WB' else None)


if __name__ == '__main__':
    import sys
    r = decode(sys.argv[1])
    print(list(r)); print('halation', r[57], 'tone balance', r[58] - 256 if r[58] > 127 else r[58], 'split', split_steps(r), 'WB', film_wb(r))
