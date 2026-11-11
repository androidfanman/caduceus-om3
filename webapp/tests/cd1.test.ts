// v0.27: the film code the camera writes into a JPEG's UserComment (firmware ex_cd1, reference firmware/cd1.py).
import { describe, expect, it } from 'vitest';
import { encodeCd1, lookFromCd1, lookFromRecord, recordFromCd1 } from '../src/om3';

// written by the firmware (om-emu, test ex2) for a record of the test card (FILM 3)
const CAM = 'Caduceus FILM 3 Kodachrome 64 cd1.EAAA_wERAP8A_w__MUQRMxAAEQ8CAOAAABAGEBA';

describe('cd1', () => {
  it('round-trips the camera code', () => {
    const rec = recordFromCd1(CAM);
    expect(encodeCd1(rec)).toBe(CAM.split(' ').pop());
  });
  it('keeps signed and unsigned fields', () => {
    const rec = new Uint8Array(64);
    for (let i = 0; i < 57; i++) rec[i] = (i % 15) - 7 & 255;
    rec[36] = 1; rec[48] = 5; rec[49] = 4; rec[50] = 1; rec[51] = 3; rec[53] = 11; rec[55] = 9;
    expect(Array.from(recordFromCd1(encodeCd1(rec)).subarray(0, 57))).toEqual(Array.from(rec.subarray(0, 57)));
  });
  it('makes the look, with the name from the comment', () => {
    const l = lookFromCd1(CAM);
    expect(l.name).toBe('Kodachrome 64');
    expect(l).toEqual(lookFromRecord(recordFromCd1(CAM), 'Kodachrome 64'));
  });
  it('refuses text without a code', () => {
    expect(() => recordFromCd1('Caduceus FILM 3 Kodachrome 64')).toThrow();
  });
});
