import './style.css';
import libraryJson from './data/library.json';
import { type Problem } from './format';
import {
  NOTE_MAX, PACK_SCHEMA, SECTORS, TONE_KEYS,
  parsePack, toneIsZero, toneLimit, type Look, type Pack, type Tone,
} from './pack';
import { History } from './history';
import { fromLibrary, libraryOrigin, resetLook } from './reset';
import { renderLook } from './preview';
import { makeZip } from './zip';
import { rrpreset } from './rapidraw';
import { previewToneLut } from './tone';
import {
  BANK_SCHEMA, COLORS, OM3, OM3_ARTS, OM3_NAME_MAX, PER, om3NameProblem, blankProfile, defaultBank, emptyBank, fromOldLookLab, parseBank, profilesBin, readProfiles,
  SHARP, sharpLabel, slowGrain, monoGrain, toOm3, validateBank, type Bank, type Fw,
} from './om3';
import { namesBin } from './om3names';
import { SPLIT_COLOURS, SPLIT_MAX, type Split } from './split';
import { CAMERA_FILMS, FILMS, FILM_GROUPS, filmLook, filmOf, type Film, type FilmGroup } from './om3films';
import { parseLook } from './pack';
// ---------------------------------------------------------------- state
const LIBRARY = parsePack(libraryJson);
// The colour-frames test photo first, then public-domain (CC0) photos picked for skin, strong colour, greens, blues,
// night light and sunset.
/** Bump when a sample photo file changes, so browsers fetch the new one instead of their cached copy. */
const SAMPLE_REV = '2';
const OM3_SAMPLES = [
  { id: 'frames', label: 'Colour frames' }, { id: 'portrait', label: 'Portrait' }, { id: 'headwrap', label: 'Portrait, headwrap' },
  { id: 'taxi', label: 'Yellow taxi' }, { id: 'meadow', label: 'Mountain meadow' }, { id: 'ocean', label: 'Ocean' },
  { id: 'bluehour', label: 'Blue hour' }, { id: 'paris', label: 'Night street' }, { id: 'paijanne', label: 'Sunset' },
];
const SWATCH = ['#e3c22f', '#e8932e', '#e0602a', '#d03434', '#c43c92', '#8a52c6', '#3d5bd0', '#3d8bd0', '#2fb2c6',
  '#2fb28c', '#45a845', '#9fc63b'];
type Tab = 'hue' | 'light' | 'sat';

let libNotice = '';
const S = {
  tab: 'hue' as Tab,
  image: 'frames',
  cut: 50,
};

// ---------------------------------------------------------------- camera: OM-3 only (owner 2026-11-09: the E-P7 side of the
// shared Caduceus Control Panel is gone from this tool)
const STORE_OM3 = 'caduceus.om3.bank.v1';
const CAM = 'om3' as const;
const samples = () => OM3_SAMPLES;
/** The OM-3 look bank: 4 COLORs x 5 numbers, positional like the camera's Film page. */
const O = { name: 'OM-3 looks', bank: startBank(), k: 0, v: 0 };
// Saved lists ("playlists"): named copies of all four COLORs' looks, kept in this browser. The list you're on is the
// one you edit: every change is saved into it. The looks you had before lists existed are the list "Default".
const STORE_LISTS = 'caduceus.om3.lists.v1', LIST_NAME_MAX = 40;
interface Lists { current: string; lists: Record<string, Bank> }
const LISTS: Lists = (() => {
  try {
    const raw = localStorage.getItem(STORE_LISTS);
    if (raw) {
      const j = JSON.parse(raw) as { current?: unknown; lists?: Record<string, unknown> };
      const lists: Record<string, Bank> = {};
      for (const [n, b] of Object.entries(j.lists ?? {})) {
        try { lists[n] = parseBank({ schema: BANK_SCHEMA, name: n, bank: b }, parseLook).bank; } catch { /* skip a damaged list */ }
      }
      const names = Object.keys(lists);
      if (names.length) {
        const current = typeof j.current === 'string' && lists[j.current] ? j.current : names[0];
        return { current, lists };
      }
    }
  } catch { /* storage blocked or damaged: start from the looks you have */ }
  return { current: 'Default', lists: { Default: O.bank } };
})();
// v0.22 (once): film sims added before they had a Sharp value get their film's, unless you set one yourself.
(() => {
  const KEY = 'caduceus.om3.filmsharp';
  try { if (localStorage.getItem(KEY)) return; } catch { return; }
  let n = 0;
  for (const bank of Object.values(LISTS.lists)) for (const row of bank) for (const l of row) {
    const f = l && filmOf(l);
    if (l && f && f.sharp && !(l.advice.sharpness ?? 0)) { l.advice = { ...l.advice, sharpness: f.sharp }; n++; }
  }
  try {
    localStorage.setItem(KEY, '1');
    if (n) localStorage.setItem(STORE_LISTS, JSON.stringify({ current: LISTS.current, lists: LISTS.lists }));
  } catch { /* private mode */ }
  if (n) libNotice = (libNotice ? libNotice + ' ' : '') + `Film sims now set Sharp (firmware v0.22): ${n} of your film looks got their film's value.`;
})();
O.bank = LISTS.lists[LISTS.current]; O.name = LISTS.current;
function storeLists() {
  LISTS.lists[LISTS.current] = O.bank;
  try { localStorage.setItem(STORE_LISTS, JSON.stringify({ current: LISTS.current, lists: LISTS.lists })); } catch { /* private mode */ }
}
const listNames = () => Object.keys(LISTS.lists).sort((a, b) => (a === 'Default' ? -1 : b === 'Default' ? 1 : a.localeCompare(b)));
function startBank(): Bank {
  try {
    const s = localStorage.getItem(STORE_OM3);
    if (s) return parseBank(JSON.parse(s), parseLook).bank;
    const old = fromOldLookLab(localStorage.getItem('om3-looklab'));
    if (old) { libNotice = 'Your looks from the earlier OM-3 Look Lab are here.'; return old; }
  } catch { /* fall through */ }
  return defaultBank(LIBRARY, fromLibrary);
}
const bankSnapshot = () => JSON.stringify({ schema: BANK_SCHEMA, name: O.name, bank: O.bank });

let saveTimer = 0;
function flush() {
  clearTimeout(saveTimer);
  try { localStorage.setItem(STORE_OM3, bankSnapshot()); storeLists(); } catch { /* private mode */ }
}
function persist() { clearTimeout(saveTimer); saveTimer = window.setTimeout(flush, 250); }
window.addEventListener('pagehide', flush);

// ---------------------------------------------------------------- undo / redo
// Every edit calls save(). Continuous edits (slider drags, typing) run inside draft(): they are saved but only become
// an undo step at the end of the gesture (the input's change event: pointer-up, blur or Enter) via checkpoint().
const snapshot = () => bankSnapshot();
let hist = new History(snapshot(), 200);
let drafting = false;
function save() { persist(); if (!drafting) checkpoint(); }
function draft(f: () => void) { drafting = true; try { f(); } finally { drafting = false; } }
function checkpoint() { hist.commit(snapshot()); undoUi(); }
function undoUi() {
  const u = document.getElementById('undo') as HTMLButtonElement | null, r = document.getElementById('redo') as HTMLButtonElement | null;
  if (u) u.disabled = !hist.canUndo;
  if (r) r.disabled = !hist.canRedo;
}
function step(dir: 'undo' | 'redo') {
  checkpoint();
  const s = dir === 'undo' ? hist.undo() : hist.redo();
  if (s === null) return;
  O.bank = parseBank(JSON.parse(s), parseLook).bank;
  persist(); renderAll(); undoUi();
}
const isTextField = (t: EventTarget | null) => t instanceof HTMLTextAreaElement || (t instanceof HTMLElement && t.isContentEditable) ||
  (t instanceof HTMLInputElement && !['range', 'checkbox', 'radio', 'button', 'submit', 'reset', 'color', 'file'].includes(t.type));
document.addEventListener('keydown', (e) => {
  if (!(e.ctrlKey || e.metaKey) || e.altKey || isTextField(e.target) || document.querySelector('dialog[open]')) return;
  const k = e.key.toLowerCase();
  if (k === 'z') step(e.shiftKey ? 'redo' : 'undo');
  else if (k === 'y' && !e.shiftKey) step('redo');
  else return;
  e.preventDefault();
});
const cur = (): Look | undefined => O.bank[O.k][O.v] ?? undefined;

// ---------------------------------------------------------------- DOM helpers
type Attrs = Record<string, unknown>;
function h<K extends keyof HTMLElementTagNameMap>(tag: K, attrs: Attrs = {}, ...kids: (Node | string | null | false | undefined)[]): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v as EventListener);
    else if (k === 'class') el.className = String(v);
    else if (k === 'value') (el as HTMLInputElement).value = String(v);
    else if (k === 'checked') (el as HTMLInputElement).checked = Boolean(v);
    else el.setAttribute(k, v === true ? '' : String(v));
  }
  for (const c of kids) if (c !== null && c !== false && c !== undefined) el.append(c);
  return el;
}
const $ = <T extends HTMLElement>(sel: string) => document.querySelector(sel) as T;

function download(name: string, data: Uint8Array | string, type = 'application/octet-stream') {
  const url = URL.createObjectURL(new Blob([data as BlobPart], { type }));
  const a = h('a', { href: url, download: name });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

let toastTimer = 0;
function toast(msg: string, kind: 'ok' | 'err' = 'ok') {
  const t = $('#toast');
  t.textContent = msg;
  t.className = `toast show ${kind}`;
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => (t.className = 'toast'), 3200);
}

function modal(title: string, body: Node, actions: (HTMLElement | null)[] = []): HTMLDialogElement {
  const dlg = h('dialog', { class: 'modal' },
    h('form', { method: 'dialog', class: 'modal-head' }, h('h2', {}, title), h('button', { class: 'icon', 'aria-label': 'Close' }, '×')),
    h('div', { class: 'modal-body' }, body),
    actions.length ? h('div', { class: 'modal-actions' }, ...actions) : null);
  dlg.addEventListener('close', () => dlg.remove());
  document.body.append(dlg);
  dlg.showModal();
  return dlg;
}

async function copy(text: string, what = 'Copied') {
  try { await navigator.clipboard.writeText(text); toast(what); } catch { toast('Copy failed: select the text and copy it by hand', 'err'); }
}

