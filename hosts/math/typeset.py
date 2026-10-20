#!/usr/bin/env python3
"""Lay out LaTeX with TeX itself, and hand back where every glyph and rule landed.

    typeset.py <spec.json>

The spec is JSON - never argv, because ghost passes no free text on a command line:
{"items": [{"id", "tex", "mode"}], "out", "work", "width", "outlines", "bin", "data"}. `bin` is the
folder TeX's programs are in (ghost's own TeX; with none, they are looked up on PATH); `data` the
series the episode's runs kept, which a drawing plots by name (figure.py). `mode` is "math" (one
formula, display style, on one line), "display" (a display environment such as `align*`, set in a
column `width` points wide), "text" (a paragraph with $...$ in it, wrapped at `width`) or "figure"
(a DRAWING: `tex` is an SVG, which figure.py turns into pen paths, its labels set by TeX in the same
run). The answer, written to `out`, is one record per item:

    {"id", "ok", "error", "w", "h", "d", "glyphs": [{"k", "f", "c", "n", "x", "y", "s", "w", "ht", "dp"}],
     "rules": [{"k", "x", "y", "w", "h"}]}

in TeX points, y DOWN from the first baseline (TeX's own, marked by a special at the start of the
box; a display's first glyph's where there is none), x from the left edge. `k` is the order TeX set
glyphs and rules in, one count over both - a fraction's bar comes between its numerator and its
denominator, which is the order a hand writes them in. A glyph is its font (`f`, a
TFM name such as cmmi10), its code (`c`), its PostScript name (`n` - "alpha", "summationdisplay",
"radicalbig"), its baseline origin (`x`, `y`), the size it was set at (`s`) and its box from the
TFM (`w`, `ht`, `dp`). THE NAME IS WHAT A HAND READS: the desk's ink draws a pen stroke for the
glyph TeX chose, in the box TeX gave it, so the structure is TeX's and the writing is the hand's.
With "outlines": true the fonts' outline contours come back too (`fonts`), for a glyph no hand has.
A PART THE PEN CAN POINT AT: `\\pin{name}{...}` around part of a formula sets the part as it would
be set anyway and names it - the record's `anchors` is {name: [x0, y0, x1, y1]}, the box of every
glyph and rule set inside it (a drawing's anchors are its elements' ids, figure.py's).
A drawing's record has `figure: true` and its `paths` beside its labels' glyphs and rules:
[{"k", "kind", "pts"}] - "line", "hatch", "dot" or "arrow", points in the record's own convention.

Why TeX and not a lighter engine: a lesson's paper is LaTeX compiled by the same TeX, so the pad
and the paper cannot disagree about what a formula is, and every environment a mathematician
writes (`align*`, `cases`, `pmatrix`) is laid out as a mathematician expects. Why DVI and not
SVG: DVI keeps each glyph's font and code, which an SVG of outlines throws away, and it is
small enough to read here whole (TeX: The Program, part 31).

All items are set in one TeX run (one page each, `\\shipout` of a box, so a page holds nothing
but the item). If the run fails, each item is set alone to find the ones at fault: one bad
formula never costs the others. Exit 0 and the file on success, even when some items failed
(their `ok` is false and `error` says why); anything else is a failure, with the reason on stderr.
"""

import json
import os
import pathlib
import shutil
import struct
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import figure  # noqa: E402  (ghost's own, beside this file: -I keeps the script's folder off the path)

# \pin{name}{tex}: a special before and after the part, which the DVI reader pairs up - nothing
# else changes, since TeX passes a whatsit by in math without spacing round it
PREAMBLE = r"""\documentclass[12pt]{article}
\usepackage{amsmath,amssymb}
\newcommand{\pin}[2]{\special{ghost:pin+#1}#2\special{ghost:pin-#1}}
\pagestyle{empty}
\begin{document}
"""

BASE = r"\special{ghost:base}"  # marks the box's first baseline where TeX knows it


def _box(item, width):
    """The TeX that ships one item as a page holding only its box."""
    tex, mode = item["tex"], item.get("mode", "math")
    if mode == "math":
        body = r"\hbox{%s$\displaystyle %s$}" % (BASE, tex)
    elif mode == "display":
        body = r"\vbox{\hsize=%.2fpt \noindent\parskip=0pt %s}" % (width, tex)
    else:
        body = r"\vbox{\hsize=%.2fpt \noindent\parindent=0pt\raggedright %s%s}" % (width, BASE, tex)
    return "\\setbox0=%s\n\\shipout\\box0\n" % body


_BIN = {"dir": ""}


def _prog(name):
    """A TeX program by its absolute path in ghost's own TeX, or its bare name for PATH."""
    if _BIN["dir"]:
        for cand in (name, name + ".exe"):
            path = os.path.join(_BIN["dir"], cand)
            if os.path.isfile(path):
                return path
    return name


