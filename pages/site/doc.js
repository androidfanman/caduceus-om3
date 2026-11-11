// Renders one of the repo's Markdown guides (docs/*.md) as a page. The Markdown file stays the one source:
// edit docs/INSTALL.md or docs/USING.md and this page follows.
(function () {
  const REPO = "https://github.com/androidfanman/caduceus-om3";
  const main = document.getElementById("doc");
  const src = main.dataset.src;                 // e.g. "../docs/INSTALL.md"
  const srcPath = main.dataset.path;            // e.g. "docs/INSTALL.md" (path in the repo)
  const srcDir = srcPath.replace(/[^/]*$/, ""); // "docs/"

  // Pages that have their own site page; anything else opens on GitHub.
  const PAGES = { "docs/INSTALL.md": "../install/", "docs/USING.md": "../using/", "ROADMAP.md": "../roadmap/", "CHANGELOG.md": "../changelog/", "docs/FAQ.md": "../faq/" };

  function slug(text) {
    return text.trim().toLowerCase().replace(/[^\w\- ]+/g, "").replace(/ /g, "-");
  }
  function resolve(rel) {
    const parts = (srcDir + rel).split("/");
    const out = [];
    for (const p of parts) { if (p === "..") out.pop(); else if (p !== ".") out.push(p); }
    return out.join("/");
  }
  function fixLink(a) {
    const href = a.getAttribute("href") || "";
    if (/^(https?:|mailto:)/.test(href)) return;
    if (href.startsWith("#")) return;
    const [path, hash] = href.split("#");
    const full = resolve(path);
    if (PAGES[full]) a.setAttribute("href", PAGES[full] + (hash ? "#" + hash : ""));
    else a.setAttribute("href", REPO + "/blob/main/" + full + (hash ? "#" + hash : ""));
  }

  async function run() {
    let text;
    try {
      const r = await fetch(src, { cache: "no-cache" });
      if (!r.ok) throw new Error(r.status);
      text = await r.text();
    } catch (e) {
      main.innerHTML = "";
      const p = document.createElement("p");
      p.className = "err";
      p.append("This page couldn't load. ");
      const a = document.createElement("a");
      a.href = REPO + "/blob/main/" + srcPath;
      a.textContent = "Read it on GitHub instead.";
      p.append(a);
      main.append(p);
      return;
    }

    const tmp = document.createElement("div");
    tmp.innerHTML = marked.parse(text, { gfm: true });

    // GitHub-style callouts: > [!NOTE] / > [!WARNING] / > [!TIP]
    tmp.querySelectorAll("blockquote").forEach(bq => {
      const first = bq.querySelector("p");
      const m = first && first.innerHTML.match(/^\s*\[!(NOTE|WARNING|TIP|IMPORTANT|CAUTION)\]\s*(<br>)?\s*/i);
      if (!m) return;
      first.innerHTML = first.innerHTML.slice(m[0].length);
      const kind = m[1].toLowerCase();
      const box = document.createElement("div");
      box.className = "callout " + (kind === "caution" || kind === "important" ? "warning" : kind);
      const t = document.createElement("p");
      t.className = "ct";
      t.textContent = { note: "Note", warning: "Warning", tip: "Tip", important: "Important", caution: "Caution" }[kind];
      box.append(t, ...bq.childNodes);
      bq.replaceWith(box);
    });
    tmp.querySelectorAll("a").forEach(fixLink);
    tmp.querySelectorAll("td").forEach(td => { if (/^\d{4}-\d{2}-\d{2}$/.test(td.textContent.trim())) td.style.whiteSpace = "nowrap"; });
    tmp.querySelectorAll("table").forEach(t => {
      const w = document.createElement("div");
      w.className = "tablewrap";
      t.replaceWith(w); w.append(t);
    });

    // Build: title + intro (before the first h2), table of contents, one card per h2 section.
    const nodes = [...tmp.childNodes];
    const lead = document.createElement("div");
    lead.className = "lead";
    const cards = [];
    let cur = null;
    for (const n of nodes) {
      if (n.nodeType === 1 && n.tagName === "H1") { document.title = n.textContent + " · Caduceus for OM-3"; lead.prepend(n); continue; }
      if (n.nodeType === 1 && n.tagName === "H2") {
        const title = n.textContent;
        n.id = slug(title);
        cur = document.createElement("section");
        cur.className = "card";
        cur.id = "s-" + n.id;
        const step = title.match(/^Step (\d+)\.\s*(.*)$/);
        if (step) {
          cur.classList.add("step");
          const num = document.createElement("div");
          num.className = "num";
          num.setAttribute("aria-hidden", "true");
          num.textContent = step[1];
          cur.append(num);
        }
        cur.append(n);
        cards.push({ el: cur, title, id: n.id });
        continue;
      }
      if (n.nodeType === 8) continue;                       // HTML comments (picture placeholders)
      if (n.nodeType === 3 && !n.textContent.trim()) continue;
      (cur || lead).append(n);
    }
    main.innerHTML = "";
    main.append(lead);
    if (cards.length > 2 && main.dataset.toc !== "off") {
      const toc = document.createElement("nav");
      toc.className = "toc";
      toc.setAttribute("aria-label", "On this page");
      cards.forEach(c => {
        const a = document.createElement("a");
        a.href = "#" + c.id;
        a.textContent = c.title.replace(/^Step (\d+)\.\s*/, "$1. ");
        toc.append(a);
      });
      main.append(toc);
    }
    cards.forEach(c => main.append(c.el));
    if (location.hash) {
      const t = document.getElementById(decodeURIComponent(location.hash.slice(1)));
      if (t) t.scrollIntoView();
    }
  }
  run();
})();
