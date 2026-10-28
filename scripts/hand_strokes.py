"""Trace a handwriting font into the strokes a pen writes it with: a stroke font in Hershey's format.

    python3 scripts/hand_strokes.py fonts/hands/Kalam-Regular.ttf fonts/hands/strokes/kalam.jhf
    python3 scripts/hand_strokes.py <font.ttf> <out.jhf> --sample <out.png>    # and a picture to check it by

A LETTER IS WRITTEN BY A PEN ([LetterHand], src/desk/letter_hand.gd): every glyph is drawn as lines, in the
order a hand makes them, and the journal's hands ([NotebookLayout.HANDS]: Kalam, Caveat, Patrick Hand) are
outline fonts - shapes to fill, not lines to draw. This renders each printable ASCII character large, thins it
to its centerline (Zhang-Suen), cuts the centerline where it branches, drops the stubs thinning leaves at a
stroke's end, and walks what is left into strokes as a hand would: from the top left, on through a branch
the way the line was going, lifting only at a sharp turn; a ring from its top, counterclockwise; a dot (an
i's, a period) last, as a small spiral. Written with a round nib as wide as the font's own stroke
(its ink's area over its centerline's length), the strokes are the font again.

THE FORMAT IS HERSHEY'S (.jhf, one glyph a line from code 32), so [Ink]'s reader takes them as it takes the
plotter fonts and the export ships them with those (export_presets.cfg's `fonts/*.jhf`). Coordinates are
whole units, as there; a unit is 1/units of the em (at Kalam's body size about half a pixel). What the
format cannot hold - the units, where the baseline is, how tall and deep the hand runs, the nib - is
printed as the row [constant LetterHand.HANDS] takes.

A development tool, run once a font: it needs numpy and Pillow, and what ships is the .jhf it writes.
"""

import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

EM = 400                          # px to an em, traced
CHARS = [chr(c) for c in range(32, 127)]
SPAN = 93                         # Hershey's coordinates run from -49 to 44 (" R" is the pen lifted)
TOP = -49
STUB = 0.9                        # a branch from a free end shorter than this many stroke widths is a stub
DOT = 1.6                         # a mark no wider than this many stroke widths is a dot
LIFT = 110.0                      # a hand lifts the pen at a turn sharper than this (degrees)
TANGENT = 1.2                     # a branch's way out of a junction, read this many stroke widths along it
SMOOTH = 7                        # px: the moving average a centerline is smoothed by
SIMPLIFY = 0.0035                 # em: Ramer-Douglas-Peucker's tolerance
MARK = 0.16                       # em: a stroke this small is a mark, made after the rest (an i's dot)
CROSS = 0.9                       # two junctions closer than this many stroke widths are one crossing
CRUMB = 0.5                       # a piece of line shorter than this many stroke widths is left out
FLIP = 0.05                       # em: how much higher and further left a line's end must be to start there


def render(font: ImageFont.FreeTypeFont, ch: str):
    asc, desc = font.getmetrics()
    pad = EM // 2
    w = int(math.ceil(font.getlength(ch))) + 2 * pad
    h = asc + desc + 2 * pad
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).text((pad, pad + asc), ch, font=font, fill=255, anchor="ls")
    return np.array(img) >= 128, pad, pad + asc


def thin(img: np.ndarray) -> np.ndarray:
    """Zhang-Suen: the shape worn down to a line one pixel wide, its connections kept."""
    a = np.pad(img.astype(np.uint8), 1)
    while True:
        changed = False
        for step in (0, 1):
            p2, p3, p4 = a[:-2, 1:-1], a[:-2, 2:], a[1:-1, 2:]
            p5, p6, p7 = a[2:, 2:], a[2:, 1:-1], a[2:, :-2]
            p8, p9, p1 = a[1:-1, :-2], a[:-2, :-2], a[1:-1, 1:-1]
            ring = [p2, p3, p4, p5, p6, p7, p8, p9, p2]
            b = sum(r.astype(np.int32) for r in ring[:8])
            t = sum(((ring[i] == 0) & (ring[i + 1] == 1)).astype(np.int32) for i in range(8))
            if step == 0:
                c = (p2 * p4 * p6 == 0) & (p4 * p6 * p8 == 0)
            else:
                c = (p2 * p4 * p8 == 0) & (p2 * p6 * p8 == 0)
            m = (p1 == 1) & (b >= 2) & (b <= 6) & (t == 1) & c
            if m.any():
                a[1:-1, 1:-1][m] = 0
                changed = True
        if not changed:
            return a[1:-1, 1:-1].astype(bool)


