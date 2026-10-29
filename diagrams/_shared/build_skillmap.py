#!/usr/bin/env python3
"""Build one skill-map page: python3 diagrams/_shared/build_skillmap.py <map>
Reads diagrams/<map>/map.py (function build() -> dict) and writes diagrams/<map>/index.html as one self-contained file.
See diagrams/_shared/README.md for the dict contract and how to add a map."""
import html, importlib.util, json, sys
from pathlib import Path
SH = Path(__file__).resolve().parent
name = sys.argv[1]
mdir = SH.parent / name
sys.path.insert(0, str(mdir))
spec = importlib.util.spec_from_file_location(name + "_map", mdir / "map.py")
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
m = mod.build()
rd = lambda f: (SH / f).read_text(encoding="utf-8")
e = html.escape
NAV = rd("sitenav.html")
for k in ("skill", "impeccable", "pstack"):
    NAV = NAV.replace("%%A_" + k + "%%", ' aria-current="page"' if k == m["key"] else "")
flt = ""
if m.get("filter"):
    f = m["filter"]
    flt = f'<div class="seg" role="group" aria-label="{e(f["label"])}">' + "".join(
        f'<button type="button" data-f="{e(v)}" aria-pressed="{"true" if i == 0 else "false"}" aria-label="{e(l)}" title="{e(l)}">{icon}</button>' for i, (v, l, icon) in enumerate(f["options"])) + "</div>"
order = "".join(f'<div class="step {c}"><i>{e(n)}</i><span><b>{e(t)}</b><small>{e(s)}</small></span></div>' for n, t, s, c in m["order"])
t = rd("shell.html")
for k, v in {"%%TITLE%%": e(m["title"]), "%%VERSION%%": e(m["version"]), "%%SUBTITLE%%": m["subtitle"], "%%NAV%%": NAV, "%%FILTER%%": flt,
             "%%TOOLS%%": m.get("tools", ""), "%%SVG%%": m["svg"], "%%LEGEND%%": m.get("legend", ""), "%%ORDER%%": order, "%%FOOTER%%": m["footer"],
             "%%SHELLCSS%%": rd("shell.css") + "\n:root{--mapw:%dpx}" % m["mapw"], "%%SMCSS%%": rd("skillmap.css"), "%%PAGECSS%%": m["css"],
             "%%SMJS%%": rd("skillmap.js"), "%%PAGEJS%%": m["js"], "%%SHELLJS%%": rd("shell.js"), "%%CANVASJS%%": rd("canvas.js")}.items():
    t = t.replace(k, v)
(mdir / "index.html").write_text(t, encoding="utf-8")
print(mdir / "index.html", len(t))