const shareBase = () => location.origin + location.pathname;

// ---------------------------------------------------------------- layout
function shell() {
  const app = $('#app');
  app.replaceChildren(
    h('header', { class: 'top' },
      h('div', { class: 'brand' }, h('span', { class: 'mark', 'aria-hidden': 'true' }, '☤'), h('span', { class: 'word' }, 'Caduceus'),
        h('span', { class: 'sub' }, 'for OM-3 · control panel')),
      h('nav', { class: 'actions' },
        h('span', { class: 'undo-btns' },
          h('button', { id: 'undo', class: 'icon', title: 'Undo (Ctrl+Z)', 'aria-label': 'Undo', disabled: true, onclick: () => step('undo') }, '↶'),
          h('button', { id: 'redo', class: 'icon', title: 'Redo (Ctrl+Shift+Z)', 'aria-label': 'Redo', disabled: true, onclick: () => step('redo') }, '↷')),
        menu('New', [
          ['Reset looks to standard', () => newBank('library')],
          ['Empty looks', () => newBank('empty')],
        ]),
        h('button', { onclick: openFile, title: 'The card\'s OM3MOD/LOOKS.BIN, or a looks file saved from this tool' }, 'Open…'),
        h('button', { onclick: () => om3FilmPicker(), title: 'Add film simulations to your films' }, 'Film sims'),
        h('button', { onclick: pasteDialog, title: 'Open a shared look or looks link' }, 'Paste link'),
        h('button', { onclick: om3Share }, 'Share looks'),
        h('button', { onclick: om3InstallDialog }, 'Install firmware'),
        h('button', { class: 'primary', onclick: om3ExportDialog }, 'Export'))),
    h('main', { class: 'layout' },
      h('aside', { class: 'pane list-pane', id: 'list' }),
      h('section', { class: 'pane preview-pane', id: 'preview' }),
      h('section', { class: 'pane editor-pane', id: 'editor' })),
    h('footer', { class: 'foot' },
      h('span', {}, 'Caduceus for OM-3 is an unofficial, community firmware mod (COLOR looks only, not Monochrome). Files are made in your browser; nothing is uploaded.'),
      h('a', { href: './samples/CREDITS.md', target: '_blank', rel: 'noopener' }, 'Image credits')),
    h('div', { id: 'toast', class: 'toast', role: 'status', 'aria-live': 'polite' }),
    h('input', { type: 'file', id: 'file', accept: '.json,application/json,.bin,.BIN', hidden: true, onchange: om3OnFile }),
    h('input', { type: 'file', id: 'photo', accept: 'image/*', hidden: true, onchange: onPhoto }));
  buildPreview();
}

function menu(label: string, items: [string, () => void][]): HTMLElement {
  const d = h('details', { class: 'menu' }, h('summary', {}, label),
    h('div', { class: 'menu-items' }, ...items.map(([t, f]) => h('button', { onclick: () => { d.open = false; f(); } }, t))));
  document.addEventListener('click', (e) => { if (!d.contains(e.target as Node)) d.open = false; });
  return d;
}

function renderAll() {
  renderList();
  renderEditor();
  schedulePreview();
}

// ---------------------------------------------------------------- look list
function renderList() {
  renderBank();
}

function enterCommits(e: KeyboardEvent) { if (e.key === 'Enter') checkpoint(); }
function focusSel() { ($('#list li.sel') as HTMLElement | null)?.focus(); }

// ---------------------------------------------------------------- editor
function renderEditor() {
  const el = $('#editor');
  const l = cur();
  if (!l) { el.replaceChildren(emptySlotPanel()); return; }
  renderOm3Editor(l);
}

function seg(label: string, opts: [string, string][], value: string, on: (v: string) => void): HTMLElement {
  return h('div', { class: 'field' }, h('span', { class: 'lbl' }, label),
    h('div', { class: 'seg', role: 'radiogroup', 'aria-label': label }, ...opts.map(([v, t]) =>
      h('button', { role: 'radio', 'aria-checked': String(v === value), class: v === value ? 'on' : '', onclick: () => on(v) }, t))));
}

function slider(min: number, max: number, value: number, on: (v: number) => void, fmt = (v: number) => (v > 0 ? `+${v}` : String(v)), aria = '') {
  const out = h('output', {}, fmt(value));
  const inp = h('input', {
    type: 'range', min, max, step: 1, value, 'aria-label': aria,
    oninput: (e: Event) => { const v = Number((e.target as HTMLInputElement).value); out.textContent = fmt(v); draft(() => on(v)); },
    onchange: checkpoint,
    ondblclick: () => { inp.value = '0'; out.textContent = fmt(0); on(0); },
  });
  return { inp, out };
}

function sectorPanel(l: Look, changed: () => void): HTMLElement {
  const hl = OM3.hl;
  const tabs: [Tab, string, number][] = [['hue', 'Hue', hl], ['light', 'Lightness', hl], ['sat', 'Saturation', 5]];
  const lim = tabs.find((t) => t[0] === S.tab)![2];
  const arr = l[S.tab];
  const rows = SECTORS.map((name, k) => {
    const { inp, out } = slider(-lim, lim, arr[k], (v) => { arr[k] = v; changed(); }, undefined, `${name} ${S.tab}`);
    return h('div', { class: 'srow' }, h('span', { class: 'sw', style: `background:${SWATCH[k]}` }), h('span', { class: 'sname' }, name), inp, out);
  });
  return h('div', { class: 'group' },
    h('div', { class: 'tabs', role: 'tablist' }, ...tabs.map(([t, label]) => h('button', {
      role: 'tab', 'aria-selected': String(t === S.tab), class: t === S.tab ? 'on' : '',
      onclick: () => { S.tab = t; renderEditor(); },
    }, label, l[t].some((v) => v !== 0) ? h('span', { class: 'dot' }) : null))),
    h('div', { class: 'sectors' }, ...rows),
    h('div', { class: 'tab-foot' },
      h('span', { class: 'help' }, S.tab === 'hue'
        ? '±5 per sector: + turns the colour toward its clockwise neighbour (Yellow → Orange). Double-click a slider to zero it.'
        : '±5 per sector, as on the camera\'s wheel. Double-click a slider to zero it.'),
      h('button', { class: 'link', onclick: () => { arr.fill(0); renderEditor(); changed(); } }, 'Reset')));
}

/** Small live tone-curve graph: x = the stock rendering, y = with this look's tone (the camera LUT model). */
function toneCurve(tone: Tone): { svg: SVGSVGElement; draw: () => void } {
  const NS = 'http://www.w3.org/2000/svg', S0 = 200, P = 8, W = S0 - 2 * P;
  const el = <K extends keyof SVGElementTagNameMap>(t: K, a: Record<string, string | number>) => {
    const e = document.createElementNS(NS, t);
    for (const [k, v] of Object.entries(a)) e.setAttribute(k, String(v));
    return e;
  };
  const svg = el('svg', { viewBox: `0 0 ${S0} ${S0}`, width: S0, height: S0, class: 'tone-curve', role: 'img', 'aria-label': 'Tone curve: stock input to look output' });
  const X = (v: number) => P + v * W, Y = (v: number) => P + (1 - v) * W;
  svg.append(el('rect', { x: P, y: P, width: W, height: W, class: 'tc-frame' }));
  for (let i = 1; i < 4; i++) {
    svg.append(el('line', { x1: X(i / 4), y1: Y(0), x2: X(i / 4), y2: Y(1), class: 'tc-grid' }));
    svg.append(el('line', { x1: X(0), y1: Y(i / 4), x2: X(1), y2: Y(i / 4), class: 'tc-grid' }));
  }
  svg.append(el('line', { x1: X(0), y1: Y(0), x2: X(1), y2: Y(1), class: 'tc-ident' }));
  const path = el('path', { class: 'tc-curve', d: '' });
  const dB = el('circle', { r: 3.5, class: 'tc-end' }), dW = el('circle', { r: 3.5, class: 'tc-end' });
  svg.append(path, dB, dW);
  const draw = () => {
    const t = previewToneLut(tone, 128);
    let d = '';
    t.forEach((v, i) => { d += `${i ? 'L' : 'M'}${X(i / 128).toFixed(1)},${Y(v).toFixed(1)}`; });
    path.setAttribute('d', d);
    dB.setAttribute('cx', String(X(0))); dB.setAttribute('cy', String(Y(t[0])));
    dW.setAttribute('cx', String(X(1))); dW.setAttribute('cy', String(Y(t[128])));
    dB.classList.toggle('on', tone.blacks !== 0); dW.classList.toggle('on', tone.whites !== 0);
  };
  draw();
  return { svg, draw };
}

const TONE_LABEL: Record<keyof Tone, string> = { highlights: 'Highlights', shadows: 'Shadows', midtones: 'Midtones', blacks: 'Blacks', whites: 'Whites' };
function tonePanel(l: Look, changed: () => void): HTMLElement {
  const rows = TONE_KEYS.map((k) => {
    const lim = toneLimit(k);
    const { inp, out } = slider(-lim, lim, l.tone[k], (v) => { l.tone[k] = v; drawCurve(); changed(); }, undefined, TONE_LABEL[k]);
    return h('div', { class: 'srow plain' }, h('span', { class: 'sname' }, TONE_LABEL[k]), inp, out);
  });
  const { svg, draw: drawCurve } = toneCurve(l.tone);
  return h('div', { class: 'group' },
    h('div', { class: 'tone-head' }, h('span', { class: 'lbl' }, 'Tone'),
      !toneIsZero(l.tone) ? h('button', { class: 'link', onclick: () => { for (const k of TONE_KEYS) l.tone[k] = 0; renderEditor(); changed(); } }, 'Reset') : null),
    svg,
    ...rows.slice(0, 3),
    h('div', { class: 'tone-sep' }),
    ...rows.slice(3),
    h('p', { class: 'help' },
      'Highlights / Shadows / Midtones (±7) are the look\'s own tone settings; Blacks / Whites (±5) move the ends of the curve ',
      '(Extras sectors 6 and 7 on the camera). Choosing the look on the camera\'s Film page sets them all. ',
      'The graph shows stock → this look; dots mark the Blacks and Whites ends.'),
  );
}