def _run_latex(work, name, items, width):
    src = PREAMBLE + "".join(_box(it, width) for it in items) + "\\end{document}\n"
    (work / (name + ".tex")).write_text(src, encoding="utf-8")
    proc = subprocess.run(
        [_prog("latex"), "-interaction=nonstopmode", "-halt-on-error", "-no-shell-escape", name + ".tex"],
        cwd=work, capture_output=True, text=True, timeout=120,
    )
    dvi = work / (name + ".dvi")
    if proc.returncode != 0 or not dvi.exists():
        return None, _tex_error(proc.stdout)
    return dvi.read_bytes(), ""


def _tex_error(log):
    """The first TeX error and the line it points at, plainly."""
    lines = log.splitlines()
    for i, line in enumerate(lines):
        if line.startswith("!"):
            tail = [x for x in lines[i + 1:i + 3] if x.strip()]
            return " ".join([line[1:].strip()] + [t.strip() for t in tail])[:400]
    return "TeX failed with no error line"


# --- Font files ---------------------------------------------------------------------------------

_FOUND = {}


def _kpse(name):
    if name not in _FOUND:
        out = subprocess.run([_prog("kpsewhich"), name], capture_output=True, text=True).stdout.strip()
        _FOUND[name] = out or None
    return _FOUND[name]


class Tfm:
    """A TFM file's character boxes, as fractions of the design size (TeX: The Program, 539)."""

    def __init__(self, path):
        b = pathlib.Path(path).read_bytes()
        lf, lh, bc, ec, nw, nh, nd, ni, nl, nk, ne, np = struct.unpack(">12H", b[:24])
        base = 24 + lh * 4
        ci = base
        wt = ci + (ec - bc + 1) * 4
        ht = wt + nw * 4
        dt = ht + nh * 4

        def fix(off):
            return struct.unpack(">i", b[off:off + 4])[0] / float(1 << 20)

        self.chars = {}
        for c in range(bc, ec + 1):
            w_i, hd, _it, _rem = b[ci + (c - bc) * 4:ci + (c - bc) * 4 + 4]
            if w_i == 0:
                continue
            self.chars[c] = (fix(wt + w_i * 4), fix(ht + (hd >> 4) * 4), fix(dt + (hd & 15) * 4))


class Type1:
    """A Type 1 font's encoding (code -> glyph name) and, when asked, its outlines."""

    def __init__(self, path):
        from fontTools.t1Lib import T1Font

        self.font = T1Font(path)
        self.font.parse()
        enc = self.font.font.get("Encoding")
        self.names = {}
        if isinstance(enc, list):
            for code, name in enumerate(enc):
                if name and name != ".notdef":
                    self.names[code] = name
        self._glyphs = None

    def contours(self, name):
        """The glyph's closed contours in em units (1000 per em), y up, curves flattened."""
        from fontTools.pens.recordingPen import RecordingPen

        if self._glyphs is None:
            self._glyphs = self.font.getGlyphSet()
        if name not in self._glyphs:
            return []
        pen = RecordingPen()
        self._glyphs[name].draw(pen)
        out, cur, last = [], [], (0.0, 0.0)
        for op, args in pen.value:
            if op == "moveTo":
                if cur:
                    out.append(cur)
                cur = list(args[0])
                last = args[0]
            elif op == "lineTo":
                cur += list(args[0])
                last = args[0]
            elif op == "curveTo":
                p0, (p1, p2, p3) = last, args
                for k in range(1, 9):
                    t = k / 8.0
                    u = 1 - t
                    cur += [
                        u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                        u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
                    ]
                last = p3
            elif op in ("closePath", "endPath"):
                if cur:
                    out.append(cur)
                cur = []
        if cur:
            out.append(cur)
        return [[round(v, 1) for v in c] for c in out]


_TFM, _T1 = {}, {}


def _tfm(name):
    if name not in _TFM:
        path = _kpse(name + ".tfm")
        _TFM[name] = Tfm(path) if path else None
    return _TFM[name]


def _t1(name):
    if name not in _T1:
        path = _kpse(name + ".pfb")
        _T1[name] = Type1(path) if path else None
    return _T1[name]


# --- DVI ----------------------------------------------------------------------------------------


