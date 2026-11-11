#!/usr/bin/env python3
"""cd1: a film's settings as a short code, as the camera writes it into a JPEG's UserComment (v0.27, editor.s ex_cd1).

The film's 64-byte LOOKS.BIN record (card/mkprofiles.py; webapp/src/om3.ts profilesBin), bytes 0..56, one nibble each
(value & 15), two to a byte (29 bytes, the last nibble 0), base64url without padding: "cd1." + 39 characters.
Signed fields (-8..7) are every byte except the unsigned ones in UNSIGNED.
"""
import base64

UNSIGNED = {36, 48, 49, 50, 51, 53, 55}       # WB on, Art Effect, NR, VigFix, Grain, split Sh / Hl colour
N = 57


def encode(rec: bytes) -> str:
    nib = [b & 15 for b in rec[:N]] + [0]
    data = bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(29))
    return 'cd1.' + base64.urlsafe_b64encode(data).decode().rstrip('=')


def decode(code: str) -> bytes:
    assert code.startswith('cd1.') and len(code) == 43
    data = base64.urlsafe_b64decode(code[4:] + '=')
    nib = [x for b in data for x in (b >> 4, b & 15)][:N]
    return bytes((v if i in UNSIGNED or v < 8 else v - 16) & 255 for i, v in enumerate(nib)) + bytes(64 - N)


if __name__ == '__main__':
    import sys
    print(list(decode(sys.argv[1])[:N]))
