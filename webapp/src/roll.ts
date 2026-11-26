// Film Rolls (test firmware): a look's roll fields (kept with the look; no imports, so pack.ts can read them).
export interface Roll { name: string; iso: number; color: string }   // color: #rrggbb
/** The roll ISOs LookLab offers (whole stops from 200). */
export const ROLL_ISOS = [200, 400, 800, 1600, 3200, 6400] as const;
/** The canister's name: printable ASCII (the camera's letters), up to 12. */
export const ROLL_NAME_MAX = 12;

export const cleanRollName = (s: string) => s.replace(/[^\x20-\x7e]/g, '').slice(0, ROLL_NAME_MAX);

/** A `roll` field from a saved look, or undefined when missing or malformed. */
export function parseRoll(v: unknown): Partial<Roll> | undefined {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return undefined;
  const o = v as Record<string, unknown>, r: Partial<Roll> = {};
  if (typeof o.name === 'string' && cleanRollName(o.name)) r.name = cleanRollName(o.name);
  if (typeof o.iso === 'number' && (ROLL_ISOS as readonly number[]).includes(o.iso)) r.iso = o.iso;
  if (typeof o.color === 'string' && /^#[0-9a-f]{6}$/i.test(o.color)) r.color = o.color.toLowerCase();
  return Object.keys(r).length ? r : undefined;
}

