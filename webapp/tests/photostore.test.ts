// Your own photos kept for your next visit: the shelf over this browser's storage (here a stand-in in memory).
import { describe, expect, it } from 'vitest';
import { MAX_OWN } from '../src/photos';
import { PhotoShelf, type KeptPhoto, type PhotoKV } from '../src/photostore';

const memKV = (): PhotoKV & { size: () => number } => {
  const m = new Map<string, KeptPhoto>();
  return {
    all: async () => [...m.values()],
    put: async (p) => { m.set(p.key, p); },
    del: async (k) => { m.delete(k); },
    clear: async () => { m.clear(); },
    size: () => m.size,
  };
};
const blob = (s: string) => new Blob([s], { type: 'image/jpeg' });

describe('PhotoShelf', () => {
  it('keeps photos in the order they were added, with their names', async () => {
    let t = 100;
    const shelf = new PhotoShelf(memKV(), () => t--);   // a clock that runs backwards: order must not depend on map order alone
    await shelf.add('a.jpg', blob('a'));
    await shelf.add('b.jpg', blob('b'));
    const names = (await shelf.list()).map((p) => p.name);
    expect(names).toEqual(['b.jpg', 'a.jpg']);           // the earlier time first
  });

  it('two photos added in the same millisecond keep apart and in order', async () => {
    const shelf = new PhotoShelf(memKV(), () => 5);
    const k1 = await shelf.add('one', blob('1')), k2 = await shelf.add('two', blob('2'));
    expect(k1).not.toBe(k2);
    expect((await shelf.list()).map((p) => p.name)).toEqual(['one', 'two']);
  });

  it('removes one, or all', async () => {
    const kv = memKV(), shelf = new PhotoShelf(kv);
    const k = await shelf.add('a', blob('a'));
    await shelf.add('b', blob('b'));
    await shelf.remove(k);
    expect((await shelf.list()).map((p) => p.name)).toEqual(['b']);
    await shelf.clear();
    expect(kv.size()).toBe(0);
  });

  it('lists at most the grid\'s number of photos', async () => {
    let t = 0;
    const shelf = new PhotoShelf(memKV(), () => ++t);
    for (let i = 0; i < MAX_OWN + 3; i++) await shelf.add(`p${i}`, blob(String(i)));
    const l = await shelf.list();
    expect(l).toHaveLength(MAX_OWN);
    expect(l[0].name).toBe('p0');
  });
});
