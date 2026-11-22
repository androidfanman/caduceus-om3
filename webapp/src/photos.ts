// Your own photos in the preview (owner 2026-11-21: "upload more than one photo to test the film sims"): up to 12 at
// once, shown as a grid of small pictures with the film on, under the big preview. The photos stay in the browser.

/** How many of your own photos the preview takes at once (owner 2026-11-21). */
export const MAX_OWN = 12;
/** The grid pictures' working size (long side, px): small enough that 12 redraw quickly when the film changes. */
export const TILE_PX = 480;

/** Which of the picked files to load: image files only, as many as there is room for. */
export function takeFiles<T extends { type: string }>(have: number, files: readonly T[], max = MAX_OWN):
  { take: T[]; notImages: number; overMax: number } {
  const imgs = files.filter((f) => f.type === '' || f.type.startsWith('image/'));
  const room = Math.max(0, max - have);
  return { take: imgs.slice(0, room), notImages: files.length - imgs.length, overMax: Math.max(0, imgs.length - room) };
}

/** A w x h picture scaled to fit `max` on its long side (never enlarged), at least 1 px each way. */
export function fitSize(w: number, h: number, max: number): { w: number; h: number } {
  const k = Math.min(1, max / Math.max(w, h));
  return { w: Math.max(1, Math.round(w * k)), h: Math.max(1, Math.round(h * k)) };
}

/** Runs jobs one at a time, each in its own turn of `next`, so the page stays responsive while the grid redraws.
 *  A new run() drops whatever is left of the last one. With `delay`, the run starts that long after the last call,
 *  so dragging a slider redraws only the big preview until the drag pauses. */
export class JobQueue {
  private gen = 0;
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private readonly next: (f: () => void) => void = (f) => { setTimeout(f, 0); },
    private readonly wait: (f: () => void, ms: number) => ReturnType<typeof setTimeout> = (f, ms) => setTimeout(f, ms),
    private readonly clear: (t: ReturnType<typeof setTimeout>) => void = (t) => clearTimeout(t),
  ) {}

  run(jobs: readonly (() => void)[], delay = 0) {
    const g = ++this.gen;
    if (this.timer !== null) { this.clear(this.timer); this.timer = null; }
    let i = 0;
    const step = () => {
      if (g !== this.gen || i >= jobs.length) return;
      jobs[i++]();
      this.next(step);
    };
    if (delay > 0) this.timer = this.wait(() => { this.timer = null; step(); }, delay);
    else step();
  }

  /** Drop whatever is left. */
  cancel() { this.run([]); }
}