function effectPanel(l: Look, changed: () => void): HTMLElement {
  const e = l.effect;
  const v = !e ? 0 : e.type === 'clarity' ? e.strength : -e.strength;
  const fmt = (x: number) => (x === 0 ? 'Off' : x < 0 ? `Glow ${-x}` : `Clarity ${x}`);
  const { inp, out } = slider(-5, 5, v, (x) => {
    l.effect = x === 0 ? null : x > 0 ? { type: 'clarity', strength: x } : { type: 'bloom', strength: -x };
    changed();
  }, fmt, 'Glow to clarity');
  return h('div', { class: 'group' },
    h('div', { class: 'field' }, h('span', { class: 'lbl' }, 'Glow ↔ Clarity'),
      h('div', { class: 'srow plain' }, h('span', { class: 'end' }, 'Glow'), inp, h('span', { class: 'end' }, 'Clarity'), out)));
}

function wbPanel(l: Look, changed: () => void): HTMLElement {
  const on = l.wb !== null, wl = OM3.wb;
  const box = h('input', {
    type: 'checkbox', checked: on,
    onchange: (e: Event) => { l.wb = (e.target as HTMLInputElement).checked ? { a_b: 0, g_m: 0 } : null; renderEditor(); changed(); },
  });
  const rows = on ? [['a_b', 'A–B', 'Amber +  /  Blue −'], ['g_m', 'G–M', 'Green +  /  Magenta −']].map(([k, label, tip]) => {
    const { inp, out } = slider(-wl, wl, l.wb![k as 'a_b'], (v) => { l.wb![k as 'a_b'] = v; changed(); }, undefined, label);
    return h('div', { class: 'srow plain', title: tip }, h('span', { class: 'sname' }, label), inp, out);
  }) : [];
  return h('div', { class: 'group' },
    h('label', { class: 'check' }, box, h('span', {}, 'White balance shift'),
      h('span', { class: 'help' }, on ? 'the look\'s shift, added to the camera\'s own WB (Extras sectors 3 A–B and 4 G–M)' : 'off: no shift')),
    ...rows);
}

/** OM-3 v0.26 split toning: two wheels (Shadows, Highlights) of the camera's 12 colours. Click a colour to tint toward
 *  it; the slider sets the strength (minus = the opposite colour). Same numbers as the camera's wheel pages. */
/** v0.26 split toning reaches the camera only with the "v0.26 or later" export: before that the preview leaves it out. */
const om3Fw25 = () => { try { return localStorage.getItem('caduceus.om3.fw') === '25'; } catch { return false; } };
const splitPv = (l: Look): Look => (l.split && !om3Fw25() ? { ...l, split: undefined } : l);
function splitPanel(l: Look, changed: () => void): HTMLElement {
  const NS = 'http://www.w3.org/2000/svg';
  const el = <K extends keyof SVGElementTagNameMap>(t: K, a: Record<string, string | number>) => {
    const e = document.createElementNS(NS, t);
    for (const [k, v] of Object.entries(a)) e.setAttribute(k, String(v));
    return e;
  };
  const sp = (): Split => l.split ?? { sh_color: 8, sh: 0, hl_color: 1, hl: 0 };
  const put = (s: Split) => { if (s.sh || s.hl) l.split = s; else delete l.split; changed(); };
  const wheel = (which: 'sh' | 'hl', title: string) => {
    const S0 = 150, C = S0 / 2, R1 = 70, R0 = 28, cKey = which === 'sh' ? 'sh_color' : 'hl_color';
    const svg = el('svg', { viewBox: `0 0 ${S0} ${S0}`, width: S0, height: S0, class: 'split-wheel', role: 'img' });
    const pt = (a: number, r: number) => [C + r * Math.sin(a), C - r * Math.cos(a)];
    const dot = el('circle', { r: 7, class: 'split-dot' });
    const { inp, out } = slider(-SPLIT_MAX, SPLIT_MAX, sp()[which], (v) => { const s = { ...sp(), [which]: v }; put(s); draw(); }, undefined, `${title} strength`);
    const name = h('span', { class: 'help' });
    const wedges = SPLIT_COLOURS.map(([nm, col], i) => {
      const a0 = (i - 0.5) * Math.PI / 6, a1 = (i + 0.5) * Math.PI / 6;
      const [x0, y0] = pt(a0, R1), [x1, y1] = pt(a1, R1), [x2, y2] = pt(a1, R0), [x3, y3] = pt(a0, R0);
      const w = el('path', { d: `M${x0},${y0} A${R1},${R1} 0 0 1 ${x1},${y1} L${x2},${y2} A${R0},${R0} 0 0 0 ${x3},${y3} Z`, fill: col, class: 'split-wedge' });
      const t = el('title', {}); t.textContent = nm; w.append(t);
      w.addEventListener('click', () => {
        const s = { ...sp(), [cKey]: i } as Split;
        if (!s[which]) s[which] = 2;
        put(s); inp.value = String(s[which]); out.textContent = s[which] > 0 ? `+${s[which]}` : String(s[which]); draw(); checkpoint();
      });
      svg.append(w); return w;
    });
    svg.append(el('circle', { cx: C, cy: C, r: R0 - 2, class: 'split-hub' }), dot);
    const draw = () => {
      const s = sp(), c = s[cKey as 'sh_color'], v = s[which];
      wedges.forEach((w, i) => w.classList.toggle('on', i === c && v !== 0));
      const a = c * Math.PI / 6 + (v < 0 ? Math.PI : 0), [x, y] = v ? pt(a, R0 + 4 + (Math.abs(v) / SPLIT_MAX) * (R1 - R0 - 10)) : [C, C];
      dot.setAttribute('cx', String(x)); dot.setAttribute('cy', String(y));
      name.textContent = v === 0 ? 'Off' : `${SPLIT_COLOURS[c][0]}${v < 0 ? ' (opposite)' : ''} ${v > 0 ? '+' : ''}${v}`;
    };
    draw();
    return h('div', { class: 'split-one' }, h('b', {}, title), svg, h('div', { class: 'srow plain' }, h('span', { class: 'sname' }, 'Strength'), inp, out), name);
  };
  return h('div', { class: 'group' },
    h('span', { class: 'lbl' }, 'Split toning (firmware v0.26)'),
    !om3Fw25() ? h('p', { class: 'warn' }, h('b', {}, 'Needs firmware v0.26: '), 'Export is set to an older firmware, so split toning is not previewed and is left out of LOOKS.BIN. Choose "v0.26 or later" under Export › Firmware on the camera to use it.') : null,
    h('div', { class: 'split-row' }, wheel('sh', 'Shadows'), wheel('hl', 'Highlights')),
    h('p', { class: 'help' }, 'Tints the shadows and the highlights: click one of the wheel\'s 12 colours, then set the strength (minus tints toward the opposite colour). On the camera these are the HSL wheel\'s Shadows and Highlights pages (INFO after Luminance). Needs firmware v0.26: export with "v0.26 or later". Shown in the preview.'),
    h('button', { class: 'link', onclick: () => { delete l.split; renderEditor(); changed(); } }, 'Reset'));
}

function refreshProblems() {
  const el = document.getElementById('problems');
  const probs = validateBank(O.bank), at = O.k * PER + O.v;
  if (el) { const mine = probs.filter((p) => p.look === at); el.replaceChildren(...(mine.length ? [h('ul', { class: 'problems' }, ...mine.map((p) => h('li', {}, p.message)))] : [])); }
  const bad = new Set(probs.map((p) => p.look));
  document.querySelectorAll('#list li.look').forEach((li) => li.classList.toggle('bad', bad.has(Number((li as HTMLElement).dataset.at))));
}

// ---------------------------------------------------------------- preview
let srcData: ImageData | null = null;
let userPhoto: ImageData | null = null;
let canvas: HTMLCanvasElement;
let beforeCv: HTMLCanvasElement;
let beforeOf: ImageData | null = null;
let previewQueued = false;

function buildPreview() {
  canvas = h('canvas', { class: 'pv', 'aria-label': 'Approximate preview of the selected look' });
  const thumbs = h('div', { class: 'thumbs' },
    ...samples().map((s) => h('button', { class: `thumb${S.image === s.id ? ' on' : ''}`, 'data-id': s.id, onclick: () => pickImage(s.id), title: s.label },
      h('img', { src: `./samples/${s.id}.jpg?v=${SAMPLE_REV}`, alt: s.label, loading: 'lazy' }))),
    h('button', { class: `thumb own${S.image === 'user' ? ' on' : ''}`, 'data-id': 'user', onclick: () => (userPhoto ? pickImage('user') : $<HTMLInputElement>('#photo').click()), title: 'Your photo (stays on this device)' },
      h('span', {}, '+ Your photo')));
  // before / after: the untouched photo on its own canvas, clipped at a line you drag on the photo (or arrow keys)
  beforeCv = h('canvas', { class: 'before', 'aria-hidden': 'true' }); beforeOf = null;
  const divider = h('div', { class: 'divider', role: 'slider', tabindex: '0', 'aria-label': 'Before and after divider', 'aria-valuemin': '0', 'aria-valuemax': '100' },
    h('span', { class: 'knob', 'aria-hidden': 'true' }, '‹ ›'));
  const frame = h('div', { class: 'pv-frame' }, canvas, beforeCv, divider);
  const setCut = (v: number) => {
    S.cut = Math.max(0, Math.min(100, v)); frame.style.setProperty('--cut', `${S.cut}%`);
    divider.setAttribute('aria-valuenow', String(Math.round(S.cut))); divider.setAttribute('aria-valuetext', `${Math.round(S.cut)}% before`);
  };
  let dragging = false;
  const at = (e: PointerEvent) => { const r = frame.getBoundingClientRect(); setCut(((e.clientX - r.left) / r.width) * 100); };
  frame.addEventListener('pointerdown', (e) => { if (e.button !== 0) return; dragging = true; frame.setPointerCapture(e.pointerId); at(e); e.preventDefault(); });
  frame.addEventListener('pointermove', (e) => { if (dragging) at(e); });
  frame.addEventListener('pointerup', () => { dragging = false; }); frame.addEventListener('pointercancel', () => { dragging = false; });
  divider.addEventListener('keydown', (e) => {
    const step = ({ ArrowLeft: -2, ArrowRight: 2, PageDown: -10, PageUp: 10 } as Record<string, number>)[e.key];
    if (step) { setCut(S.cut + step); e.preventDefault(); }
    else if (e.key === 'Home') { setCut(0); e.preventDefault(); } else if (e.key === 'End') { setCut(100); e.preventDefault(); }
  });
  setCut(S.cut);
  $('#preview').replaceChildren(
    h('div', { class: 'pv-wrap' }, frame, h('span', { class: 'badge' }, 'Before'), h('span', { class: 'badge r' }, 'After · approximate')),
    thumbs,
    h('div', { class: 'pv-opts' },
      h('span', { class: 'help' }, 'Includes Contrast, Sharp and Shading.'),
      h('button', { class: 'link', onclick: () => $<HTMLInputElement>('#photo').click() }, 'Use your own photo…')),
    h('p', { class: 'help' }, 'Drag the line on the photo to compare before and after. A rough desktop-sim port running on JPEGs, not the camera\'s pipeline: use it for direction and strength, then check on the camera. Your own photo never leaves this browser.'));
  pickImage(S.image);
}

