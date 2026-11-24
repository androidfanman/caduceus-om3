// The colour wheel's "Sat. All" (Picture Mode from v0.41, camera-tested as p4, 2026-11-23): on the Saturation page,
// one step of the front dial past the first (or last) colour selects all colours, and the rear dial then moves all 12
// saturation values together (each kept within −5..+5).

/** The value "Sat. All" shows: the 12 saturations' mean, rounded. */
export const satAllValue = (sat: readonly number[]) => Math.round(sat.reduce((a, b) => a + b, 0) / sat.length);

/** All 12 saturations moved by d steps, each kept within ±lim. */
export const shiftSat = (sat: readonly number[], d: number, lim = 5) => sat.map((v) => Math.max(-lim, Math.min(lim, v + d)));