def neighbours(pix: set, p):
    """A pixel's neighbours on the centerline: a diagonal only where no side neighbour already joins the two."""
    x, y = p
    out = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (x + dx, y + dy) in pix]
    for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        q = (x + dx, y + dy)
        if q in pix and (x + dx, y) not in pix and (x, y + dy) not in pix:
            out.append(q)
    return out


class Graph:
    """The centerline as branches between nodes: a free end, or a junction (its touching pixels one node)."""

    def __init__(self, pix: set):
        self.pos = {}             # node -> (x, y)
        self.edges = {}           # edge -> [a, b, points]
        self.dots = []            # [(x, y)] of lone pixels
        nb = {p: neighbours(pix, p) for p in pix}
        node_of = {}
        nid = 0
        for p in pix:
            if p in node_of or len(nb[p]) == 2:
                continue
            if not nb[p]:
                self.dots.append(p)
                continue
            # a free end alone; a junction with every junction pixel touching it
            group, todo = [], [p]
            node_of[p] = nid
            while todo:
                q = todo.pop()
                group.append(q)
                if len(nb[q]) < 3:
                    continue
                for r in nb[q]:
                    if r not in node_of and len(nb[r]) >= 3:
                        node_of[r] = nid
                        todo.append(r)
            self.pos[nid] = (sum(g[0] for g in group) / len(group), sum(g[1] for g in group) / len(group))
            nid += 1
        seen = set()
        eid = 0
        for p, n in list(node_of.items()):
            for q in nb[p]:
                if node_of.get(q) == n or (p, q) in seen:
                    continue
                path, prev, cur = [p], p, q
                seen.add((p, q))
                while cur not in node_of:
                    path.append(cur)
                    nxt = [r for r in nb[cur] if r != prev and (cur, r) not in seen]
                    if not nxt:
                        break
                    seen.add((cur, nxt[0]))
                    seen.add((nxt[0], cur))
                    prev, cur = cur, nxt[0]
                seen.add((cur, prev))
                if cur in node_of:
                    path.append(cur)
                    self.edges[eid] = [n, node_of[cur], path]
                    eid += 1
        # rings with no node on them (an o)
        on_edge = {q for e in self.edges.values() for q in e[2]}
        for p in pix:
            if p in node_of or p in on_edge or len(nb[p]) != 2:
                continue
            ring, prev, cur = [p], None, p
            while True:
                nxt = [r for r in nb[cur] if r != prev and r not in ring[1:]]
                if not nxt or nxt[0] == p:
                    break
                prev, cur = cur, nxt[0]
                ring.append(cur)
            on_edge.update(ring)
            self.pos[nid] = ring[0]
            self.edges[eid] = [nid, nid, ring + [ring[0]]]
            nid += 1
            eid += 1

    def degree(self, n):
        return sum((e[0] == n) + (e[1] == n) for e in self.edges.values())

    def contract(self, near: float):
        """Two junctions this close are one: a crossing thins to two, and a crossbar walked from either side
        stopped at the first."""
        changed = True
        while changed:
            changed = False
            for k, (a, b, pts) in list(self.edges.items()):
                if a == b or length(pts) >= near or self.degree(a) < 3 or self.degree(b) < 3:
                    continue
                del self.edges[k]
                pa, pb = self.pos[a], self.pos[b]
                self.pos[a] = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)
                for e in self.edges.values():
                    e[0] = a if e[0] == b else e[0]
                    e[1] = a if e[1] == b else e[1]
                del self.pos[b]
                changed = True
                break

    def prune(self, stub_px: float):
        """Drops the stubs thinning leaves at a corner or a stroke's end, then joins what passed through."""
        for _ in range(4):
            gone = [k for k, (a, b, pts) in self.edges.items() if a != b and length(pts) < stub_px
                    and ((self.degree(a) == 1 and self.degree(b) >= 3) or (self.degree(b) == 1 and self.degree(a) >= 3))]
            if not gone:
                break
            for k in gone:
                del self.edges[k]
            self._join_through()

    def _join_through(self):
        changed = True
        while changed:
            changed = False
            for n in list(self.pos):
                inc = [k for k, e in self.edges.items() if n in (e[0], e[1]) and e[0] != e[1]]
                if len(inc) != 2 or self.degree(n) != 2:
                    continue
                e1, e2 = self.edges[inc[0]], self.edges[inc[1]]
                p1 = e1[2] if e1[1] == n else e1[2][::-1]
                o1 = e1[0] if e1[1] == n else e1[1]
                p2 = e2[2] if e2[0] == n else e2[2][::-1]
                o2 = e2[1] if e2[0] == n else e2[0]
                del self.edges[inc[1]]
                self.edges[inc[0]] = [o1, o2, p1 + p2[1:]]
                changed = True
                break