async function pickImage(id: string) {
  S.image = id;
  document.querySelectorAll('.thumb').forEach((t) => t.classList.toggle('on', (t as HTMLElement).dataset.id === id));
  if (id === 'user') { srcData = userPhoto; schedulePreview(); return; }
  try {
    const img = new Image();
    img.src = `./samples/${id}.jpg?v=${SAMPLE_REV}`;
    await img.decode();
    srcData = toImageData(img, img.naturalWidth, img.naturalHeight);
    if (S.image === id) schedulePreview();
  } catch { toast('Could not load the sample image', 'err'); }
}

/** The preview's working size (long side, px): enough for the preview at this screen's pixel density (sharp on
 *  Retina), between 1024 and 2048 so the colour engine stays quick. */
function previewPx(): number {
  const pane = document.getElementById('preview');
  const css = Math.max(pane ? pane.clientWidth - 28 : 0, window.innerHeight * 0.7);
  return Math.max(1024, Math.min(2048, Math.ceil(css * (window.devicePixelRatio || 1))));
}

function toImageData(img: CanvasImageSource, w: number, h0: number, max = previewPx()): ImageData {
  const k = Math.min(1, max / Math.max(w, h0));
  const W = Math.round(w * k), H = Math.round(h0 * k);
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  const ctx = c.getContext('2d', { willReadFrequently: true })!;
  ctx.drawImage(img, 0, 0, W, H);
  return ctx.getImageData(0, 0, W, H);
}

async function onPhoto(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  (e.target as HTMLInputElement).value = '';
  if (!f) return;
  try {
    const bmp = await createImageBitmap(f, { imageOrientation: 'from-image' } as ImageBitmapOptions);
    userPhoto = toImageData(bmp, bmp.width, bmp.height);
    bmp.close();
    pickImage('user');
  } catch { toast('That file could not be read as an image', 'err'); }
}

/** The photo frame: the photo's shape, as wide as the pane allows but no taller than 70% of the window. */
function sizeFrame(w: number, h: number) {
  const frame = canvas.parentElement as HTMLElement | null;
  if (!frame) return;
  frame.style.aspectRatio = `${w} / ${h}`;
  frame.style.width = `min(100%, ${(70 * w / h).toFixed(2)}vh)`;
}

function schedulePreview() {
  if (previewQueued) return;
  previewQueued = true;
  requestAnimationFrame(() => {
    previewQueued = false;
    if (!srcData || !canvas) return;
    if (canvas.width !== srcData.width || canvas.height !== srcData.height) { canvas.width = srcData.width; canvas.height = srcData.height; }
    sizeFrame(srcData.width, srcData.height);
    if (beforeOf !== srcData) {           // the untouched photo, drawn once per photo
      beforeCv.width = srcData.width; beforeCv.height = srcData.height; beforeCv.getContext('2d')!.putImageData(srcData, 0, 0); beforeOf = srcData;
    }
    const ctx = canvas.getContext('2d')!;
    const l = cur();
    if (!l) { ctx.putImageData(srcData, 0, 0); return; }
    const out = ctx.createImageData(srcData.width, srcData.height);
    renderLook(srcData, out, splitPv(l), { advice: true, camera: CAM });
    ctx.putImageData(out, 0, 0);
  });
}

// ---------------------------------------------------------------- import / export / share
function openFile() { $<HTMLInputElement>('#file').click(); }
function pasteDialog() {
  const ta = h('textarea', { rows: 3, placeholder: 'Paste a shared look or looks link (…#op1_… or …#ob1_…)', spellcheck: 'false' });
  const msg = h('p', { class: 'help' });
  const go = h('button', { class: 'primary' }, 'Open');
  const dlg = modal('Paste a link', h('div', {}, ta, msg), [go]);
  go.addEventListener('click', async () => {
    const r = await om3ImportCode(ta.value, false);
    if (r) dlg.close(); else msg.className = 'help err';
  });
  ta.addEventListener('input', () => { msg.textContent = ''; });
  importCodeMsg = (m) => (msg.textContent = m);
  ta.focus();
}
let importCodeMsg: (m: string) => void = (m) => toast(m, 'err');

const rrName = (n: string) => n.replace(/[^\w.-]+/g, '-').replace(/^-+|-+$/g, '') || 'look';
// ---------------------------------------------------------------- OM-3 (Caduceus for OM-3)
// The OM-3 has no look list: each of COLOR 1-4 holds five numbered looks (the camera's Film page, dial 1-5).
const OB_PREFIX = 'ob1_', OP_PREFIX = 'op1_';
const OM3_GH = 'https://github.com/androidfanman/caduceus-om3';
const at = (k: number, v: number) => `FILM ${k * PER + v + 1}`;   // owner 2026-11-08: one list, FILM 1-20 (COLOR k = (n - 1) / 5 on the card)

function newBank(kind: 'library' | 'empty') {
  if (!confirm(kind === 'library' ? 'Reset to the 20 films in the standard FILM 1–20 order? Your current films are replaced (Undo brings them back).'
    : 'Empty all 20 looks? Your current looks are removed (Undo brings them back).')) return;
  O.bank = kind === 'library' ? defaultBank(LIBRARY, fromLibrary) : emptyBank();
  O.k = 0; O.v = 0;
  save(); renderAll();
  toast(kind === 'library' ? 'Reset to the 20 films (FILM 1–20)' : 'All films emptied');
}

let bankDrag: [number, number] | null = null;
function swapSlots(a: [number, number], b: [number, number]) {
  if (a[0] === b[0] && a[1] === b[1]) return;
  const t = O.bank[a[0]][a[1]];
  O.bank[a[0]][a[1]] = O.bank[b[0]][b[1]];
  O.bank[b[0]][b[1]] = t;
  [O.k, O.v] = b;
  save(); renderAll(); focusSel();
}
function clearSlot(k: number, v: number) {
  const l = O.bank[k][v];
  if (!l) return;
  O.bank[k][v] = null;
  O.k = k; O.v = v;
  save(); renderAll();
  toast(`Removed "${l.name}" from ${at(k, v)} (Undo brings it back)`);
}
/** The saved-lists bar above the looks: pick a list to load it, save the current looks as a new list, rename or
 *  delete. */
function listsBar(): HTMLElement {
  const names = listNames();
  const sel = h('select', { 'aria-label': 'Saved list', onchange: (e: Event) => switchList((e.target as HTMLSelectElement).value) },
    ...names.map((n) => h('option', { value: n, selected: n === LISTS.current }, n)));
  return h('div', { class: 'lists-bar' },
    h('label', { class: 'field' }, h('span', { class: 'lbl' }, 'List'), sel),
    h('div', { class: 'lists-btns' },
      h('button', { onclick: () => nameDialog('Save as a new list', '', 'Save', (n) => {
        flush(); LISTS.lists[n] = JSON.parse(JSON.stringify(O.bank)) as Bank; switchList(n, `Saved as "${n}". You're now on "${n}"; changes save into it.`);
      }), title: 'Save all 20 films under a new name' }, 'Save as…'),
      h('button', { onclick: () => nameDialog(`Rename "${LISTS.current}"`, LISTS.current, 'Rename', (n) => {
        const b = LISTS.lists[LISTS.current]; delete LISTS.lists[LISTS.current];
        LISTS.lists[n] = b; LISTS.current = n; O.name = n; flush(); renderList(); toast(`Renamed to "${n}"`);
      }) }, 'Rename'),
      h('button', { class: 'danger', disabled: names.length < 2, title: names.length < 2 ? 'The only list can\'t be deleted' : undefined, onclick: () => {
        if (!confirm(`Delete the list "${LISTS.current}"? Its looks are removed from this browser (this can't be undone).`)) return;
        const gone = LISTS.current; delete LISTS.lists[gone];
        LISTS.current = listNames()[0]; O.bank = LISTS.lists[LISTS.current]; O.name = LISTS.current; O.k = 0; O.v = 0;
        hist = new History(snapshot(), 200); undoUi(); flush(); renderAll(); toast(`Deleted "${gone}"; now on "${LISTS.current}"`);
      } }, 'Delete')));
}
function switchList(n: string, msg?: string) {
  if (!LISTS.lists[n]) return;
  flush();
  LISTS.current = n; O.bank = LISTS.lists[n]; O.name = n; O.k = 0; O.v = 0;
  hist = new History(snapshot(), 200); undoUi();
  flush(); renderAll(); toast(msg ?? `Loaded "${n}"`);
}
function nameDialog(title: string, value: string, ok: string, done: (name: string) => void) {
  const help = h('p', { class: 'help' }, `Up to ${LIST_NAME_MAX} characters.`);
  const input = h('input', { type: 'text', value, maxlength: LIST_NAME_MAX, 'aria-label': 'List name', autocomplete: 'off' });
  const problem = (n: string) => (!n ? 'Type a name.' : n !== value && LISTS.lists[n] ? `There's already a list called "${n}".` : null);
  const submit = () => {
    const n = input.value.trim(), p = problem(n);
    if (p) { help.textContent = p; help.className = 'help err'; input.focus(); return; }
    dlg.close(); if (n !== value || !value) done(n);
  };
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); submit(); } });
  const dlg = modal(title, h('div', { class: 'name-dlg' }, input, help),
    [h('button', { onclick: () => dlg.close() }, 'Cancel'), h('button', { class: 'primary', onclick: submit }, ok)]);
  input.focus(); input.select();
}

