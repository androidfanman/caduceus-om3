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
    for (let i = 57; i < 64; i++) rec[i] = i - 50;                 // future settings: 7..13, read back as they are
    expect(Array.from(recordFromPhotoCode(encodePhotoCode(rec)))).toEqual(Array.from(rec));
  });
  it('makes the look, with the name from the comment', () => {
    const l = lookFromPhotoCode(CAM);
    expect(l.name).toBe('Astia 100F');
    expect(l).toEqual(lookFromRecord(recordFromPhotoCode(CAM), 'Astia 100F'));
  });
  it('refuses text without a code', () => {
    expect(() => recordFromPhotoCode('Caduceus FILM 3 Kodachrome 64 cd1.EAAA')).toThrow();
  });
});