def length(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def smooth(pts, ends: tuple):
    """A moving average along the line, its ends where the nodes are."""
    if len(pts) < 3:
        return [ends[0], ends[1]] if ends[0] != ends[1] or len(pts) < 2 else list(pts)
    a = np.array(pts, dtype=float)
    ring = pts[0] == pts[-1]
    k = SMOOTH // 2
    out = a.copy()
    n = len(a)
    for i in range(n):
        if ring:
            idx = [(i + j) % (n - 1) for j in range(-k, k + 1)]
        else:
            lo, hi = max(0, i - k), min(n - 1, i + k)
            r = min(i - lo, hi - i)
            idx = range(i - r, i + r + 1)
        out[i] = a[list(idx)].mean(axis=0)
    out = [tuple(p) for p in out]
    if not ring:
        out[0], out[-1] = ends
    else:
        out[-1] = out[0]
    return out


def simplify(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = np.array(pts[0]), np.array(pts[-1])
    ab = b - a
    nab = np.hypot(*ab)
    best, at = -1.0, 0
    for i in range(1, len(pts) - 1):
        p = np.array(pts[i])
        d = abs(ab[0] * (p - a)[1] - ab[1] * (p - a)[0]) / nab if nab > 1e-9 else np.hypot(*(p - a))
        if d > best:
            best, at = d, i
    if best <= eps:
        return [pts[0], pts[-1]]
    return simplify(pts[:at + 1], eps)[:-1] + simplify(pts[at:], eps)


def angle(u, v):
    nu, nv = math.hypot(*u), math.hypot(*v)
    if nu < 1e-9 or nv < 1e-9:
        return 180.0
    c = max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / (nu * nv)))
    return math.degrees(math.acos(c))


def along(pts, d):
    """The point [d] along a line from its start."""
    run = 0.0
    for i in range(len(pts) - 1):
        s = math.dist(pts[i], pts[i + 1])
        if run + s >= d and s > 0:
            t = (d - run) / s
            return (pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t)
        run += s
    return pts[-1]


def score(p):
    return p[1] + 0.35 * p[0]


def ccw(pts):
    """A ring as a hand writes one: from its top, counterclockwise as it is seen (y down)."""
    ring = pts[:-1]
    top = min(range(len(ring)), key=lambda i: (ring[i][1], ring[i][0]))
    ring = ring[top:] + ring[:top]
    area = sum(ring[i][0] * ring[(i + 1) % len(ring)][1] - ring[(i + 1) % len(ring)][0] * ring[i][1]
               for i in range(len(ring)))
    if area > 0:
        ring = [ring[0]] + ring[1:][::-1]
    return ring + [ring[0]]