def _pages(dvi):
    """Each page of a DVI file as (glyphs, rules), positions in TeX points, y down."""
    pos, n = 0, len(dvi)
    fonts, pages = {}, []
    conv = 1.0

    def u(k):
        nonlocal pos
        v = int.from_bytes(dvi[pos:pos + k], "big")
        pos += k
        return v

    def s(k):
        nonlocal pos
        v = int.from_bytes(dvi[pos:pos + k], "big", signed=True)
        pos += k
        return v

    h = v = w = x = y = z = 0
    stack, f = [], None
    glyphs, rules, base = [], [], None
    seq = 0
    pins = []          # the \pin parts open now, innermost last

    def put(c, advance):
        nonlocal h, seq
        font = fonts.get(f)
        if font is None:
            return
        tfm = font["tfm"]
        box = tfm.chars.get(c) if tfm else None
        size = font["s"]
        wd = box[0] * size if box else 0.0
        if box:
            t1 = _t1(font["name"])
            seq += 1
            glyphs.append({
                "k": seq, "f": font["name"], "c": c, "n": (t1.names.get(c) if t1 else None) or "",
                "x": h * conv, "y": v * conv, "s": round(size * conv, 4),
                "w": round(wd * conv, 4), "ht": round(box[1] * size * conv, 4),
                "dp": round(box[2] * size * conv, 4),
            })
            if pins:
                glyphs[-1]["a"] = list(pins)
        if advance:
            h += int(round(wd))

    def rule(a, b, advance):
        nonlocal h, seq
        if a > 0 and b > 0:
            seq += 1
            rules.append({"k": seq, "x": h * conv, "y": (v - a) * conv, "w": b * conv, "h": a * conv})
            if pins:
                rules[-1]["a"] = list(pins)
        if advance:
            h += b

    while pos < n:
        op = dvi[pos]
        pos += 1
        if op <= 127:
            put(op, True)
        elif 128 <= op <= 131:
            put(u(op - 127), True)
        elif op == 132:
            a, b = s(4), s(4)
            rule(a, b, True)
        elif 133 <= op <= 136:
            put(u(op - 132), False)
        elif op == 137:
            a, b = s(4), s(4)
            rule(a, b, False)
        elif op == 138:
            pass
        elif op == 139:
            pos += 44
            h = v = w = x = y = z = 0
            stack, f, glyphs, rules, base, seq, pins = [], None, [], [], None, 0, []
        elif op == 140:
            pages.append((glyphs, rules, base))
        elif op == 141:
            stack.append((h, v, w, x, y, z))
        elif op == 142:
            h, v, w, x, y, z = stack.pop()
        elif 143 <= op <= 146:
            h += s(op - 142)
        elif op == 147:
            h += w
        elif 148 <= op <= 151:
            w = s(op - 147)
            h += w
        elif op == 152:
            h += x
        elif 153 <= op <= 156:
            x = s(op - 152)
            h += x
        elif 157 <= op <= 160:
            v += s(op - 156)
        elif op == 161:
            v += y
        elif 162 <= op <= 165:
            y = s(op - 161)
            v += y
        elif op == 166:
            v += z
        elif 167 <= op <= 170:
            z = s(op - 166)
            v += z
        elif 171 <= op <= 234:
            f = op - 171
        elif 235 <= op <= 238:
            f = u(op - 234)
        elif 239 <= op <= 242:
            k = u(op - 238)
            said = dvi[pos:pos + k]
            if said == b"ghost:base" and base is None:
                base = (h * conv, v * conv)
            elif said.startswith(b"ghost:pin+"):
                pins.append(said[10:].decode("latin-1"))
            elif said.startswith(b"ghost:pin-"):
                name = said[10:].decode("latin-1")
                if name in pins:
                    pins.remove(name)
            pos += k
        elif 243 <= op <= 246:
            k = u(op - 242)
            pos += 4
            scale = u(4)
            pos += 4
            a, l = u(1), u(1)
            name = dvi[pos:pos + a + l].decode("latin-1")
            pos += a + l
            fonts[k] = {"name": name, "s": scale, "tfm": _tfm(name)}
        elif op == 247:
            pos += 1
            num, den, mag = u(4), u(4), u(4)
            conv = num / den * mag / 1000.0 / 254000.0 * 72.27  # DVI units to TeX points
            pos += u(1)
        elif op == 248:
            break
        else:
            raise ValueError("unknown DVI opcode %d at %d" % (op, pos - 1))
    return pages


def _record(item, page):
    glyphs, rules, mark = page
    if not glyphs and not rules:
        return {"id": item["id"], "ok": False, "error": "nothing was set", "glyphs": [], "rules": []}
    # The page's own origin is TeX's (1in, 1in) convention plus the box's height: move it to the
    # item's left edge and its first baseline.
    xs = [g["x"] for g in glyphs] + [r["x"] for r in rules]
    left = min(xs)
    if mark is not None:
        base = mark[1]
    else:
        base = glyphs[0]["y"] if glyphs else rules[0]["y"] + rules[0]["h"]
    for g in glyphs:
        g["x"] = round(g["x"] - left, 4)
        g["y"] = round(g["y"] - base, 4)
    for r in rules:
        r["x"] = round(r["x"] - left, 4)
        r["y"] = round(r["y"] - base, 4)
        r["w"] = round(r["w"], 4)
        r["h"] = round(r["h"], 4)
    right = max([g["x"] + g["w"] for g in glyphs] + [r["x"] + r["w"] for r in rules])
    top = min([g["y"] - g["ht"] for g in glyphs] + [r["y"] for r in rules])
    bottom = max([g["y"] + g["dp"] for g in glyphs] + [r["y"] + r["h"] for r in rules])
    return {
        "id": item["id"], "ok": True, "error": "", "w": round(right, 4), "h": round(-top, 4),
        "d": round(bottom, 4), "glyphs": glyphs, "rules": rules, "anchors": _anchors(glyphs, rules),
    }


