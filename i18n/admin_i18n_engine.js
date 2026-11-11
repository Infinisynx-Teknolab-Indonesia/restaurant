/* Mesin terjemahan admin panel: menerjemahkan teks DOM secara otomatis (Indonesia → English / 中文).
   Kode admin tetap menulis Bahasa Indonesia; MutationObserver menerjemahkan setiap teks yang muncul. */
(function () {
  "use strict";
  const DICT = window.RB_I18N_DICT || {};
  const PHRASES = window.RB_I18N_PHRASES || [];
  const LANGS = { id: "ID", en: "EN", zh: "中文" };
  let lang = "id";
  try { lang = localStorage.getItem("rb_lang") || "id"; } catch { /* abaikan */ }
  if (!LANGS[lang]) lang = "id";

  const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  // template "Meja {}" → regex
  const TPL = Object.keys(DICT).filter((k) => k.includes("{}"))
    .map((k) => ({ re: new RegExp("^" + k.split("{}").map(esc).join("(.+?)") + "$", "s"), k, w: k.replace(/\{\}/g, "").length }))
    .sort((a, b) => b.w - a.w);
  // potongan kalimat (untuk teks campuran angka): urut terpanjang dulu
  // hanya frasa (≥ 2 kata) agar data yang diketik admin (nama menu, deskripsi) tidak ikut diterjemahkan kata per kata
  const FRAG_KEYS = Object.keys(DICT).filter((k) => !k.includes("{}") && /\S\s+\S/.test(k.trim()) && k.trim().length >= 6 && /[A-Za-z]/.test(k))
    .sort((a, b) => b.length - a.length);
  let FRAG_RE = null;
  const fragRe = () => FRAG_RE || (FRAG_RE = new RegExp("(?<![A-Za-z\\u00C0-\\u024F])(" + FRAG_KEYS.map(esc).join("|") + ")(?![A-Za-z\\u00C0-\\u024F])", "g"));
  const cache = new Map();

  function tr(s, depth = 0) {
    if (lang === "id" || !s) return s;
    const t = s.trim();
    if (!t || !/[A-Za-z]{2}/.test(t)) return s;
    const key = lang + "\u0000" + s;
    if (cache.has(key)) return cache.get(key);
    const idx = lang === "en" ? 0 : 1;
    const lead = s.slice(0, s.indexOf(t)), trail = s.slice(s.indexOf(t) + t.length);
    let out = null;
    const hit = DICT[t] || DICT[t.replace(/[:：]$/, "")];
    if (hit) out = hit[idx] + (DICT[t] ? "" : t.slice(-1));
    if (out === null && depth < 3) {
      for (const tp of TPL) {
        const m = tp.re.exec(t);
        if (!m) continue;
        let i = 0;
        out = DICT[tp.k][idx].replace(/\{\}/g, () => { i++; return tr(m[i] || "", depth + 1); });
        break;
      }
    }
    if (out === null) {
      out = t.replace(fragRe(), (w) => DICT[w][idx]);
      for (const p of PHRASES) if (out.includes(p[0])) out = out.split(p[0]).join(p[idx + 1]);
    }
    out = lead + out + trail;
    if (cache.size > 5000) cache.clear();
    cache.set(key, out);
    return out;
  }

  // ---------------------------------------------------------- DOM
  const ORIG = new WeakMap(); // node → teks asli (Indonesia)
  const DONE = new WeakMap(); // node → teks hasil terjemahan terakhir
  const ATTRS = ["placeholder", "title", "aria-label", "data-tip"];
  const SKIP = new Set(["SCRIPT", "STYLE", "CODE", "PRE", "TEXTAREA"]);

  function textNode(n) {
    const cur = n.nodeValue;
    if (DONE.get(n) === cur) return;
    ORIG.set(n, cur);
    const out = tr(cur);
    DONE.set(n, out);
    if (out !== cur) n.nodeValue = out;
  }
  function elAttrs(el) {
    for (const a of ATTRS) {
      if (!el.hasAttribute || !el.hasAttribute(a)) continue;
      const cur = el.getAttribute(a), mark = "__rb_" + a;
      if (el[mark] === cur) continue;
      el[mark + "_o"] = cur;
      const out = tr(cur);
      el[mark] = out;
      if (out !== cur) el.setAttribute(a, out);
    }
  }
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) { if (!SKIP.has(root.parentNode?.nodeName) && !root.parentNode?.closest?.(".material-symbols-rounded,[data-noi18n]")) textNode(root); return; }
    if (root.nodeType !== 1 || SKIP.has(root.nodeName)) return;
    if (root.classList?.contains("material-symbols-rounded") || root.hasAttribute?.("data-noi18n") || root.nodeName === "CODE") return;
    elAttrs(root);
    for (const c of root.childNodes) walk(c);
  }
  // kembalikan teks asli lalu terjemahkan ulang (saat ganti bahasa)
  function restore(root) {
    const it = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
    let n = it.currentNode;
    while (n) {
      if (n.nodeType === 3 && ORIG.has(n) && DONE.get(n) === n.nodeValue) { n.nodeValue = ORIG.get(n); DONE.delete(n); }
      if (n.nodeType === 1) for (const a of ATTRS) { const o = n["__rb_" + a + "_o"]; if (o != null && n.getAttribute(a) === n["__rb_" + a]) { n.setAttribute(a, o); n["__rb_" + a] = null; } }
      n = it.nextNode();
    }
  }

  let obs = null;
  function observe() {
    if (obs) return;
    obs = new MutationObserver((muts) => {
      if (lang === "id") return;
      for (const m of muts) {
        if (m.type === "characterData") walk(m.target);
        else if (m.type === "attributes") elAttrs(m.target);
        else m.addedNodes.forEach(walk);
      }
    });
    obs.observe(document.documentElement, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ATTRS });
  }

  function setLang(l) {
    if (!LANGS[l] || l === lang) return;
    restore(document.body);
    lang = l;
    cache.clear();
    try { localStorage.setItem("rb_lang", l); } catch { /* abaikan */ }
    document.documentElement.lang = l === "zh" ? "zh-CN" : l;
    if (l !== "id") walk(document.body);
    document.querySelectorAll(".lang-sw button").forEach((b) => b.classList.toggle("on", b.dataset.l === l));
    window.dispatchEvent(new CustomEvent("rb-lang", { detail: l }));
  }

  // pemilih bahasa (dipakai di topbar & halaman login)
  function switcher() {
    return `<div class="lang-sw" data-noi18n title="Bahasa / Language / 语言">${Object.entries(LANGS).map(([k, v]) => `<button type="button" data-l="${k}" class="${k === lang ? "on" : ""}">${v}</button>`).join("")}</div>`;
  }
  document.addEventListener("click", (e) => { const b = e.target.closest?.(".lang-sw button"); if (b) setLang(b.dataset.l); });

  // dialog bawaan browser ikut diterjemahkan
  const _prompt = window.prompt.bind(window), _confirm = window.confirm.bind(window), _alert = window.alert.bind(window);
  window.prompt = (m, d) => _prompt(tr(String(m ?? "")), d);
  window.confirm = (m) => _confirm(tr(String(m ?? "")));
  window.alert = (m) => _alert(tr(String(m ?? "")));

  window.RBI18N = { tr, setLang, switcher, get lang() { return lang; } };
  const start = () => { document.documentElement.lang = lang === "zh" ? "zh-CN" : lang; observe(); if (lang !== "id") walk(document.body); };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start); else start();
})();