function renderBank() {
  const el = $('#list');
  const bad = new Set(validateBank(O.bank).map((p) => p.look));
  const used = O.bank.flat().filter(Boolean).length;
  // owner 2026-11-08: one list FILM 1-20, as on the camera (FILM n = COLOR (n - 1) / 5 + 1, look (n - 1) % 5 + 1 in LOOKS.BIN)
  const N = COLORS * PER, slot = (n: number): [number, number] => [Math.floor(n / PER), n % PER];
  const films = h('ol', { class: 'looks bank' }, ...O.bank.flatMap((row, k) => row.map((l, v) => {
      const n = k * PER + v;
      const sel = k === O.k && v === O.v;
      const li = h('li', {
        class: `look${sel ? ' sel' : ''}${l ? '' : ' empty-slot'}${bad.has(k * PER + v) ? ' bad' : ''}`, 'data-at': k * PER + v,
        draggable: l ? 'true' : 'false', tabindex: 0,
        onclick: () => { O.k = k; O.v = v; renderAll(); },
        onkeydown: (e: KeyboardEvent) => {
          const go = (m: number) => { if (m >= 0 && m < COLORS * PER) { O.k = Math.floor(m / PER); O.v = m % PER; renderAll(); focusSel(); } };
          if (e.key === 'ArrowUp' && e.altKey && n > 0) { swapSlots([k, v], slot(n - 1)); e.preventDefault(); }
          else if (e.key === 'ArrowDown' && e.altKey && n < N - 1) { swapSlots([k, v], slot(n + 1)); e.preventDefault(); }
          else if (e.key === 'ArrowUp') { go(n - 1); e.preventDefault(); }
          else if (e.key === 'ArrowDown') { go(n + 1); e.preventDefault(); }
          else if ((e.key === 'Delete' || e.key === 'Backspace') && l) { clearSlot(k, v); e.preventDefault(); }
        },
        ondragstart: (e: DragEvent) => { bankDrag = [k, v]; e.dataTransfer?.setData('text/plain', `${k},${v}`); li.classList.add('dragging'); },
        ondragend: () => li.classList.remove('dragging'),
        ondragover: (e: DragEvent) => { e.preventDefault(); li.classList.add('over'); },
        ondragleave: () => li.classList.remove('over'),
        ondrop: (e: DragEvent) => { e.preventDefault(); li.classList.remove('over'); if (bankDrag) swapSlots(bankDrag, [k, v]); bankDrag = null; },
      },
      h('span', { class: 'grip', 'aria-hidden': 'true' }, l ? '⋮⋮' : ''),
      h('span', { class: 'idx' }, String(n + 1)),
      h('span', { class: 'nm' }, l ? l.name || '(no name)' : 'Empty'),
      h('span'),
      h('span', { class: 'row-btns' },
        h('button', { class: 'icon', title: 'Move up (Alt+↑)', 'aria-label': 'Move up', disabled: n === 0, onclick: (e: Event) => { e.stopPropagation(); swapSlots([k, v], slot(n - 1)); } }, '↑'),
        h('button', { class: 'icon', title: 'Move down (Alt+↓)', 'aria-label': 'Move down', disabled: n === N - 1, onclick: (e: Event) => { e.stopPropagation(); swapSlots([k, v], slot(n + 1)); } }, '↓'),
        h('button', { class: 'icon danger', title: 'Remove (leaves the number empty)', 'aria-label': 'Remove', disabled: !l, onclick: (e: Event) => { e.stopPropagation(); clearSlot(k, v); } }, '×')));
      return li;
    })));
  el.replaceChildren(
    listsBar(),
    h('div', { class: 'list-head' }, h('span', {}, 'Films'), h('span', { class: 'count' }, `${used} / ${N}`)),
    films,
    h('p', { class: 'help' }, 'The camera lists these as FILM 1–20 in Picture Mode, after COLOR 1–4, in this order. Drag a film to another place, or use ↑ ↓. Empty places are left out of the camera\'s list (the films after them move up a number).'));
}

/** The editor for a number with no look: make one. */
function emptySlotPanel(): HTMLElement {
  const k = O.k, v = O.v;
  const put = (l: Look, msg: string) => { O.bank[k][v] = l; save(); renderAll(); toast(msg); };
  return h('div', { class: 'empty-slot-panel' },
    h('h3', {}, `${at(k, v)}: Empty`),
    h('p', { class: 'help' }, 'On the camera this number shows "Empty" and loads neutral settings. Give it a look:'),
    h('div', { class: 'pick-row' },
      h('button', { class: 'primary', onclick: () => put(blankProfile(`Look ${v + 1}`), `New blank look in ${at(k, v)}`) }, 'Blank look'),
      h('button', { onclick: () => om3FilmPicker({ k, v }) }, 'From the film sims…'),
      h('button', { onclick: om3LibraryPicker }, 'From the built-in library…'),
      h('button', { onclick: pasteDialog }, 'Paste a link…')),
    h('p', { class: 'help' }, 'Library looks are the starter looks of Caduceus for the E-P7 by cakelesscoder, converted for the OM-3: Hue, Light and WB shifts are limited to ±5, a halation glow becomes a plain glow (the OM-3 glow has no colour), and Blur is left out. NR, Glow / Clarity and Art Effects carry over (firmware v0.20).'));
}

function om3Changes(c: { changed: string[]; dropped: string[] }): string {
  const parts = [];
  if (c.changed.length) parts.push(`limited to the OM-3 range: ${c.changed.join(', ')}`);
  if (c.dropped.length) parts.push(`left out: ${c.dropped.join(', ')}`);
  return parts.length ? ` (${parts.join('; ')})` : '';
}

function om3LibraryPicker() {
  const k = O.k, v = O.v;
  const inBank = new Set(O.bank.flat().filter(Boolean).map((l) => l!.name.toLowerCase()));
  const list = h('div', { class: 'pick-list' }, ...LIBRARY.looks.filter((l) => l.kind === 'colour').map((l) => h('button', {
    class: 'pick', onclick: () => {
      const c = toOm3(fromLibrary(l));
      if (!c.look) return;
      O.bank[k][v] = c.look; save(); renderAll(); dlg.close();
      toast(`"${c.look.name}" is now ${at(k, v)}${om3Changes(c)}`);
    },
  }, h('b', {}, l.name), inBank.has(l.name.toLowerCase()) ? h('span', { class: 'tag' }, 'in looks') : null, h('small', {}, l.notes))));
  const dlg = modal(`Library look for ${at(k, v)}`, list);
}

/** Film sims: browse the fitted films, preview one on the current photo and add it to the looks. With `into`, the
 *  film goes into that (empty) FILM; otherwise into the selected FILM when it is empty, else the first empty FILM (or, when all 20 are used, it asks to replace
 *  the selected look). Removing works as for any look (× in the list). */
function om3FilmPicker(into?: { k: number; v: number }) {
  let group: FilmGroup | 'all' | 'camera' = 'all', query = '', sel: Film | null = null;
  const pv = h('canvas', { class: 'film-pv', 'aria-label': 'Preview of the selected film sim' });
  const pvNote = h('div', { class: 'film-desc' });
  const drawPv = () => {
    if (!srcData) { pvNote.replaceChildren(h('p', { class: 'help' }, 'Pick a photo in the preview first.')); return; }
    const sc = Math.min(1, 520 / srcData.width), W = Math.round(srcData.width * sc), H = Math.round(srcData.height * sc);
    const c = document.createElement('canvas'); c.width = srcData.width; c.height = srcData.height;
    const cx = c.getContext('2d')!;
    if (sel) { const out = cx.createImageData(srcData.width, srcData.height); renderLook(srcData, out, splitPv(filmLook(sel)), { advice: true, camera: CAM }); cx.putImageData(out, 0, 0); }
    else cx.putImageData(srcData, 0, 0);
    pv.width = W; pv.height = H; pv.getContext('2d')!.drawImage(c, 0, 0, W, H);
    pvNote.replaceChildren(...(sel ? [h('b', {}, sel.film), h('p', {}, sel.desc)] : [h('p', { class: 'help' }, 'Click a film to see it on your photo.')]));
  };
  const target = (): { k: number; v: number } | null => {
    if (into && !O.bank[into.k][into.v]) return into;
    if (!O.bank[O.k][O.v]) return { k: O.k, v: O.v };
    for (let k = 0; k < COLORS; k++) { const v = O.bank[k].findIndex((l) => !l); if (v >= 0) return { k, v }; }   // the first empty FILM
    return null;
  };
  const place = (f: Film, t: { k: number; v: number }) => {
    const old = O.bank[t.k][t.v];
    O.bank[t.k][t.v] = filmLook(f); O.k = t.k; O.v = t.v; into = undefined;
    save(); renderAll(); drawRows();
    toast(old ? `${f.name} replaced "${old.name}" as ${at(t.k, t.v)}` : `${f.name} added as ${at(t.k, t.v)}`);
  };
  // All 20 numbers in use: ask first, then let the user pick which COLOR and number to replace.
  const askReplace = (f: Film) => {
    const box = h('div', { class: 'replace-box' });
    const dlg = modal(`Replace a look with ${f.name}?`, box);
    const choose = () => {
      box.replaceChildren(
        h('p', { class: 'help' }, `Pick the look ${f.name} replaces. The look you pick is overwritten (Undo brings it back).`),
        h('div', { class: 'replace-grid' }, ...O.bank.map((row, k) => h('div', { class: 'replace-col' },
          ...row.map((l, v) => h('button', { class: 'replace-slot', title: `Replace ${at(k, v)}: ${l?.name ?? 'Empty'}`, onclick: () => { dlg.close(); place(f, { k, v }); } },
            h('span', { class: 'num' }, String(k * PER + v + 1)), h('span', { class: 'nm' }, l?.name ?? 'Empty')))))),
        h('div', { class: 'modal-actions' }, h('button', { onclick: () => dlg.close() }, 'Cancel')));
    };
    box.replaceChildren(
      h('p', {}, `All 20 films (FILM 1–20) are in use. Do you want to replace one of them with ${f.name}?`),
      h('div', { class: 'modal-actions' },
        h('button', { onclick: () => dlg.close() }, 'No'),
        h('button', { class: 'primary', onclick: choose }, 'Yes, choose a look…')));
  };
  const add = (f: Film) => {
    const t = target();
    if (t) place(f, t); else askReplace(f);
  };
  // where each film sim already is in the current list (COLOR k, number v), by the look's film origin
  const where = () => {
    const m = new Map<string, string[]>();
    O.bank.forEach((row, k) => row.forEach((l, v) => { const f = l && filmOf(l); if (f) m.set(f.name, [...(m.get(f.name) ?? []), at(k, v)]); }));
    return m;
  };
  const list = h('div', { class: 'film-list', role: 'list' });
  const drawRows = () => {
    const have = where(), q = query.trim().toLowerCase();
    const hit = (f: Film) => !q || `${f.name} ${f.film}`.toLowerCase().includes(q);
    // owner 2026-11-08: the camera's 20 first, in their FILM 1-20 order; under All the other films follow by type
    const cam = group === 'all' || group === 'camera' ? CAMERA_FILMS.filter(hit) : [];
    const rows = group === 'camera' ? [] : FILMS.filter((f) => (group === 'all' ? !CAMERA_FILMS.includes(f) : f.group === group) && hit(f));
    const parts: [string, Film[]][] = [...(cam.length ? [['The 20 (FILM 1–20 order)', cam] as [string, Film[]]] : []),
      ...FILM_GROUPS.filter(([g]) => rows.some((f) => f.group === g)).map(([g, label]) => [group === 'all' ? `More: ${label.toLowerCase()}` : label, rows.filter((f) => f.group === g)] as [string, Film[]])];
    const sections = parts.map(([label, fs]) =>
      h('div', { class: 'film-group' }, h('h3', {}, label), ...fs.map((f) =>
        h('div', { class: `film-row${sel === f ? ' on' : ''}${have.has(f.name) ? ' in-list' : ''}`, role: 'listitem' },
          h('button', { class: 'film-pick', onclick: () => { sel = f; drawPv(); drawRows(); }, 'aria-pressed': String(sel === f) },
            h('b', {}, CAMERA_FILMS.includes(f) ? `${CAMERA_FILMS.indexOf(f) + 1}. ${f.name}` : f.name), h('small', {}, f.film)),
          have.has(f.name) ? h('span', { class: 'in-list-tag', title: `Already in "${LISTS.current}": ${have.get(f.name)!.join(', ')}` }, '✓ ', have.get(f.name)!.join(', ')) : null,
          h('button', { class: 'film-add', onclick: () => add(f), title: `Add ${f.name} to your looks` }, '+ Add')))));
    list.replaceChildren(...(sections.length ? sections : [h('p', { class: 'empty' }, 'No film matches.')]));
  };
  const chips = h('div', { class: 'seg film-groups', role: 'radiogroup', 'aria-label': 'Film type' },
    ...([['all', 'All'], ['camera', 'The 20']] as [FilmGroup | 'all' | 'camera', string][]).concat(FILM_GROUPS.map(([g, l]) => [g, l.replace(' simulations', '')] as [FilmGroup, string])).map(([g, t]) =>
      h('button', { role: 'radio', 'aria-checked': String(g === group), class: g === group ? 'on' : '', onclick: (e: Event) => {
        group = g; (e.currentTarget as HTMLElement).parentElement!.querySelectorAll('button').forEach((b) => { const on = b === e.currentTarget; b.classList.toggle('on', on); b.setAttribute('aria-checked', String(on)); });
        drawRows();
      } }, t)));
  const search = h('input', { type: 'search', placeholder: 'Search films…', 'aria-label': 'Search films', oninput: (e: Event) => { query = (e.target as HTMLInputElement).value; drawRows(); } });
  const body = h('div', { class: 'film-dlg' },
    h('div', { class: 'film-side' }, pv, pvNote),
    h('div', { class: 'film-main' }, h('div', { class: 'film-filters' }, search, chips), list));
  drawRows(); drawPv();
  modal(into ? `Film sim for ${at(into.k, into.v)}` : 'Film sims', body);
}

