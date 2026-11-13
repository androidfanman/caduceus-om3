// v0.27: the film code the camera writes into a JPEG's UserComment (firmware ex_cd1, reference firmware/photocode.py).
import { describe, expect, it } from 'vitest';
import { encodePhotoCode, lookFromPhotoCode, lookFromRecord, recordFromPhotoCode } from '../src/om3';

// written by the firmware (om-emu, test dr4) for FILM 19 of the test card
const CAM = 'Caduceus FILM 19 Astia 100F om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA';

describe('om3.1 photo code', () => {
  it('round-trips the camera code', () => {
    expect(encodePhotoCode(recordFromPhotoCode(CAM))).toBe(CAM.split(' ').pop());
  });
  it('keeps signed, unsigned and spare bytes', () => {
    const rec = new Uint8Array(64);
    for (let i = 0; i < 57; i++) rec[i] = (i % 15) - 7 & 255;
    rec[36] = 1; rec[48] = 5; rec[49] = 4; rec[50] = 1; rec[51] = 3; rec[53] = 11; rec[55] = 9;
    rec[57] = 5;                                                    // v0.28 Halation 0..5
    [-3, 4, -5, 1, 1].forEach((v, k) => { rec[58 + k] = v & 255; });  // v0.28 Tone Balance, film WB: signed
    rec[63] = 13;                                                   // spare: read back as it is
    expect(Array.from(recordFromPhotoCode(encodePhotoCode(rec)))).toEqual(Array.from(rec));
  });
  it('makes the look, with the name from the comment', () => {
    const l = lookFromPhotoCode(CAM);
    expect(l.name).toBe('Astia 100F');
    expect(l).toEqual(lookFromRecord(recordFromPhotoCode(CAM), 'Astia 100F'));
  });
  it('v0.28 (pc1, written by the firmware in om-emu): Halation, Tone Balance, a half step in byte 63', () => {
    const l = lookFromPhotoCode('Caduceus FILM 1 Test om3.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACRPgAAI');
    expect(l.halation).toBe(3); expect(l.tone_balance).toBe(-2); expect(l.film_wb).toBeUndefined();
    expect(l.split).toEqual({ sh_color: 0, sh: 0, hl_color: 9, hl: 1.5 });              // 3 of 10
  });
  it('a v0.27 photo\'s minus (the opposite colour) and the WB fields', () => {
    const rec = new Uint8Array(64); rec[53] = 2; rec[54] = -2 & 255; rec[59] = -4 & 255; rec[60] = -4 & 255; rec[61] = 1; rec[62] = 1;
    const l = lookFromPhotoCode('om3.1.' + encodePhotoCode(rec).slice(6));
    expect(l.split).toEqual({ sh_color: 8, sh: 2, hl_color: 0, hl: 0 });
    expect(l.film_wb).toEqual({ mode: 'custom', kelvin: 3200 });
  });
  it('refuses text without a code', () => {
    expect(() => recordFromPhotoCode('Caduceus FILM 3 Kodachrome 64 cd1.EAAA')).toThrow();
  });
});
