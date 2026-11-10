import html, json, sys
sys.path.insert(0, sys.argv[1])
from data import AREAS, ROWS, EP7_REF, OM3_REF

LABEL = {"same": "Same", "differs": "Both, different", "ep7": "E-P7 only", "om3": "OM-3 only", "neither": "Neither yet"}
ORDER = ["same", "differs", "ep7", "om3", "neither"]
counts = {k: sum(1 for r in ROWS if r[4] == k) for k in ORDER}

PRIORITIES = [
    ("Agree the panel plan with cakelesscoder", "The E-P7 project wants one shared Control Panel with each camera as a profile; ours went OM-3-only on 2026-11-09. Pick one path before the two panels drift further. Your call; nothing is sent without your OK."),
    ("Make share links open both ways", "Their panel opens our op1_ / ob1_ links; ours no longer opens their pk1_ packs or look codes. Bringing that reader back costs little and means any shared look opens anywhere."),
    ("Propose schema and min_fw upstream", "Added to our looks today. Their rules ask for new fields to be proposed there first, and their copy of our om3.ts will need one more line at their next sync."),
    ("Settle the hue direction", "The two projects report opposite directions for + hue. One same-scene test on both bodies decides whether shared looks turn hue the right way."),
    ("Line up where Grain, NR and Sharp live", "On the E-P7 they are COLOR profile settings, here they are part of the film. A shared look carries them either way, but the two cameras apply them differently."),
    ("Trade features", "To the OM-3: halation (Next), XPan / 21:9, video colour profile, button functions. To the E-P7: split toning, fast colour grain, loading at power-on, the RAW+JPEG grain lesson."),
]

# ---- Markdown (docs/PARITY.md)
md = []
md.append("# Caduceus parity: E-P7 and OM-3\n")
md.append(f"What each Caduceus project has, what lines up and what doesn't, so the look format, share links and Control Panel can stay shared. Compared 2026-11-09 from [cakelesscoder/caduceus-ep7](https://github.com/cakelesscoder/caduceus-ep7) at `{EP7_REF}` (read only) and this repo at `{OM3_REF}`. Statuses are as each project reports them; \"not researched\" means nobody has looked yet.\n")
md.append("Update this page when either project ships a feature, and regenerate the page with `research/tools/parity/make.py`.\n")
md.append("| " + " | ".join(LABEL[k] for k in ORDER) + " |\n|" + "---|" * len(ORDER) + "\n| " + " | ".join(str(counts[k]) for k in ORDER) + " |\n")
md.append("## What to do for parity\n")
for i, (t, d) in enumerate(PRIORITIES, 1):
    md.append(f"{i}. **{t}.** {d}")
md.append("")
for a in AREAS:
    md.append(f"## {a}\n")
    md.append("| Feature | E-P7 | OM-3 | Parity | Notes |\n|---|---|---|---|---|")
    for r in ROWS:
        if r[0] != a: continue
        cell = lambda s: s.replace("|", "/")
        md.append(f"| **{cell(r[1])}** | {cell(r[2])} | {cell(r[3])} | {LABEL[r[4]]} | {cell(r[5])} |")
    md.append("")
open(sys.argv[2], "w").write("\n".join(md))

# ---- HTML page
data = json.dumps([{"area": r[0], "feature": r[1], "ep7": r[2], "om3": r[3], "parity": r[4], "note": r[5]} for r in ROWS], ensure_ascii=False)
pri = "".join(f"<li><strong>{html.escape(t)}.</strong> {html.escape(d)}</li>" for t, d in PRIORITIES)
tiles = "".join(f'<button class="tile" data-p="{k}" aria-pressed="false"><span class="n">{counts[k]}</span><span class="chip {k}">{LABEL[k]}</span></button>' for k in ORDER)
areas = "".join(f'<option value="{html.escape(a)}">{html.escape(a)}</option>' for a in AREAS)
page = open(sys.argv[4]).read()
page = page.replace("%%DATA%%", data).replace("%%PRI%%", pri).replace("%%TILES%%", tiles).replace("%%AREAS%%", areas)
page = page.replace("%%EP7%%", EP7_REF).replace("%%OM3%%", OM3_REF).replace("%%LABELS%%", json.dumps(LABEL)).replace("%%TOTAL%%", str(len(ROWS)))
open(sys.argv[3], "w").write(page)
print(counts, len(ROWS))
