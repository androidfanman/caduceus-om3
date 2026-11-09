// Resetting looks to the built-in library (or to neutral for looks that did not come from it).
import { blankLook, cloneLook, type Look, type Pack } from './pack';

/** Fingerprint of what the user can edit in a look (everything but the app-only fields and the advice). */
export function lookFingerprint(l: Look, withTone = true): string {
  const v = [l.name, l.notes, l.kind, l.hue, l.light, l.sat, l.grain, l.wb, l.effect, l.vignette, l.art_effect,
    withTone ? l.tone : null];
  const s = JSON.stringify(v);
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 0x01000193);
  return (h >>> 0).toString(16).padStart(8, '0');
}

/** A pack copy of library look `src` that remembers where it came from (origin) and its values (lib). */
export const fromLibrary = (src: Look): Look => ({ ...cloneLook(src), origin: src.name, lib: lookFingerprint(src) });

/** Library looks that were renamed or replaced: old origin -> the look that took its place. */
const REPLACED_LOOKS: Record<string, string> = { Nostalgic: 'Provia 400' };

/** The library look `l` came from, if any. */
export const libraryOrigin = (l: Look, library: Pack): Look | undefined => {
  if (l.origin === undefined) return undefined;
  const name = REPLACED_LOOKS[l.origin] ?? l.origin;
  return library.looks.find((o) => o.name === name);
};

/**
 * `l` reset: a library look gets its shipped values back (and its shipped name, unless another look in the pack
 * now uses it); any other look becomes neutral, keeping its name, kind and notes.
 */
export function resetLook(l: Look, library: Pack, otherNames: string[] = []): Look {
  const src = libraryOrigin(l, library);
  if (src) {
    const r: Look = fromLibrary(src);
    if (otherNames.some((n) => n.toLowerCase() === src.name.toLowerCase())) r.name = l.name;
    return r;
  }
  const r: Look = { ...blankLook(l.kind, l.name), notes: l.notes };
  if (l.origin !== undefined) r.origin = l.origin;
  return r;
}