function renderOm3Editor(l: Look) {
  // v0.21: Grain with Glow / Clarity or an Art Effect takes the camera's slow route: say so next to the Grain setting
  const grainWarn = h('p', { class: 'warn', role: 'status' });
  const showWarn = () => {
    grainWarn.replaceChildren(
      ...(slowGrain(l) ? [h('b', {}, 'Slower saving: '), 'Glow / Clarity and Frame together with grain use a slower way (about 3 seconds more per photo, no fast burst). Grain with any one of them, or with Shading, is as fast as normal. '] : []),
      ...(monoGrain(l) ? [h('b', {}, 'Firmware v0.24.1 only: '), 'Shading with grain turned the photo black and white there, so looks saved for v0.24.1 get Shading 0.'] : []));
    grainWarn.hidden = !slowGrain(l) && !monoGrain(l);
  };
  const fxChanged = () => { changed(); showWarn(); };
  showWarn();
  const el = $('#editor');
  const k = O.k, v = O.v;
  const changed = () => { save(); schedulePreview(); refreshProblems(); };
  const np = om3NameProblem(l.name);
  const nameInput = h('input', {
    type: 'text', value: l.name, maxlength: OM3_NAME_MAX, spellcheck: 'false', autocomplete: 'off', 'aria-describedby': 'name-help',
    onchange: checkpoint, onkeydown: enterCommits,
    oninput: (e: Event) => draft(() => {
      l.name = (e.target as HTMLInputElement).value;
      const p = om3NameProblem(l.name);
      $('#name-help').textContent = p ?? `${l.name.length} / ${OM3_NAME_MAX} · shown under the wheel on the Film page`;
      $('#name-help').className = p ? 'help err' : 'help';
      const row = document.querySelector(`#list li[data-at="${k * PER + v}"] .nm`);
      if (row) row.textContent = l.name || '(no name)';
      changed();
    }),
  });
  const setting = (label: string, lim: number, get: () => number, set: (x: number) => void, tip: string) => {
    const { inp, out } = slider(-lim, lim, get(), (x) => { set(x); changed(); }, undefined, label);
    return h('div', { class: 'srow plain', title: tip }, h('span', { class: 'sname' }, label), inp, out);
  };
  const notesBytes = () => new TextEncoder().encode(l.notes).length;
  const film = filmOf(l), orig = film ? undefined : libraryOrigin(l, LIBRARY);
  el.replaceChildren(
    h('div', { class: 'ed-head' },
      h('label', { class: 'field grow' }, h('span', { class: 'lbl' }, `Name · ${at(k, v)}`), nameInput,
        h('span', { id: 'name-help', class: np ? 'help err' : 'help' }, np ?? `${l.name.length} / ${OM3_NAME_MAX} · shown under the wheel on the Film page`)),
      h('div', { class: 'ed-btns' },
        h('button', {
          class: 'share-btn', title: film ? `Restore the ${film.name} film sim's values` : orig ? `Restore the built-in "${orig.name}" values (OM-3 version)` : 'Set every value to neutral',
          onclick: () => {
            const r = film ? Object.assign(filmLook(film), { name: l.name }) : toOm3(resetLook(l, LIBRARY, [])).look ?? blankProfile(l.name);
            O.bank[k][v] = r; save(); renderAll();
            toast(film ? `"${r.name}" restored to the ${film.name} film sim` : orig ? `"${r.name}" restored to the built-in values` : `"${l.name}" reset to neutral`);
          },
        }, 'Reset look'),
        h('button', { class: 'share-btn', onclick: () => om3ShareProfile(l), title: 'Share this look as a link' }, 'Share'))),
    sectorPanel(l, changed),
    tonePanel(l, changed),
    splitPanel(l, changed),
    h('div', { class: 'group' },
      h('span', { class: 'lbl' }, 'Camera settings'),
      setting('Contrast', OM3.contrast, () => l.advice.contrast ?? 0, (x) => { l.advice.contrast = x; }, 'The camera\'s Contrast for this look'),
      setting('Shading', OM3.shading, () => l.vignette, (x) => { l.vignette = x; }, 'The camera\'s Shading (− darker corners, + lighter)'),
      h('p', { class: 'help' }, 'Choosing the look on the camera sets its Contrast and Shading (Picture Mode menu items) to these. (Firmware v0.24.1 hid Shading: looks saved for it get Shading 0.)')),
    h('div', { class: 'group' },
      h('span', { class: 'lbl' }, 'Extras (camera firmware v0.20; lens correction and Grain v0.21; Sharp v0.22; NR High v0.23)'),
      seg('NR', [['off', 'Camera'], ['film', 'Off'], ['fine', 'Low'], ['standard', 'Std'], ['high', 'High']], l.grain,
        (x) => { l.grain = x as Look['grain']; renderEditor(); changed(); }),
      h('p', { class: 'help' }, 'The camera\'s noise reduction (Noise Filter) for each photo with this look; Camera leaves your menu setting. Extras sector 1. High needs firmware v0.23 (for older firmware it is saved as Std).')),
    h('div', { class: 'group' },
      seg('Lens vignette correction', [['off', 'Off (default)'], ['on', 'Keep camera\'s']], l.lens_correction ? 'on' : 'off', (v) => {
        if (v === 'on') l.lens_correction = true; else delete l.lens_correction;
        renderEditor(); changed();
      }),
      h('p', { class: 'help' }, 'Off turns the camera\'s lens shading correction (Shading Comp.) off for photos with this look, for natural corners, without changing the menu setting; Keep follows your menu setting. Extras sector 8 (VigFix, firmware v0.21). Not shown in the preview.')),
    h('div', { class: 'group' },
      seg('Grain', [['0', 'Off'], ['1', 'Low'], ['2', 'Med'], ['3', 'High']], String(l.film_grain ?? 0), (v) => {
        if (v === '0') delete l.film_grain; else l.film_grain = Number(v);
        renderEditor(); changed();
      }),
      h('p', { class: 'help' }, 'Film grain from the camera\'s own grain engine, the same texture as its Monochrome grain, on the colour photo. Extras sector 9 (firmware v0.21). Shown in the preview.'),
      grainWarn),
    h('div', { class: 'group' }, (() => {
      const { inp, out } = slider(SHARP.lo, SHARP.hi, l.advice.sharpness ?? 0, (x) => { l.advice.sharpness = x; changed(); }, sharpLabel, 'Sharp');
      return h('div', { class: 'srow plain', title: 'The camera\'s sharpening for photos with this look' }, h('span', { class: 'sname' }, 'Sharp'), inp, out);
    })(),
      h('p', { class: 'help' }, 'The camera\'s sharpening for photos with this look, in its own numbers: 0 is its normal, +1 and +2 crisper, −1 to −4 softer (−3 and −4 go past the camera\'s menu) and Off (−5) no sharpening at all. Extras sector 10 (firmware v0.22, which takes the Sharpness item off the COLOR screen). Shown roughly in the preview.')),
    h('p', { class: 'warn' }, h('b', {}, 'Firmware v0.25: '), 'Glow / Clarity has its own row on the camera\'s Picture Mode screen (called Glow: + is Glow, − is Clarity), and grain stays as fast as normal with it. Art Effects are not used on v0.25 (Shading does the dark corners).'),
    effectPanel(l, fxChanged),
    h('label', { class: 'field' }, h('span', { class: 'lbl' }, 'Art Effect'),
      h('select', { onchange: (e: Event) => { l.art_effect = (e.target as HTMLSelectElement).value as Look['art_effect']; fxChanged(); } },
        ...OM3_ARTS.filter((a) => a === 'off' || a === l.art_effect).map((a) => h('option', { value: a, selected: a === l.art_effect }, ({ off: 'Off', star_light: 'Star Light (not on v0.25)', pin_hole: 'Pin Hole (not on v0.25)', white_edge: 'White Edge (not on v0.25)', frame: 'Frame (not on v0.25)' } as Record<string, string>)[a]))),
      h('span', { class: 'help' }, 'Not used on v0.25: looks saved for v0.25 always have it Off. Older firmware (v0.24.1 and before) ignores it too or uses it only as noted there.')),
    wbPanel(l, changed),
    h('label', { class: 'field' }, h('span', { class: 'lbl' }, 'Notes'),
      h('textarea', {
        rows: 3, maxlength: 400, placeholder: 'What the look is for…', onchange: checkpoint,
        oninput: (e: Event) => draft(() => {
          l.notes = (e.target as HTMLTextAreaElement).value;
          const b = notesBytes();
          $('#notes-help').textContent = `${b} / ${NOTE_MAX} bytes · kept in the looks file (not on the card)`;
          $('#notes-help').className = b > NOTE_MAX ? 'help err' : 'help';
          changed();
        }),
      }, l.notes),
      h('span', { id: 'notes-help', class: notesBytes() > NOTE_MAX ? 'help err' : 'help' }, `${notesBytes()} / ${NOTE_MAX} bytes · kept in the looks file (not on the card)`)),
    h('div', { id: 'problems' }));
  refreshProblems();
}

