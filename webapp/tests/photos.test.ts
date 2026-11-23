import { describe, expect, it } from 'vitest';
import { JobQueue, MAX_OWN, fitSize, takeFiles } from '../src/photos';

const file = (type: string) => ({ type });

describe('takeFiles', () => {
  it('takes image files only, up to the room left', () => {
    const r = takeFiles(10, [file('image/jpeg'), file('application/json'), file('image/png'), file('image/heic')]);
    expect(r.take).toHaveLength(MAX_OWN - 10);
    expect(r.notImages).toBe(1);
    expect(r.overMax).toBe(1);
  });
  it('takes nothing when full, and files with no type (the browser could not tell) are tried', () => {
    expect(takeFiles(MAX_OWN, [file('image/jpeg')])).toEqual({ take: [], notImages: 0, overMax: 1 });
    expect(takeFiles(0, [file('')]).take).toHaveLength(1);
  });
});

describe('fitSize', () => {
  it('fits the long side, keeps the shape, never enlarges', () => {
    expect(fitSize(5184, 3888, 480)).toEqual({ w: 480, h: 360 });
    expect(fitSize(3888, 5184, 480)).toEqual({ w: 360, h: 480 });
    expect(fitSize(300, 200, 480)).toEqual({ w: 300, h: 200 });
    expect(fitSize(10000, 1, 480)).toEqual({ w: 480, h: 1 });
  });
});

describe('JobQueue', () => {
  // a hand-driven scheduler: nothing runs until we say so
  const manual = () => {
    const ticks: (() => void)[] = [];
    let timer: (() => void) | null = null;
    const q = new JobQueue((f) => { ticks.push(f); }, (f) => { timer = f; return 1 as unknown as ReturnType<typeof setTimeout>; }, () => { timer = null; });
    return { q, tick: () => ticks.shift()?.(), fire: () => { const t = timer; timer = null; t?.(); }, hasTimer: () => timer !== null };
  };

  it('runs jobs one per turn, in order', () => {
    const { q, tick } = manual(), done: number[] = [];
    q.run([1, 2, 3].map((n) => () => done.push(n)));
    expect(done).toEqual([1]);
    tick(); expect(done).toEqual([1, 2]);
    tick(); tick(); tick();
    expect(done).toEqual([1, 2, 3]);
  });

  it('a new run drops what is left of the last', () => {
    const { q, tick } = manual(), done: string[] = [];
    q.run(['a1', 'a2', 'a3'].map((n) => () => done.push(n)));
    q.run(['b1', 'b2'].map((n) => () => done.push(n)));
    for (let i = 0; i < 6; i++) tick();
    expect(done).toEqual(['a1', 'b1', 'b2']);
  });

  it('with a delay, only the last of quick calls runs (a slider drag)', () => {
    const { q, tick, fire, hasTimer } = manual(), done: string[] = [];
    q.run([() => done.push('x')], 150);
    q.run([() => done.push('y')], 150);
    expect(done).toEqual([]);
    fire(); tick();
    expect(done).toEqual(['y']);
    q.run([() => done.push('z')], 150);
    q.cancel();
    expect(hasTimer()).toBe(false);
    fire();
    expect(done).toEqual(['y']);
  });
});
