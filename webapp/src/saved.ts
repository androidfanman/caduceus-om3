// Your own film sims (owner 2026-11-23: "there is no way to save film looks youve made"): a look saved with "Save film
// sim" goes into the Film sims window's "User created" section, kept in this browser apart from the lists, so it can be
// added again after the look in the list was replaced or changed.
import { exportLook } from './om3';
import { parseLook, type Look } from './pack';

export const STORE_SAVED = 'caduceus.om3.saved.v1';

const key = (name: string) => name.trim().toLowerCase();

/** A copy of the look as it is saved: without the app-only fields (built-in origin), so it stands on its own. */
export function savedCopy(l: Look): Look {
  return parseLook(JSON.parse(JSON.stringify(exportLook(l))), l.name);
}

/** The saved films from storage text (looks that cannot be read are left out). */
export function readSaved(raw: string | null): Look[] {
  if (!raw) return [];
  let j: unknown;
  try { j = JSON.parse(raw); } catch { return []; }
  const arr = j && typeof j === 'object' && Array.isArray((j as { looks?: unknown }).looks) ? (j as { looks: unknown[] }).looks : [];
  const out: Look[] = [];
  for (const v of arr) { try { out.push(parseLook(v, 'saved film')); } catch { /* skip a broken one */ } }
  return out;
}

/** Storage text for the saved films. */
export const writeSaved = (looks: Look[]): string => JSON.stringify({ looks: looks.map(exportLook) });

/** The saved film with this name (case and spaces at the ends ignored), or -1. */
export const savedIndex = (looks: Look[], name: string) => looks.findIndex((x) => key(x.name) === key(name));

/** Saves a copy of `l`: replaces the saved film of the same name, else adds it at the end. */
export function putSaved(looks: Look[], l: Look): { looks: Look[]; replaced: boolean } {
  const c = savedCopy(l), i = savedIndex(looks, l.name);
  if (i < 0) return { looks: [...looks, c], replaced: false };
  const next = looks.slice(); next[i] = c;
  return { looks: next, replaced: true };
}