// ---- OM-3 links: a whole bank (ob1_) or one look (op1_), deflated JSON. Unlike look codes they keep Contrast and Sharp.
async function zpipe(data: Uint8Array, s: CompressionStream | DecompressionStream): Promise<Uint8Array> {
  const out = new Response(new Blob([data as BlobPart]).stream().pipeThrough(s));
  return new Uint8Array(await out.arrayBuffer());
}
const toB64u = (b: Uint8Array) => { let s = ''; for (const x of b) s += String.fromCharCode(x); return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
const fromB64u = (s: string) => Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
const plainLook = (l: Look) => { const { origin: _o, lib: _l, ...x } = l as Look & { origin?: unknown; lib?: unknown }; return x; };
async function encodeOm3(prefix: string, v: unknown) { return prefix + toB64u(await zpipe(new TextEncoder().encode(JSON.stringify(v)), new CompressionStream('deflate'))); }
async function decodeOm3(prefix: string, t: string): Promise<unknown> {
  const s = t.trim().replace(/^.*#/, '').replace(/\s+/g, '');
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(await zpipe(fromB64u(s.slice(prefix.length)), new DecompressionStream('deflate')))); }
  catch { throw new Error('This link is damaged or incomplete: copy it again.'); }
}
const isOm3Code = (t: string, p: string) => new RegExp(`(^|#)\\s*${p}`).test(t.trim());

function replaceBank(bank: Bank, msg: string, name?: string) {
  O.bank = bank; if (name) O.name = name; O.k = 0; O.v = 0;
  save(); renderAll();
  const probs = validateBank(bank);
  toast(probs.length ? `${msg}. ${probs.length} problem(s) to fix before export.` : msg, probs.length ? 'err' : 'ok');
}
async function om3OnFile(e: Event) {
  const f = (e.target as HTMLInputElement).files?.[0];
  (e.target as HTMLInputElement).value = '';
  if (!f) return;
  const bytes = new Uint8Array(await f.arrayBuffer());
  const magic = bytes.length >= 4 ? String.fromCharCode(...bytes.subarray(0, 4)) : '';
  try {
    if (magic === 'OM3P') { replaceBank(readProfiles(bytes), `Opened ${f.name} (${readProfiles(bytes).flat().filter(Boolean).length} looks)`); return; }
    if (magic === 'OM3N') { toast('That is NAMES.BIN (the name pictures). Open LOOKS.BIN instead: it holds the names too.', 'err'); return; }
    const j = JSON.parse(new TextDecoder().decode(bytes));
    if (j && j.schema === BANK_SCHEMA) { const b = parseBank(j, parseLook); replaceBank(b.bank, `Opened "${b.name}"`, b.name); return; }
    throw new Error('not an OM-3 file');
  } catch (err) { toast(`Not an OM-3 LOOKS.BIN or looks file: ${(err as Error).message}`, 'err'); }
}

async function om3ImportCode(t: string, fromLink: boolean): Promise<boolean> {
  try {
    if (isOm3Code(t, OB_PREFIX)) {
      const b = parseBank(await decodeOm3(OB_PREFIX, t), parseLook);
      const n = b.bank.flat().filter(Boolean).length;
      if (!confirm(`Open the shared looks "${b.name}" (${n} looks)? They replace your current looks (Undo brings them back).`)) return fromLink;
      replaceBank(b.bank, `Opened "${b.name}"`, b.name);
      return true;
    }
    if (!isOm3Code(t, OP_PREFIX)) throw new Error('This is not an OM-3 look link (it starts with op1_ or ob1_).');
    const c: { look: Look | null; changed: string[]; dropped: string[] } = { look: parseLook(await decodeOm3(OP_PREFIX, t), 'look'), changed: [], dropped: [] };
    if (!c.look) throw new Error('That link holds no look.');
    let k = O.k, v = O.v;
    if (O.bank[k][v]) {
      const free = O.bank[k].findIndex((x) => !x);
      if (free >= 0) v = free;
      else {
        const any = O.bank.flat().findIndex((x) => !x);
        if (any >= 0) { k = Math.floor(any / PER); v = any % PER; }
        else if (!confirm(`All 20 looks are in use. Replace ${at(O.k, O.v)} ("${O.bank[k][v]!.name}") with "${c.look.name}"?`)) return false;
      }
    }
    O.bank[k][v] = c.look; O.k = k; O.v = v;
    save(); renderAll();
    toast(`Added "${c.look.name}" as ${at(k, v)}${om3Changes(c)}`);
    return true;
  } catch (e) {
    importCodeMsg((e as Error).message);
    return false;
  }
}

async function om3Share() {
  const code = await encodeOm3(OB_PREFIX, { schema: BANK_SCHEMA, name: O.name, bank: O.bank.map((r) => r.map((l) => (l ? plainLook(l) : null))) });
  const link = `${shareBase()}?camera=om3#${code}`;
  modal('Share these looks', h('div', { class: 'share' },
    h('p', {}, `A link to all ${O.bank.flat().filter(Boolean).length} OM-3 looks (names, notes, Contrast / Sharp / Shading). Opening it loads them here. Everything is inside the link itself: nothing is stored on a server.`),
    h('div', { class: 'code-box link' }, h('input', { type: 'text', readonly: true, value: link, onfocus: (e: Event) => (e.target as HTMLInputElement).select() }),
      h('button', { onclick: () => copy(link, 'Link copied') }, 'Copy link')),
    h('p', { class: 'help' }, `${link.length} characters. For one look, use the Share button next to its name.`)));
}

async function om3ShareProfile(l: Look) {
  const code = await encodeOm3(OP_PREFIX, plainLook(l));
  const link = `${shareBase()}?camera=om3#${code}`;
  modal(`Share "${l.name}"`, h('div', { class: 'share' },
    h('p', {}, 'A link to this OM-3 look, with everything in it (including Contrast, Sharp and Shading):'),
    h('div', { class: 'code-box link' }, h('input', { type: 'text', readonly: true, value: link, onfocus: (e: Event) => (e.target as HTMLInputElement).select() }),
      h('button', { onclick: () => copy(link, 'Link copied') }, 'Copy link')),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'RapidRAW preset'), h('p', { class: 'help' }, 'This look as a .rrpreset for RapidRAW (Presets › Import), for ORF files. An approximation of the camera look.')),
      h('button', { onclick: () => download(`${rrName(l.name)}.rrpreset`, rrpreset(bankPack([l]), 0), 'application/json') }, 'Download'))));
}
const bankPack = (looks: Look[]): Pack => ({ schema: PACK_SCHEMA, name: O.name, looks, slots: {} });