def strokes_of(g: Graph, w: float):
    """The branches walked into a hand's strokes, in a hand's order."""
    lines = {k: smooth(e[2], (g.pos[e[0]], g.pos[e[1]])) for k, e in g.edges.items()}
    unused = set(lines)
    out = []

    def ends(k):
        a, b, _ = g.edges[k]
        return [(k, False, a), (k, True, b)]

    def free(n):
        return sum(1 for k in unused for (_, _, m) in ends(k) if m == n) == 1 and g.degree(n) == 1

    while unused:
        cands = [(k, rev, n) for k in unused for (k, rev, n) in ends(k)]
        frees = [c for c in cands if free(c[2])]
        pool = frees or cands
        k, rev, n = min(pool, key=lambda c: score(lines[c[0]][-1] if c[1] else lines[c[0]][0]))
        pts = lines[k][::-1] if rev else lines[k]
        if g.edges[k][0] == g.edges[k][1] and not frees:
            pts = ccw(pts)
        stroke = list(pts)
        unused.discard(k)
        at = g.edges[k][0] if rev else g.edges[k][1]
        while True:
            come = (stroke[-1][0] - along(stroke[::-1], TANGENT * w)[0],
                    stroke[-1][1] - along(stroke[::-1], TANGENT * w)[1])
            best = None
            for k2 in unused:
                a2, b2, _ = g.edges[k2]
                for rev2, m in ((False, a2), (True, b2)):
                    if m != at:
                        continue
                    p2 = lines[k2][::-1] if rev2 else lines[k2]
                    go = along(p2, TANGENT * w)
                    turn = angle(come, (go[0] - p2[0][0], go[1] - p2[0][1]))
                    if best is None or turn < best[0]:
                        best = (turn, k2, rev2, p2)
            if best is None or best[0] > LIFT:
                break
            _, k2, rev2, p2 = best
            stroke.extend(p2[1:])
            unused.discard(k2)
            at = g.edges[k2][0] if rev2 else g.edges[k2][1]
        # A LINE BEGUN AT ITS TAIL IS WRITTEN THE OTHER WAY: an a, an e or a g has one free end, its tail,
        # and walked from there it was written backward
        if stroke[0] != stroke[-1] and score(stroke[-1]) < score(stroke[0]) - FLIP * EM:
            stroke.reverse()
        out.append(stroke)
    return out


def spiral(c, radius, w):
    """A dot filled in with the nib: a small spiral out from its middle to its edge."""
    r_out = max(radius - w * 0.5, 0.0)
    if r_out < w * 0.15:
        return [(c[0] - w * 0.1, c[1]), (c[0] + w * 0.1, c[1])]
    turns = max(1.0, r_out / (w * 0.45))
    n = int(10 * turns) + 6
    pts = []
    for i in range(n + 1):
        t = i / n
        a = math.pi * 0.5 + t * turns * 2 * math.pi
        r = r_out * min(1.0, 0.25 + t)
        pts.append((c[0] + math.cos(a) * r * -1.0, c[1] - math.sin(a) * r))
    return pts


