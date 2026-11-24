// Your own photos kept for your next visit (owner 2026-11-23: "if I come back to the page later it doesnt save them"):
// a preview-size JPEG copy of each (at most 2048 px on its long side, upright) in this browser's own storage
// (IndexedDB), until you remove it. Nothing is uploaded: the copies never leave this browser.
import { MAX_OWN } from './photos';

/** The preview-size copy's long side (px): the preview never works larger (previewPx). */
export const KEEP_PX = 2048;

export interface KeptPhoto { key: string; name: string; blob: Blob; at: number }

/** Where the photos are kept: IndexedDB in the browser, or a stand-in for tests. */
export interface PhotoKV {
  all(): Promise<KeptPhoto[]>;
  put(p: KeptPhoto): Promise<void>;
  del(key: string): Promise<void>;
  clear(): Promise<void>;
}

/** The kept photos, oldest first (the order you added them), at most MAX_OWN. */
export class PhotoShelf {
  private n = 0;
  constructor(private readonly kv: PhotoKV, private readonly now: () => number = Date.now) {}

  async list(): Promise<KeptPhoto[]> {
    return (await this.kv.all()).sort((a, b) => a.at - b.at || (a.key < b.key ? -1 : 1)).slice(0, MAX_OWN);
  }

  /** Keeps a copy; returns its key. */
  async add(name: string, blob: Blob): Promise<string> {
    const at = this.now(), key = `${at}-${++this.n}`;
    await this.kv.put({ key, name, blob, at });
    return key;
  }

  remove(key: string) { return this.kv.del(key); }
  clear() { return this.kv.clear(); }
}

/** This browser's IndexedDB: database "caduceus.om3.photos", one store "photos" keyed by `key`. */
export function idbPhotoKV(name = 'caduceus.om3.photos', storeName = 'photos'): PhotoKV {
  let db: Promise<IDBDatabase> | null = null;
  const open = () => (db ??= new Promise<IDBDatabase>((ok, fail) => {
    const r = indexedDB.open(name, 1);
    r.onupgradeneeded = () => { if (!r.result.objectStoreNames.contains(storeName)) r.result.createObjectStore(storeName, { keyPath: 'key' }); };
    r.onsuccess = () => ok(r.result);
    r.onerror = () => { db = null; fail(r.error); };
  }));
  const run = async <T>(mode: IDBTransactionMode, f: (s: IDBObjectStore) => IDBRequest<T>) => {
    const s = (await open()).transaction(storeName, mode).objectStore(storeName);
    return new Promise<T>((ok, fail) => { const q = f(s); q.onsuccess = () => ok(q.result); q.onerror = () => fail(q.error); });
  };
  return {
    all: () => run<KeptPhoto[]>('readonly', (s) => s.getAll() as IDBRequest<KeptPhoto[]>),
    put: async (p) => { await run('readwrite', (s) => s.put(p)); },
    del: async (key) => { await run('readwrite', (s) => s.delete(key)); },
    clear: async () => { await run('readwrite', (s) => s.clear()); },
  };
}
