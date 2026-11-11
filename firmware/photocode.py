#!/usr/bin/env python3
"""The film's settings as a short code in a JPEG's UserComment (v0.27, editor.s ex_cd1):
"Caduceus FILM n Name om3.1.<43 characters>".

om3.1 = the film's whole 64-byte LOOKS.BIN record (card/mkprofiles.py; webapp/src/om3.ts profilesBin), one nibble
each (value & 15), two to a byte (32 bytes), base64url without padding. Bytes 57..63 are spare: future settings go there
with 0 = off, so a reader that does not know them still loads the rest, and an old code reads as "off". Signed fields
are -8..7, unsigned ones 0..15 (UNSIGNED, plus every spare byte). Another camera (E-P7) would use its own name ("ep7.1.").
"""
import base64

PREFIX = 'om3.1.'
UNSIGNED = {36, 48, 49, 50, 51, 53, 55} | set(range(57, 64))


def encode(rec: bytes) -> str:
    nib = [b & 15 for b in rec[:64]]
    data = bytes((nib[2 * k] << 4) | nib[2 * k + 1] for k in range(32))
    return PREFIX + base64.urlsafe_b64encode(data).decode().rstrip('=')


def decode(code: str) -> bytes:
    i = code.index(PREFIX) + len(PREFIX)
    data = base64.urlsafe_b64decode(code[i:i + 43] + '=')
    nib = [x for b in data for x in (b >> 4, b & 15)]
    return bytes((v if i in UNSIGNED or v < 8 else v - 16) & 255 for i, v in enumerate(nib))


if __name__ == '__main__':
    import sys
    print(list(decode(sys.argv[1])))