def _anchors(glyphs, rules):
    """Each \\pin part's box, [x0, y0, x1, y1] in the record's points: every glyph and rule set inside
    it. The parts' names come off the pieces (`a`), which keep nothing else of them."""
    boxes = {}

    def grow(name, x0, y0, x1, y1):
        b = boxes.get(name)
        boxes[name] = [x0, y0, x1, y1] if b is None else [min(b[0], x0), min(b[1], y0),
                                                           max(b[2], x1), max(b[3], y1)]

    for g in glyphs:
        for name in g.pop("a", []):
            grow(name, g["x"], g["y"] - g["ht"], g["x"] + g["w"], g["y"] + g["dp"])
    for r in rules:
        for name in r.pop("a", []):
            grow(name, r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
    return {k: [round(v, 4) for v in b] for k, b in boxes.items()}


def typeset(spec):
    width = float(spec.get("width", 360.0))
    work = pathlib.Path(spec["work"])
    work.mkdir(parents=True, exist_ok=True)
    # A DRAWING's labels are set in the same run as the formulas, one item each, and put back
    # together into the drawing's own record after (figure.assemble)
    items, figures = [], {}
    for it in spec["items"]:
        if it.get("mode") != "figure":
            items.append(it)
            continue
        try:
            fig = figure.compile_figure(it.get("tex", ""), spec.get("data") or {})
        except figure.FigureError as e:
            figures[it["id"]] = {"error": "the drawing: %s" % e}
            continue
        figures[it["id"]] = fig
        for j, lab in enumerate(fig["labels"]):
            items.append({"id": "%s/%d" % (it["id"], j), "tex": lab["tex"], "mode": "text"})
    records = _set(items, width, work)
    by_id = {r["id"]: r for r in records}
    out = []
    for it in spec["items"]:
        if it.get("mode") != "figure":
            out.append(by_id[it["id"]])
            continue
        fig = figures[it["id"]]
        if "error" in fig:
            out.append({"id": it["id"], "ok": False, "error": fig["error"], "glyphs": [], "rules": []})
            continue
        try:
            out.append(figure.assemble(it["id"], fig,
                                       [by_id["%s/%d" % (it["id"], j)] for j in range(len(fig["labels"]))]))
        except figure.FigureError as e:
            out.append({"id": it["id"], "ok": False, "error": "the drawing: %s" % e, "glyphs": [], "rules": []})
    return _answer(out, spec)


def _set(items, width, work):
    """Every item set by TeX: one run for all, or one each when the run fails."""
    if not items:
        return []
    dvi, err = _run_latex(work, "batch", items, width)
    records = []
    if dvi is not None:
        pages = _pages(dvi)
        if len(pages) == len(items):
            records = [_record(it, pg) for it, pg in zip(items, pages)]
    if not records:
        # One at a time, so a bad item costs only itself.
        for i, it in enumerate(items):
            one, one_err = _run_latex(work, "item%d" % i, [it], width)
            pages = _pages(one) if one is not None else []
            if len(pages) == 1:
                records.append(_record(it, pages[0]))
            else:
                records.append({"id": it["id"], "ok": False, "error": one_err or err,
                                "glyphs": [], "rules": []})
    return records


def _answer(records, spec):
    answer = {"items": records}
    if spec.get("outlines"):
        fonts = {}
        for rec in records:
            for g in rec["glyphs"]:
                t1 = _t1(g["f"])
                slot = fonts.setdefault(g["f"], {})
                key = str(g["c"])
                if t1 and key not in slot:
                    slot[key] = {"n": g["n"], "contours": t1.contours(g["n"])}
        answer["fonts"] = fonts
    return answer


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    _BIN["dir"] = spec.get("bin", "")
    if shutil.which(_prog("latex")) is None or shutil.which(_prog("kpsewhich")) is None:
        print("TeX is not installed (latex and kpsewhich are needed)", file=sys.stderr)
        return 3
    answer = typeset(spec)
    out = pathlib.Path(spec["out"])
    tmp = out.with_suffix(out.suffix + ".part")
    tmp.write_text(json.dumps(answer), encoding="utf-8")
    os.replace(tmp, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