def components(img):
    """The shape's separate pieces (8-connected): [(pixels mask, area, (cx, cy), extent)]."""
    lab = np.zeros(img.shape, dtype=np.int32)
    out = []
    n = 0
    ys, xs = np.nonzero(img)
    for y, x in zip(ys, xs):
        if lab[y, x]:
            continue
        n += 1
        todo = [(y, x)]
        lab[y, x] = n
        got = []
        while todo:
            cy, cx = todo.pop()
            got.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = cy + dy, cx + dx
                    if 0 <= yy < img.shape[0] and 0 <= xx < img.shape[1] and img[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        todo.append((yy, xx))
        g = np.array(got)
        ext = max(g[:, 0].max() - g[:, 0].min(), g[:, 1].max() - g[:, 1].min()) + 1
        out.append((n, len(got), (g[:, 1].mean(), g[:, 0].mean()), ext))
    return lab, out


def glyph(font, ch, w_px):
    """One character, traced: (advance px, [strokes in px from its origin, y down])."""
    img, x0, base = render(font, ch)
    adv = font.getlength(ch)
    if not img.any():
        return adv, []
    lab, parts = components(img)
    sk = thin(img)
    lines, dots = [], []
    for n, area, c, ext in parts:
        if ext <= DOT * w_px:
            dots.append(spiral(c, math.sqrt(area / math.pi), w_px))
            continue
        mask = sk & (lab == n)
        pix = {(int(x), int(y)) for y, x in zip(*np.nonzero(mask))}
        g = Graph(pix)
        g.contract(CROSS * w_px)
        g.prune(STUB * w_px)
        g.contract(CROSS * w_px)
        kept = [s for s in strokes_of(g, w_px) if len(s) >= 2 and length(s) >= CRUMB * w_px]
        if kept:
            lines.extend(kept)
        else:
            # a mark whose line is too short to keep is a dot all the same (Caveat's period)
            dots.append(spiral(c, math.sqrt(area / math.pi), w_px))
    strokes = lines
    small = [s for s in strokes if extent(s) < MARK * EM]
    big = [s for s in strokes if extent(s) >= MARK * EM]
    big.sort(key=lambda s: score(s[0]))
    if not big:
        small.sort(key=lambda s: score(s[0]))
    marks = small + dots
    marks.sort(key=lambda s: score(s[0]))
    ordered = big + marks
    return adv, [[(p[0] - x0, p[1] - base) for p in simplify(s, SIMPLIFY * EM)] for s in ordered]


def extent(s):
    xs = [p[0] for p in s]
    ys = [p[1] for p in s]
    return max(max(xs) - min(xs), max(ys) - min(ys))


def measure(font):
    """The font's stroke width (its ink over its centerline) and how far its glyphs reach (em)."""
    area, cl = 0, 0.0
    up, down, wide = 0.0, 0.0, 0.0
    for ch in CHARS:
        img, x0, base = render(font, ch)
        if not img.any():
            continue
        if ch.isalnum():
            sk = thin(img)
            area += int(img.sum())
            cl += float(sk.sum())
        ys = np.nonzero(img.any(axis=1))[0]
        xs = np.nonzero(img.any(axis=0))[0]
        up = max(up, (base - ys[0]) / EM)
        down = max(down, (ys[-1] - base) / EM)
        adv = font.getlength(ch)
        wide = max(wide, 2 * max(adv / 2 - (xs[0] - x0), (xs[-1] - x0) - adv / 2) / EM, adv / EM)
    return area / cl, up, down, wide


def main():
    args = sys.argv[1:]
    sample = None
    if "--sample" in args:
        i = args.index("--sample")
        sample = args[i + 1]
        args = args[:i] + args[i + 2:]
    src, dst = args
    font = ImageFont.truetype(src, EM)
    w_px, up, down, wide = measure(font)
    units = int(min(SPAN / (up + down + 0.02), SPAN / (wide + 0.02)))
    base = TOP + int(math.ceil(up * units))
    lines = []
    traced = {}
    for code, ch in enumerate(CHARS, start=32):
        adv, strokes = glyph(font, ch, w_px)
        traced[ch] = (adv, strokes)
        left = -int(round(adv / EM * units / 2))
        right = left + int(round(adv / EM * units))
        body = ""
        for s in strokes:
            pts = []
            for x, y in s:
                q = (max(-49, min(44, int(round(x / EM * units)) + left)), max(-49, min(44, int(round(y / EM * units)) + base)))
                if not pts or pts[-1] != q:
                    pts.append(q)
            if len(pts) == 1:
                pts.append(pts[0])
            if body:
                body += " R"
            body += "".join(chr(82 + x) + chr(82 + y) for x, y in pts)
        n = 1 + len(body) // 2
        lines.append("%5d%3d%s%s%s" % (code, n, chr(82 + left), chr(82 + right), body))
    with open(dst, "w") as f:
        f.write("\n".join(lines) + "\n")
    print('"units": %d, "base": %d, "ascent": %.3f, "descent": %.3f, "nib": %.4f' % (units, base, up, down, w_px / EM))
    if sample:
        draw_sample(font, traced, w_px, sample)


def draw_sample(font, traced, w_px, path):
    """The font's own text above the strokes traced from it, at the size traced, to compare by eye."""
    text = ["Dear Pen, Isn't it suspicious how", "the world is not your friend? ijt.,!",
            "ABCDEFGHIJKLM nopqrstuvwxyz 0123456789"]
    k = 0.25
    line_h = int(EM * 1.25 * k)
    img = Image.new("L", (int(EM * 22 * k), line_h * len(text) * 2 + 20), 255)
    d = ImageDraw.Draw(img)
    small = ImageFont.truetype(font.path, int(EM * k))
    y = int(EM * k)
    for t in text:
        d.text((10, y), t, font=small, fill=0, anchor="ls")
        x = 10.0
        for ch in t:
            adv, strokes = traced[ch]
            for s in strokes:
                pts = [(x + p[0] * k, y + line_h + p[1] * k) for p in s]
                d.line(pts, fill=0, width=max(1, int(round(w_px * k))), joint="curve")
                r = w_px * k / 2
                for p in (pts[0], pts[-1]):
                    d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=0)
            x += adv * k
        y += line_h * 2
    img.save(path)


if __name__ == "__main__":
    main()