function om3InstallDialog() {
  const link = (href: string, text: string) => h('a', { href, target: '_blank', rel: 'noopener' }, text);
  const code = (t: string) => h('code', {}, t);
  const step = (title: string, ...body: (Node | string | null)[]) => h('li', { class: 'step' }, h('b', {}, title), h('div', { class: 'step-body' }, ...body));
  const exportBtn = h('button', { onclick: () => { dlg.close(); om3ExportDialog(); } }, 'Open Export');
  const body = h('div', { class: 'install' },
    h('p', { class: 'warn' }, '⚠️ Unofficial, experimental firmware. Flashing can brick your camera; you do this at your own risk. The restore files return the camera to stock.'),
    h('ol', { class: 'steps' },
      step('Check your camera',
        h('p', {}, 'OM SYSTEM ', h('b', {}, 'OM-3'), ' on firmware ', h('b', {}, '1.1'), ' (Setup › Firmware), a charged battery and an SD card formatted in the camera.')),
      step('Get Python 3.10+ (once)',
        h('p', {}, link('https://www.python.org/downloads/', 'python.org/downloads'), '. macOS: afterwards run ', code('Install Certificates.command'), ' in the Python folder.')),
      step('Download Caduceus for OM-3',
        h('p', {}, 'Open the ', link(`${OM3_GH}/releases/latest`, 'latest release'), ', download ', h('b', {}, 'Source code (zip)'), ' and unzip it. There is no firmware file to download: OM\'s licence means you build it yourself from the official firmware.')),
      step('Build',
        h('p', {}, 'Run ', code('firmware/patch.py'), ' (the guide shows how). It gets OM\'s official firmware, applies the patch, checks every file and writes an ', code('SD card files'), ' folder: copy ', code('DCOLYMP'), ' and ', code('OM3MOD'), ' to the root of the card. Keep ', code('restore/'), ' on your computer.')),
      step('Your looks: LOOKS.BIN + NAMES.BIN (optional)',
        h('p', {}, 'Looks can be made on the camera itself (Film page). To use the ones here instead:'),
        h('ol', { class: 'substeps' },
          h('li', {}, 'To keep looks made on the camera, first ', h('b', {}, 'Open…'), ' the card\'s ', code('OM3MOD/LOOKS.BIN'), ' here (', code('PROFILES.BIN'), ' before v0.19).'),
          h('li', {}, 'Edit, then ', h('b', {}, 'Export'), ' › Save to the SD card (or download the card folder zip).'),
          h('li', {}, 'Put the card back and half-press once.')),
        exportBtn),
      step('Flash',
        h('p', {}, 'Put the card in the camera, hold ', h('b', {}, 'OK'), ' and switch on. Wait for the update to finish (blinking LED) and don\'t switch off meanwhile. Then delete ', code('DCOLYMP/E1479999.BIN'), ' from the card.')),
      step('Shoot',
        h('p', {}, 'Picture Mode: after COLOR 1–4 the list shows ', h('b', {}, 'FILM 1–20'), ', in the order you set here. Pick one, then adjust its settings in the rows beside it; changes are saved into that film.')))
  );
  const dlg = modal('Install Caduceus for OM-3', body, [
    h('a', { class: 'btn', href: `${OM3_GH}/blob/main/docs/INSTALL.md`, target: '_blank', rel: 'noopener' }, 'Full guide on GitHub'),
    h('a', { class: 'btn primary', href: `${OM3_GH}/releases/latest`, target: '_blank', rel: 'noopener' }, 'Latest release'),
  ]);
}

type DirHandle = { name: string; getDirectoryHandle(n: string, o?: { create?: boolean }): Promise<DirHandle>; getFileHandle(n: string, o?: { create?: boolean }): Promise<{ createWritable(): Promise<{ write(d: BlobPart): Promise<void>; close(): Promise<void> }> }>; values(): AsyncIterable<{ name: string }> };
async function om3ToCard(files: { name: string; data: Uint8Array }[]) {
  const pick = (window as unknown as { showDirectoryPicker?: (o?: object) => Promise<DirHandle> }).showDirectoryPicker;
  if (!pick) { toast('This browser can\'t write to a folder: use the card folder zip instead.', 'err'); return; }
  let dir: DirHandle;
  try { dir = await pick({ mode: 'readwrite', id: 'om3card' }); } catch { return; }
  try {
    let om3 = dir;
    if (dir.name.toUpperCase() !== 'OM3MOD') om3 = await dir.getDirectoryHandle('OM3MOD', { create: true });
    for (const f of files) {
      const w = await (await om3.getFileHandle(f.name, { create: true })).createWritable();
      await w.write(f.data as BlobPart); await w.close();
    }
    toast(`Saved ${files.map((f) => f.name).join(' and ')} to ${dir.name === om3.name ? dir.name : `${dir.name}/OM3MOD`}. Put the card in the camera and half-press.`);
  } catch (e) { toast(`Could not write to the card: ${(e as Error).message}`, 'err'); }
}

function om3ExportDialog() {
  const probs = validateBank(O.bank);
  const fname = (O.name || 'om3-looks').replace(/[^\w.-]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'om3-looks';
  const n = O.bank.flat().filter(Boolean).length;
  const bankJson = () => JSON.stringify({ schema: BANK_SCHEMA, name: O.name, bank: O.bank.map((r) => r.map((l) => (l ? plainLook(l) : null))) }, null, 1) + '\n';
  let fw: Fw = 24; try { const s = localStorage.getItem('caduceus.om3.fw'); if (s === '20' || s === '21' || s === '22' || s === '23' || s === '24' || s === '25') fw = Number(s) as Fw; } catch { /* storage blocked */ }
  const looksBin = () => profilesBin(O.bank, fw);
  const fwSel = h('select', { onchange: (e: Event) => {
    fw = Number((e.target as HTMLSelectElement).value) as Fw;
    try { localStorage.setItem('caduceus.om3.fw', String(fw)); } catch { /* storage blocked */ }
    renderEditor(); schedulePreview();   // v0.26: split toning shows only with the v0.26 export
  } }, h('option', { value: '25', selected: fw === 25 }, 'v0.26 or later (split toning; firmware in testing)'), h('option', { value: '24', selected: fw === 24 }, 'v0.25'), h('option', { value: '23', selected: fw === 23 }, 'v0.24.1'), h('option', { value: '22', selected: fw === 22 }, 'v0.22'), h('option', { value: '21', selected: fw === 21 }, 'v0.21'), h('option', { value: '20', selected: fw === 20 }, 'v0.20 or older'));
  const cardFiles = async () => [{ name: 'LOOKS.BIN', data: looksBin() }, { name: 'NAMES.BIN', data: await namesBin(O.bank) as Uint8Array }];
  const busy = async (b: HTMLButtonElement, f: () => Promise<void>) => { b.disabled = true; try { await f(); } catch (e) { toast((e as Error).message, 'err'); } finally { b.disabled = probs.length > 0; } };
  const looks = O.bank.flat().filter(Boolean) as Look[];
  const rrAll = () => makeZip(looks.map((l, i) => ({ name: `${String(i + 1).padStart(2, '0')}-${rrName(l.name)}.rrpreset`, data: new TextEncoder().encode(rrpreset(bankPack(looks), i)) })));
  const fmt = (p: Problem) => (p.look !== undefined ? `${at(Math.floor(p.look / PER), p.look % PER)} (${O.bank[Math.floor(p.look / PER)][p.look % PER]?.name || 'no name'}): ` : '') + p.message;
  const toCard: HTMLButtonElement = h('button', { class: 'primary', disabled: probs.length > 0, onclick: () => busy(toCard, async () => om3ToCard(await cardFiles())) }, 'Save to card…');
  const zip: HTMLButtonElement = h('button', {
    disabled: probs.length > 0, onclick: () => busy(zip, async () => {
      const files = (await cardFiles()).map((f) => ({ name: `OM3MOD/${f.name}`, data: f.data }));
      files.push({ name: `${fname}.om3.json`, data: new TextEncoder().encode(bankJson()) });
      download(`${fname}-card.zip`, makeZip(files), 'application/zip');
    }),
  }, 'Download');
  const names: HTMLButtonElement = h('button', { disabled: probs.length > 0, onclick: () => busy(names, async () => download('NAMES.BIN', await namesBin(O.bank) as Uint8Array)) }, 'NAMES.BIN');
  modal('Export for the OM-3', h('div', { class: 'export' },
    probs.length
      ? h('div', { class: 'problems-box' }, h('b', {}, `${probs.length} problem(s) to fix first:`), h('ul', { class: 'problems' }, ...probs.slice(0, 12).map((p) => h('li', {}, fmt(p)))))
      : h('p', { class: 'ok' }, `✓ ${n} looks pass the camera's checks (Caduceus for OM-3 v0.19 or later; NR, Glow / Clarity and Art Effects need v0.20, Grain and lens correction v0.21, Sharp v0.22, older firmware ignores them; on v0.17–v0.18 use the PROFILES.BIN file below).`),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'Firmware on the camera'), h('p', { class: 'help' }, 'v0.22 adds Sharp, v0.21 Grain and the lens vignette correction choice to LOOKS.BIN. Older firmware would reject a file with the newer settings, so they are left out for it: for v0.21 the look\'s sharpness goes to the camera\'s Sharpness setting instead (−2 to +2, softer values as −2); for v0.20 and older there is no grain either and every look keeps the camera\'s correction.')),
      fwSel),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'Save to the SD card'), h('p', { class: 'help' }, 'Pick the card (or its OM3MOD folder): writes OM3MOD/LOOKS.BIN and NAMES.BIN. This replaces the looks on the card, including ones made on the camera: Open… the card\'s LOOKS.BIN first to keep those. Chrome / Edge.')),
      toCard),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'Card folder (.zip)'), h('p', { class: 'help' }, 'OM3MOD/LOOKS.BIN, OM3MOD/NAMES.BIN and the looks file. Unzip at the card root (never into DCOLYMP/).')),
      zip),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'Single files'), h('p', { class: 'help' }, 'LOOKS.BIN: the 20 looks. NAMES.BIN: their names as the camera shows them under the wheel ("Empty" for unused numbers). Both go in OM3MOD/. Still on firmware v0.17–v0.18? It reads the same looks as PROFILES.BIN.')),
      h('div', { class: 'ex-btns' },
        h('button', { disabled: probs.length > 0, onclick: () => download('LOOKS.BIN', looksBin()) }, 'LOOKS.BIN'),
        h('button', { disabled: probs.length > 0, title: 'For firmware v0.17–v0.18', onclick: () => download('PROFILES.BIN', profilesBin(O.bank, 20)) }, 'PROFILES.BIN'),
        names)),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'Looks file (.json)'), h('p', { class: 'help' }, 'Everything, including notes. Open it here later or send it to someone.')),
      h('button', { onclick: () => download(`${fname}.om3.json`, bankJson(), 'application/json') }, 'Download')),
    h('div', { class: 'ex-row' },
      h('div', {}, h('b', {}, 'RapidRAW presets (.rrpreset)'), h('p', { class: 'help' }, 'Every look as its own preset in a zip, for ORF files. Approximate.')),
      h('button', { disabled: !looks.length, onclick: () => download(`${fname}-rapidraw.zip`, rrAll(), 'application/zip') }, `All ${looks.length} (.zip)`)),
    h('p', { class: 'help' }, 'The camera checks every file and ignores one that fails. A new LOOKS.BIN keeps the camera on its current setting until you pick a film.')));
}

// ---------------------------------------------------------------- start
async function handleHash() {
  const code = decodeURIComponent(location.hash.slice(1));
  if (!code) return;
  history.replaceState(null, '', location.pathname + location.search);
  importCodeMsg = (m) => toast(`Link: ${m}`, 'err');
  await om3ImportCode(code, true);
  importCodeMsg = (m) => toast(m, 'err');
}

shell();
renderAll();
if (libNotice) toast(libNotice);
undoUi();
handleHash();
window.addEventListener('hashchange', handleHash);
