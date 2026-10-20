"""A drawing on the pad: the teacher's SVG turned into what a pen draws.

    compile_figure(svg_text, data=None) -> {"paths": [...], "labels": [...]}     (raises FigureError)
    assemble(fig, label_records) -> one typeset record, as typeset.py answers for a formula

THE TEACHER DRAWS IN SVG, a language it writes fluently, and the desk's pen draws it by hand: every
line, curve, circle and polygon becomes a stroke (curves and arcs flattened along their length), in
the order the SVG lists them; every `<text>` becomes a label TeX sets (math in `$...$`), which the
hand writes as it writes a formula. svgelements (MIT) reads the SVG - paths, arcs, transforms and
styles - so nothing here re-implements the standard.

UNITS. The pad's column is COLUMN units wide: a figure whose viewBox is COLUMN wide spans it, one half
as wide takes half the column. Nothing is taller than MAX_H points - a tall figure is shrunk to fit.

A HAND DOES NOT FILL. A shape filled small (a dot, a bead) is drawn as a dot; a bigger one is hatched
- the way a person shades a region on paper. Only a fill the SVG asks for: SVG's own default fill is
black, and an outline drawn without `fill="none"` is still an outline here.

WHAT THE SVG MAY ADD, beyond the standard (each one a thing a math teacher draws, which plain SVG says
badly or not at all):

    arrow="end" | "start" | "both"   on a line, polyline or path: an arrowhead drawn by hand
                                     (marker-end and marker-start are read the same way)
    <dot x="" y=""/>                 a dot, the size a pen makes one
    <angle x="" y="" r="" from="" to=""/>
                                     an angle marked at (x, y): an arc of radius r from one direction
                                     to another, in degrees counterclockwise from pointing right as
                                     the page is seen (0 right, 90 up); right="true" draws a right
                                     angle's square corner instead
    <axes x="x0 x1" y="y0 y1" box="left top width height" ticks="dx dy" xlabel="" ylabel="" grid="">
                                     a pair of axes on a box of the figure, its children in the
                                     AXES' OWN COORDINATES (y up): <plot fn="x^2" from="" to=""/>, a
                                     curve given as x and y of t (<plot x="" y="" t="t0 t1"/>) or as
                                     a radius at angle t (<plot r="" t="t0 t1"/>), <dot x y/>,
                                     <label x y>text</label>, <line .../>, <polyline .../>,
                                     <polygon .../>, <rect x y width height/> (x, y its lower left: a
                                     bar), <circle cx cy r/>, <ellipse cx cy rx ry/> and <angle/> (its
                                     r in the figure's units); grid="true" adds faint lines at the
                                     ticks. A range or a tick may be written with pi (x="0 2*pi",
                                     ticks="pi/2 1"): ticks given with pi are numbered in pi.
                                     A SERIES A RUN KEPT (`data`, {name: {"points": [[x, y], ...]}},
                                     hosts/compute/run.py's keep()) is drawn by its name:
                                     <plot data=""/> joins its points (thinned to PLOT_MOST),
                                     <dots data=""/> a dot at each (DOTS_MOST at most) and
                                     <bars data="" width=""/> a bar standing on the x axis at each x,
                                     as tall as its y (BARS_MOST at most).

A PART THE PEN CAN POINT AT: an `id` on any element (or on a group, for all of it - inside <axes>
too) names it, and the record's `anchors` is {id: [x0, y0, x1, y1]}, the box of everything drawn
under that name - the desk points the pen there when the lesson says so (DeskScript's `point`).

THE WORK SHOWN IS THE WORK DONE (next/proof.md): a plot is computed here, from its expression, never
drawn from points an agent guessed. The expression is arithmetic only (+ - * / ^, parentheses, x, pi,
e and the usual functions), read by a parser that allows nothing else. Computed numbers come in only as
a series a run kept, by name - a name no run kept is refused.

What comes back is in POINTS, y down, from the figure's top left; [assemble] moves it to a record's
convention (y down from a baseline at the figure's foot) once TeX has set the labels.
"""

import ast
import io
import math
import xml.etree.ElementTree as ET

import svgelements as se

ET.register_namespace("", "http://www.w3.org/2000/svg")

## The pad's column, in the figure's units (a viewBox this wide spans it) and in points.
COLUMN = 360.0
COLUMN_PT = 270.0
## The tallest a figure is drawn, in points (the page holds about 360 below its first rule).
MAX_H = 200.0
## Curves are flattened to points about this far apart (points).
STEP = 2.0
## A filled shape no bigger than this (points, each way) is a dot; bigger is hatched this far apart.
DOT_MAX = 9.0
DOT_R = 2.2
HATCH = 4.5
## An arrowhead's wings: their length (points) and their angle off the line.
HEAD = 6.5
HEAD_ANGLE = math.radians(26.0)
## A label at a point of the axes sits this far right and up from it (points).
NUDGE = (3.0, -3.0)
## How many samples a plot takes across its range.
SAMPLES = 240
## A kept series: the most points a line is drawn through (more are thinned evenly, the last kept), the
## most dots and the most bars a pen draws.
PLOT_MOST = 800
DOTS_MOST = 400
BARS_MOST = 60
SVG_NS = "http://www.w3.org/2000/svg"


class FigureError(Exception):
    pass


# --- the expression a plot draws ----------------------------------------------------------------

FUNCS = {
    "sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan, "exp": math.exp,
    "log": math.log, "ln": math.log, "log10": math.log10, "log2": math.log2, "abs": abs,
    "floor": math.floor, "ceil": math.ceil, "asin": math.asin, "acos": math.acos,
    "atan": math.atan, "sinh": math.sinh, "cosh": math.cosh, "tanh": math.tanh,
    "min": min, "max": max,
}
CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}
_OPS = {ast.Add: lambda a, b: a + b, ast.Sub: lambda a, b: a - b, ast.Mult: lambda a, b: a * b,
        ast.Div: lambda a, b: a / b, ast.Pow: lambda a, b: a ** b, ast.Mod: lambda a, b: a % b}


def expression(src, var="x"):
    """`src` as a function of `var` (None: a constant, a function of nothing): arithmetic, the
    variable, the constants and FUNCS, nothing else."""
    text = src.replace("^", "**").replace("−", "-").replace("·", "*").replace("×", "*").replace("π", "pi")
    try:
        tree = ast.parse(text, mode="eval")
    except SyntaxError:
        raise FigureError("%r is not arithmetic%s (write 2*%s, not 2%s)" % (
            src, " in " + var if var else "", var or "pi", var or "pi"))

    def check(node):
        if isinstance(node, ast.Expression):
            return check(node.body)
        if isinstance(node, ast.BinOp) and type(node.op) in _OPS:
            return check(node.left) and check(node.right)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            return check(node.operand)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return True
        if isinstance(node, ast.Name):
            if node.id == var or node.id in CONSTS:
                return True
            raise FigureError("%r names %r - only %spi and e" % (src, node.id, var + ", " if var else ""))
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
            if node.func.id not in FUNCS:
                raise FigureError("%r calls %r, which a plot does not know" % (src, node.func.id))
            return all(check(a) for a in node.args)
        raise FigureError("%r is not arithmetic%s" % (src, " in " + var if var else ""))

    check(tree)

    def ev(node, x):
        if isinstance(node, ast.Expression):
            return ev(node.body, x)
        if isinstance(node, ast.BinOp):
            return _OPS[type(node.op)](ev(node.left, x), ev(node.right, x))
        if isinstance(node, ast.UnaryOp):
            v = ev(node.operand, x)
            return -v if isinstance(node.op, ast.USub) else v
        if isinstance(node, ast.Constant):
            return float(node.value)
        if isinstance(node, ast.Name):
            return x if node.id == var else CONSTS[node.id]
        return FUNCS[node.func.id](*[ev(a, x) for a in node.args])

    def f(x):
        try:
            v = ev(tree, x)
            if isinstance(v, complex):
                return float("nan")
            return float(v)
        except (ValueError, ZeroDivisionError, OverflowError, TypeError):
            return float("nan")
    return f


# --- the figure's own elements, made into plain SVG -------------------------------------------

def _tag(el):
    return el.tag.split("}", 1)[-1]


def _num(el, key, default=None):
    v = el.get(key)
    if v is None:
        if default is None:
            raise FigureError("<%s> needs %s" % (_tag(el), key))
        return default
    try:
        return float(v)
    except ValueError:
        raise FigureError("<%s> %s=%r is not a number" % (_tag(el), key, v))


def _pair(el, key, default=None):
    """`key`'s numbers: each a number or a constant written with pi (2*pi, pi/2), without spaces."""
    v = el.get(key)
    if v is None:
        if default is None:
            raise FigureError("<%s> needs %s (two numbers)" % (_tag(el), key))
        return default
    bits = []
    for b in v.replace(",", " ").split():
        try:
            bits.append(float(b))
        except ValueError:
            try:
                f = expression(b, None)
            except FigureError:
                raise FigureError("<%s> %s=%r is not numbers (write each without spaces: 2*pi)" % (_tag(el), key, v))
            val = f(0.0)
            if not math.isfinite(val):
                raise FigureError("<%s> %s=%r is not numbers" % (_tag(el), key, v))
            bits.append(val)
    return bits


def _pi_fmt(v):
    """`v` as a multiple of pi, the way a hand numbers a trig axis: pi/2, -pi, 3pi/2 - or plainly."""
    n = v / math.pi
    for d in (1, 2, 3, 4, 6):
        a = n * d
        if abs(a - round(a)) < 1e-6:
            a = int(round(a))
            if a == 0:
                return "0"
            num = ("-" if a < 0 else "") + ("" if abs(a) == 1 else str(abs(a)))
            return num + "\\pi" + ("/%d" % d if d > 1 else "")
    return _fmt(v)


def _angle(el, cx, cy):
    """<angle> as a polyline (figure units, y down) about (cx, cy): its arc, or a right angle's corner."""
    r = _num(el, "r", 14.0)
    a0 = math.radians(_num(el, "from"))
    a1 = math.radians(_num(el, "to"))
    if r <= 0:
        raise FigureError("<angle> r is its radius, more than 0")

    def at(a, k):
        return (cx + k * math.cos(a), cy - k * math.sin(a))
    if (el.get("right") or "").strip().lower() in ("true", "1", "yes"):
        u, v = at(a0, r), at(a1, r)
        pts = [u, (u[0] + v[0] - cx, u[1] + v[1] - cy), v]
    else:
        while a1 < a0:
            a1 += math.tau
        n = max(4, int(math.ceil(abs(a1 - a0) * r / 3.0)))
        pts = [at(a0 + (a1 - a0) * i / n, r) for i in range(n + 1)]
    e = _el("polyline", points=" ".join("%.3f,%.3f" % p for p in pts))
    for k in ("stroke-dasharray", "id"):
        if el.get(k):
            e.set(k, el.get(k))
    return e


def _nice(span):
    """A tick step for a range: 1, 2 or 5 times a power of ten, four to eight ticks across it."""
    if span <= 0:
        return 1.0
    raw = span / 6.0
    p = 10.0 ** math.floor(math.log10(raw))
    for m in (1.0, 2.0, 5.0, 10.0):
        if raw <= m * p:
            return m * p
    return 10.0 * p


def _fmt(v):
    if abs(v - round(v)) < 1e-9:
        return "%d" % round(v)
    return ("%.2f" % v).rstrip("0").rstrip(".")


def _el(tag, **attrs):
    e = ET.Element("{%s}%s" % (SVG_NS, tag))
    for k, v in attrs.items():
        e.set(k.replace("_", "-"), str(v))
    return e


def _series(data, name):
    """The kept series [name] as (x, y) points, or FigureError naming what was kept."""
    s = (data or {}).get(name)
    pts = s.get("points") if isinstance(s, dict) else None
    if not isinstance(pts, list) or not pts:
        kept = ", ".join(sorted(data)) if data else "none"
        raise FigureError('no run kept a series called "%s" (kept: %s)' % (name, kept))
    out = []
    for q in pts:
        try:
            x, y = float(q[0]), float(q[1])
        except (TypeError, ValueError, IndexError):
            raise FigureError('the series "%s" holds something that is not a point' % name)
        if math.isfinite(x) and math.isfinite(y):
            out.append((x, y))
    return out


def _joined(pts, x0, x1, y0, y1):
    """A series joined point to point, as runs inside the box: cut where it leaves the box."""
    runs, run = [], []
    for p, q in zip(pts, pts[1:]):
        cut = _clip(p, q, x0, x1, y0, y1)
        if cut is None:
            if len(run) > 1:
                runs.append(run)
            run = []
            continue
        c0, c1, whole_end = cut
        if not (run and math.isclose(c0[0], p[0]) and math.isclose(c0[1], p[1])):
            if len(run) > 1:
                runs.append(run)
            run = [c0]
        if not (math.isclose(c1[0], run[-1][0]) and math.isclose(c1[1], run[-1][1])):
            run.append(c1)
        if not whole_end:
            runs.append(run)
            run = []
    if len(run) > 1:
        runs.append(run)
    return runs


def _axes(el, data=None):
    """<axes> made plain: a <g> of lines, ticks, numbers, curves, dots and labels in the figure's units."""
    x0, x1 = (_pair(el, "x") + [None, None])[:2]
    y0, y1 = (_pair(el, "y") + [None, None])[:2]
    if x1 is None or y1 is None or x1 <= x0 or y1 <= y0:
        raise FigureError("<axes> x and y are each a range, low then high: x=\"-2 2\"")
    box = _pair(el, "box", [20.0, 10.0, COLUMN - 40.0, 160.0])
    if len(box) != 4 or box[2] <= 0 or box[3] <= 0:
        raise FigureError("<axes> box is left, top, width and height")
    bx, by, bw, bh = box
    ticks = _pair(el, "ticks", [_nice(x1 - x0), _nice(y1 - y0)])
    tx, ty = (ticks + ticks)[:2]
    # ticks written with pi are numbered in pi
    said = (el.get("ticks") or "").replace(",", " ").split()
    xpi = len(said) > 0 and "pi" in said[0]
    ypi = "pi" in said[1] if len(said) > 1 else xpi

    def X(x):
        return bx + (x - x0) / (x1 - x0) * bw

    def Y(y):
        return by + bh - (y - y0) / (y1 - y0) * bh

    g = _el("g")
    ax_y = 0.0 if y0 <= 0.0 <= y1 else y0          # where the x axis crosses
    ax_x = 0.0 if x0 <= 0.0 <= x1 else x0          # where the y axis crosses
    tick = 0.025 * min(bw, bh) + 2.0
    # THE GRID, drawn first, under everything: faint lines across the box at every tick (`grid` paths,
    # which the hand draws fine and light - dashed, a grid was hundreds of strokes)
    if (el.get("grid") or "").strip().lower() in ("true", "1", "yes", "both", "x", "y"):
        which = (el.get("grid") or "").strip().lower()
        if which != "y" and tx > 0:
            n = math.ceil(x0 / tx - 1e-9)
            while n * tx <= x1 + 1e-9:
                if abs(n * tx - ax_x) > 1e-9:
                    g.append(_el("line", x1=X(n * tx), y1=by + bh, x2=X(n * tx), y2=by, ghostkind="grid"))
                n += 1
        if which != "x" and ty > 0:
            n = math.ceil(y0 / ty - 1e-9)
            while n * ty <= y1 + 1e-9:
                if abs(n * ty - ax_y) > 1e-9:
                    g.append(_el("line", x1=bx, y1=Y(n * ty), x2=bx + bw, y2=Y(n * ty), ghostkind="grid"))
                n += 1
    g.append(_el("line", x1=bx, y1=Y(ax_y), x2=bx + bw, y2=Y(ax_y), arrow="end"))
    g.append(_el("line", x1=X(ax_x), y1=by + bh, x2=X(ax_x), y2=by, arrow="end"))
    if tx > 0:
        n = math.ceil(x0 / tx - 1e-9)
        while n * tx <= x1 + 1e-9 and n * tx < x1 - 0.04 * (x1 - x0):
            v = n * tx
            n += 1
            if abs(v - ax_x) < 1e-9 and ax_y == 0.0 and ax_x == 0.0:
                continue
            g.append(_el("line", x1=X(v), y1=Y(ax_y) - tick, x2=X(v), y2=Y(ax_y) + tick))
            lab = _el("text", x=X(v), y=Y(ax_y) + tick + 13.0, text_anchor="middle")
            lab.text = "$%s$" % (_pi_fmt(v) if xpi else _fmt(v))
            g.append(lab)
    if ty > 0:
        n = math.ceil(y0 / ty - 1e-9)
        while n * ty <= y1 + 1e-9 and n * ty < y1 - 0.04 * (y1 - y0):
            v = n * ty
            n += 1
            if abs(v - ax_y) < 1e-9 and ax_y == 0.0 and ax_x == 0.0:
                continue
            g.append(_el("line", x1=X(ax_x) - tick, y1=Y(v), x2=X(ax_x) + tick, y2=Y(v)))
            lab = _el("text", x=X(ax_x) - tick - 4.0, y=Y(v) + 4.0, text_anchor="end")
            lab.text = "$%s$" % (_pi_fmt(v) if ypi else _fmt(v))
            g.append(lab)
    if ax_x == 0.0 and ax_y == 0.0:
        lab = _el("text", x=X(0.0) - 4.0, y=Y(0.0) + tick + 13.0, text_anchor="end")
        lab.text = "$0$"
        g.append(lab)
    if el.get("xlabel"):
        lab = _el("text", x=bx + bw, y=Y(ax_y) - tick - 4.0, text_anchor="end")
        lab.text = el.get("xlabel")
        g.append(lab)
    if el.get("ylabel"):
        lab = _el("text", x=X(ax_x) + tick + 4.0, y=by + 10.0)
        lab.text = el.get("ylabel")
        g.append(lab)
    for child in list(el):
        tag = _tag(child)
        at = len(g)
        if tag == "plot" and child.get("data") is not None:
            pts = _series(data, child.get("data"))
            if len(pts) > PLOT_MOST:
                step = math.ceil(len(pts) / PLOT_MOST)
                pts = pts[::step] + ([pts[-1]] if (len(pts) - 1) % step else [])
            if len(pts) < 2:
                raise FigureError('<plot data="%s"> has one point: draw it with <dots>' % child.get("data"))
            for run in _joined(pts, x0, x1, y0, y1):
                pl = _el("polyline", points=" ".join("%.3f,%.3f" % (X(x), Y(y)) for x, y in run))
                for k in ("stroke-dasharray", "arrow"):
                    if child.get(k):
                        pl.set(k, child.get(k))
                g.append(pl)
        elif tag == "dots":
            pts = _series(data, child.get("data"))
            if len(pts) > DOTS_MOST:
                raise FigureError('<dots data="%s"> has %d points; a pen draws at most %d dots - keep fewer'
                                  % (child.get("data"), len(pts), DOTS_MOST))
            for x, y in pts:
                if x0 <= x <= x1 and y0 <= y <= y1:
                    g.append(_el("dot", x=X(x), y=Y(y)))
        elif tag == "bars":
            pts = _series(data, child.get("data"))
            if len(pts) > BARS_MOST:
                raise FigureError('<bars data="%s"> has %d bars; a pen draws at most %d - keep fewer'
                                  % (child.get("data"), len(pts), BARS_MOST))
            xs = sorted(set(x for x, _ in pts))
            gaps = [b - a for a, b in zip(xs, xs[1:]) if b > a]
            w = _num(child, "width", min(gaps) * 0.8 if gaps else (x1 - x0) / 20.0)
            for x, h in pts:
                a, b = max(x - w / 2.0, x0), min(x + w / 2.0, x1)
                lo, hi = max(min(ax_y, h), y0), min(max(ax_y, h), y1)
                if b <= a or hi <= lo:
                    continue
                e = _el("rect", x=X(a), y=Y(hi), width=X(b) - X(a), height=Y(lo) - Y(hi))
                if child.get("fill"):
                    e.set("fill", child.get("fill"))
                g.append(e)
        elif tag == "plot":
            fn = child.get("fn")
            if fn:
                f = expression(fn)
                a = _pair(child, "from", [x0])[0]
                b = _pair(child, "to", [x1])[0]
                runs = _curve(f, max(a, x0), min(b, x1), y0, y1)
            elif child.get("r") or (child.get("x") and child.get("y")):
                # A CURVE OF t: x and y given apart, or a radius at the angle t (polar)
                t0, t1 = (_pair(child, "t") + [None, None])[:2]
                if t1 is None or t1 <= t0:
                    raise FigureError("<plot> t is the range of t, low then high: t=\"0 2*pi\"")
                if child.get("r"):
                    fr = expression(child.get("r"), "t")
                    fx = lambda t: fr(t) * math.cos(t)
                    fy = lambda t: fr(t) * math.sin(t)
                else:
                    fx = expression(child.get("x"), "t")
                    fy = expression(child.get("y"), "t")
                runs = _traced(fx, fy, t0, t1, x0, x1, y0, y1)
            else:
                raise FigureError("<plot> needs fn (y as an expression in x), x and y (each in t), or r (in t)")
            for run in runs:
                pl = _el("polyline", points=" ".join("%.3f,%.3f" % (X(x), Y(y)) for x, y in run))
                for k in ("stroke-dasharray", "arrow"):
                    if child.get(k):
                        pl.set(k, child.get(k))
                g.append(pl)
        elif tag == "dot":
            g.append(_el("dot", x=X(_num(child, "x")), y=Y(_num(child, "y"))))
        elif tag in ("label", "text"):
            lab = _el("text", x=X(_num(child, "x")), y=Y(_num(child, "y")),
                      text_anchor=child.get("text-anchor", "start"), nudge="1")
            lab.text = "".join(child.itertext())
            g.append(lab)
        elif tag == "line":
            e = _el("line", x1=X(_num(child, "x1")), y1=Y(_num(child, "y1")),
                    x2=X(_num(child, "x2")), y2=Y(_num(child, "y2")))
            for k in ("stroke-dasharray", "arrow", "marker-end", "marker-start"):
                if child.get(k):
                    e.set(k, child.get(k))
            g.append(e)
        elif tag in ("polyline", "polygon"):
            pts = [float(p) for p in child.get("points", "").replace(",", " ").split()]
            e = _el(tag, points=" ".join("%.3f,%.3f" % (X(pts[i]), Y(pts[i + 1]))
                                         for i in range(0, len(pts) - 1, 2)))
            for k in ("stroke-dasharray", "arrow", "fill", "marker-end"):
                if child.get(k):
                    e.set(k, child.get(k))
            g.append(e)
        elif tag == "rect":
            x, y = _num(child, "x", 0.0), _num(child, "y", 0.0)
            w, h = _num(child, "width"), _num(child, "height")
            lo, hi = min(y, y + h), max(y, y + h)
            e = _el("rect", x=min(X(x), X(x + w)), y=Y(hi), width=abs(X(x + w) - X(x)), height=Y(lo) - Y(hi))
            for k in ("stroke-dasharray", "fill"):
                if child.get(k):
                    e.set(k, child.get(k))
            g.append(e)
        elif tag in ("circle", "ellipse"):
            cx, cy = _num(child, "cx", 0.0), _num(child, "cy", 0.0)
            rx = _num(child, "r") if tag == "circle" else _num(child, "rx")
            ry = rx if tag == "circle" else _num(child, "ry")
            e = _el("ellipse", cx=X(cx), cy=Y(cy), rx=abs(rx) * bw / (x1 - x0), ry=abs(ry) * bh / (y1 - y0))
            for k in ("stroke-dasharray", "fill"):
                if child.get(k):
                    e.set(k, child.get(k))
            g.append(e)
        elif tag == "angle":
            g.append(_angle(child, X(_num(child, "x")), Y(_num(child, "y"))))
        else:
            raise FigureError("<axes> holds plot, dot, dots, bars, label, line, polyline, polygon, rect, circle, ellipse and angle - not <%s>" % tag)
        if child.get("id"):
            for made in list(g)[at:]:
                made.set("id", child.get("id"))
    return g


def _curve(f, a, b, y0, y1):
    """y = f(x) for x from a to b, as runs of points inside the y range: broken where f is undefined
    or jumps (1/x across 0), and cut where it leaves the range, at the edge it crosses."""
    runs, run = [], []
    span = y1 - y0
    prev = None                 # the last sample, while the curve runs unbroken
    for i in range(SAMPLES + 1):
        x = a + (b - a) * i / SAMPLES
        y = f(x)
        if not math.isfinite(y) or (prev is not None and abs(y - prev[1]) > 1.5 * span):
            if len(run) > 1:
                runs.append(run)
            run = []
            prev = (x, y) if math.isfinite(y) else None
            if prev is not None and y0 <= y <= y1:
                run = [prev]
            continue
        inside = y0 <= y <= y1
        if prev is not None and inside != (y0 <= prev[1] <= y1):
            edge = y1 if max(y, prev[1]) > y1 else y0
            t = (edge - prev[1]) / (y - prev[1])
            cut = (prev[0] + (x - prev[0]) * t, edge)
            if inside:
                run = [cut]
            else:
                run.append(cut)
                if len(run) > 1:
                    runs.append(run)
                run = []
        if inside:
            run.append((x, y))
        prev = (x, y)
    if len(run) > 1:
        runs.append(run)
    return runs


def _traced(fx, fy, a, b, x0, x1, y0, y1):
    """The curve (fx(t), fy(t)) for t from a to b, as runs of points inside the box x0..x1, y0..y1:
    broken where it is undefined or leaps, and cut where it leaves the box, at the edge it crosses."""
    runs, run = [], []
    span = math.hypot(x1 - x0, y1 - y0)
    prev = None
    n = SAMPLES * 2
    for i in range(n + 1):
        t = a + (b - a) * i / n
        p = (fx(t), fy(t))
        if not (math.isfinite(p[0]) and math.isfinite(p[1])) or (prev is not None and math.dist(p, prev) > 0.5 * span):
            if len(run) > 1:
                runs.append(run)
            run = []
            prev = p if math.isfinite(p[0]) and math.isfinite(p[1]) else None
            if prev is not None and x0 <= p[0] <= x1 and y0 <= p[1] <= y1:
                run = [p]
            continue
        if prev is None:
            if x0 <= p[0] <= x1 and y0 <= p[1] <= y1:
                run = [p]
            prev = p
            continue
        cut = _clip(prev, p, x0, x1, y0, y1)
        if cut is None:
            if len(run) > 1:
                runs.append(run)
            run = []
        else:
            c0, c1, whole_end = cut
            if not run:
                run = [c0]
            run.append(c1)
            if not whole_end:
                if len(run) > 1:
                    runs.append(run)
                run = []
        prev = p
    if len(run) > 1:
        runs.append(run)
    return runs


def _clip(p, q, x0, x1, y0, y1):
    """The part of the segment p-q inside the box (Liang-Barsky): (start, end, whether it reaches q),
    or None."""
    t0, t1 = 0.0, 1.0
    dx, dy = q[0] - p[0], q[1] - p[1]
    for pp, qq in ((-dx, p[0] - x0), (dx, x1 - p[0]), (-dy, p[1] - y0), (dy, y1 - p[1])):
        if pp == 0:
            if qq < 0:
                return None
            continue
        r = qq / pp
        if pp < 0:
            t0 = max(t0, r)
        else:
            t1 = min(t1, r)
        if t0 > t1:
            return None
    return ((p[0] + dx * t0, p[1] + dy * t0), (p[0] + dx * t1, p[1] + dy * t1), t1 >= 1.0)


def _filled(el, inherited):
    """Does `el` ask to be filled? Its own fill, a style's, or one it inherits - never SVG's default."""
    fill = el.get("fill")
    style = el.get("style", "")
    for part in style.split(";"):
        if part.strip().startswith("fill:"):
            fill = part.split(":", 1)[1].strip()
    if fill is None:
        return inherited
    return fill.strip().lower() not in ("none", "transparent", "")


def _plain(root, data=None):
    """The figure's own elements made plain SVG, each drawn element marked with what it asks of the pen
    (`ghostfill`, `ghostdot`) and the part it belongs to (`ghostid`: its own id, else its group's).
    [data]: the series runs kept, which a plot, dots or bars inside <axes> draw by name."""
    def walk(el, filled, part):
        for child in list(el):
            tag = _tag(child)
            name = child.get("id") or part
            if tag == "axes":
                g = _axes(child, data)
                for k in ("transform",):
                    if child.get(k):
                        g.set(k, child.get(k))
                el.insert(list(el).index(child), g)
                el.remove(child)
                child = g
                tag = "g"
            if tag == "angle":
                a = _angle(child, _num(child, "x"), _num(child, "y"))
                el.insert(list(el).index(child), a)
                el.remove(child)
                child = a
                tag = "polyline"
            if tag == "dot":
                c = _el("circle", cx=_num(child, "x", _num(child, "cx", 0.0)),
                        cy=_num(child, "y", _num(child, "cy", 0.0)), r="0.5", ghostdot="1")
                if child.get("id"):
                    c.set("id", child.get("id"))
                el.insert(list(el).index(child), c)
                el.remove(child)
                child = c
                tag = "circle"
            f = _filled(child, filled)
            if name and tag not in ("g", "svg", "a", "switch"):
                child.set("ghostid", name)
            if tag in ("g", "svg", "a", "switch"):
                walk(child, f, name)
            elif tag in ("line", "polyline", "polygon", "rect", "circle", "ellipse", "path"):
                child.set("ghostfill", "1" if f and tag != "line" and tag != "polyline" else "0")
            elif tag in ("defs", "title", "desc", "style", "metadata", "marker", "clipPath", "mask",
                         "linearGradient", "radialGradient", "pattern", "symbol"):
                el.remove(child)
            elif tag == "text":
                pass
            elif tag in ("tspan",):
                pass
            elif tag == "use":
                raise FigureError("<use> is not drawn - write the shape out")
            elif tag == "image":
                raise FigureError("<image> cannot be drawn by a pen")
            elif tag in ("plot", "label"):
                raise FigureError("<%s> belongs inside <axes>" % tag)
            else:
                raise FigureError("<%s> is not something the pen draws" % tag)
    walk(root, _filled(root, False), None)


# --- drawing it ----------------------------------------------------------------------------------

def _flatten(path, scale):
    """A path's subpaths as point lists, in the figure's units, curves cut about STEP points apart."""
    out = []
    for sub in path.as_subpaths():
        pts = []
        sp = se.Path(sub)
        for seg in sp:
            if isinstance(seg, se.Move):
                if len(pts) > 1:
                    out.append(pts)
                pts = [(seg.end.x, seg.end.y)]
            elif isinstance(seg, (se.Line, se.Close)):
                if seg.end is not None:
                    pts.append((seg.end.x, seg.end.y))
            else:
                n = max(2, int(math.ceil(seg.length() * scale / STEP)))
                for i in range(1, n + 1):
                    p = seg.point(i / n)
                    pts.append((p.x, p.y))
        if len(pts) > 1:
            out.append(pts)
        elif len(pts) == 1:
            out.append(pts)
    return out


def _dashes(pts, pattern):
    """`pts` cut into the dashes of `pattern` (on, off, ...), in the same units."""
    if not pattern or sum(pattern) <= 0:
        return [pts]
    out, cur = [], [pts[0]]
    i, left, on = 0, pattern[0], True
    for a, b in zip(pts, pts[1:]):
        seg = math.dist(a, b)
        pos = 0.0
        while seg - pos > left:
            pos += left
            t = pos / seg
            q = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            if on:
                cur.append(q)
                out.append(cur)
            cur = [q]
            i = (i + 1) % len(pattern)
            left, on = pattern[i], not on
        left -= seg - pos
        if on:
            cur.append(b)
        else:
            cur = [b]
    if on and len(cur) > 1:
        out.append(cur)
    return out


def _head(tip, back):
    """An arrowhead at `tip`, pointing away from `back`: one stroke, wing - tip - wing (points)."""
    ang = math.atan2(tip[1] - back[1], tip[0] - back[0])
    w1 = (tip[0] - HEAD * math.cos(ang - HEAD_ANGLE), tip[1] - HEAD * math.sin(ang - HEAD_ANGLE))
    w2 = (tip[0] - HEAD * math.cos(ang + HEAD_ANGLE), tip[1] - HEAD * math.sin(ang + HEAD_ANGLE))
    return [w1, tip, w2]


def _behind(pts, at_end):
    """The point a little way back along `pts` from one end - the arrow's direction, not a kink's."""
    seq = pts[::-1] if at_end else pts
    tip = seq[0]
    for p in seq[1:]:
        if math.dist(p, tip) >= 1.5:
            return tip, p
    return tip, seq[-1]


def _hatch(polys):
    """Lines at 45 degrees, HATCH points apart, inside `polys` (even-odd), in points."""
    # rotate by -45 so the hatch is horizontal, scan, rotate back
    c, s = math.cos(math.pi / 4), math.sin(math.pi / 4)
    rot = [[(x * c + y * s, -x * s + y * c) for x, y in p] for p in polys]
    ys = [y for p in rot for _, y in p]
    if not ys:
        return []
    out = []
    y = math.floor(min(ys) / HATCH) * HATCH + HATCH * 0.5
    while y < max(ys):
        xs = []
        for p in rot:
            for a, b in zip(p, p[1:] + p[:1]):
                if (a[1] <= y < b[1]) or (b[1] <= y < a[1]):
                    xs.append(a[0] + (y - a[1]) / (b[1] - a[1]) * (b[0] - a[0]))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            if xs[i + 1] - xs[i] > 1.0:
                ends = [(xs[i] + 0.6, y), (xs[i + 1] - 0.6, y)]
                out.append([(x * c - yy * s, x * s + yy * c) for x, yy in ends])
        y += HATCH
    return out


def _spiral(cx, cy, r):
    """A dot as a pen fills one: a small tight spiral out from the middle (points)."""
    pts = []
    turns = 2.5
    n = 28
    for i in range(n + 1):
        u = i / n
        a = u * turns * math.tau
        pts.append((cx + math.cos(a) * r * u, cy + math.sin(a) * r * u))
    return pts


def _arrows(el):
    a = (el.values.get("arrow") or "").strip().lower()
    start = a in ("start", "both") or bool(el.values.get("marker-start"))
    end = a in ("end", "both") or bool(el.values.get("marker-end"))
    return start, end


def compile_figure(svg_text, data=None):
    """The SVG as the pen draws it: {"paths": [{k, pts, kind}], "labels": [{k, tex, x, y, anchor}],
    "w", "h"} in points, y down from the viewBox's top left. [data]: the series runs kept (see the
    module's note)."""
    text = svg_text.strip()
    if not text.startswith("<svg"):
        raise FigureError("a drawing is one <svg> element")
    try:
        root = ET.fromstring(text if "xmlns" in text.split(">", 1)[0]
                             else text.replace("<svg", '<svg xmlns="%s"' % SVG_NS, 1))
    except ET.ParseError as e:
        raise FigureError("the SVG does not parse: %s" % e)
    vb = root.get("viewBox")
    if vb:
        try:
            vx, vy, vw, vh = [float(v) for v in vb.replace(",", " ").split()]
        except ValueError:
            raise FigureError("viewBox=%r is not four numbers" % vb)
    else:
        try:
            vx, vy, vw, vh = 0.0, 0.0, float(root.get("width", COLUMN)), float(root.get("height", 200))
        except ValueError:
            raise FigureError("a drawing needs a viewBox")
    if vw <= 0 or vh <= 0:
        raise FigureError("the viewBox has no size")
    _plain(root, data)
    scale = COLUMN_PT / COLUMN
    scale = min(scale, COLUMN_PT / vw, MAX_H / vh)
    root.set("viewBox", "%g %g %g %g" % (vx, vy, vw, vh))
    for k in ("width", "height"):
        if k in root.attrib:
            del root.attrib[k]
    try:
        svg = se.SVG.parse(io.StringIO(ET.tostring(root, encoding="unicode")), reify=True,
                           width=vw, height=vh)
    except Exception as e:  # svgelements raises many kinds; the message is what the teacher needs
        raise FigureError("the SVG does not read: %s" % e)

    # svgelements has already moved the viewBox's origin to 0, 0
    def pt(p):
        return (p[0] * scale, p[1] * scale)

    paths, labels = [], []
    k = 0
    for el in svg.elements():
        if isinstance(el, se.Text):
            tex = (el.text or "").strip()
            if not tex:
                continue
            x, y = el.x, el.y
            m = el.transform
            if m is not None:
                x, y = m.a * el.x + m.c * el.y + m.e, m.b * el.x + m.d * el.y + m.f
            px, py = pt((x, y))
            if el.values.get("nudge"):
                px, py = px + NUDGE[0], py + NUDGE[1]
            anchor = (el.anchor or "start").lower()
            labels.append({"k": k, "tex": tex, "x": round(px, 3), "y": round(py, 3),
                           "anchor": anchor if anchor in ("start", "middle", "end") else "start",
                           "id": el.values.get("ghostid") or ""})
            k += 1
            continue
        if not isinstance(el, se.Shape):
            continue
        gid = el.values.get("ghostid") or ""
        path = se.Path(el)
        if len(path) == 0:
            continue
        subs = [[pt(p) for p in s] for s in _flatten(path, scale)]
        subs = [s for s in subs if s]
        if not subs:
            continue
        if el.values.get("ghostdot") == "1":
            xs = [p[0] for s in subs for p in s]
            ys = [p[1] for s in subs for p in s]
            paths.append({"k": k, "id": gid, "kind": "dot",
                          "pts": _spiral((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, DOT_R)})
            k += 1
            continue
        xs = [p[0] for s in subs for p in s]
        ys = [p[1] for s in subs for p in s]
        filled = el.values.get("ghostfill") == "1"
        if filled and max(xs) - min(xs) <= DOT_MAX and max(ys) - min(ys) <= DOT_MAX:
            r = max(max(xs) - min(xs), max(ys) - min(ys)) / 2
            paths.append({"k": k, "id": gid, "kind": "dot", "pts": _spiral((min(xs) + max(xs)) / 2,
                                                                (min(ys) + max(ys)) / 2, max(r, 1.2))})
            k += 1
            continue
        dash = el.values.get("stroke-dasharray")
        pattern = []
        if dash and dash != "none":
            try:
                pattern = [float(v) * scale for v in dash.replace(",", " ").split()]
            except ValueError:
                pattern = []
            if len(pattern) % 2:
                pattern = pattern * 2
        kind = "grid" if el.values.get("ghostkind") == "grid" else "line"
        for s in subs:
            for piece in (_dashes(s, pattern) if pattern else [s]):
                if len(piece) > 1:
                    paths.append({"k": k, "id": gid, "kind": kind, "pts": piece})
                    k += 1
        if filled:
            for h in _hatch([s for s in subs if len(s) > 2]):
                paths.append({"k": k, "id": gid, "kind": "hatch", "pts": h})
                k += 1
        start, end = _arrows(el)
        if end and len(subs[-1]) > 1:
            tip, back = _behind(subs[-1], True)
            paths.append({"k": k, "id": gid, "kind": "arrow", "pts": _head(tip, back)})
            k += 1
        if start and len(subs[0]) > 1:
            tip, back = _behind(subs[0], False)
            paths.append({"k": k, "id": gid, "kind": "arrow", "pts": _head(tip, back)})
            k += 1
    for p in paths:
        p["pts"] = [[round(x, 3), round(y, 3)] for x, y in p["pts"]]
    if not paths and not labels:
        raise FigureError("the drawing has nothing in it to draw")
    return {"paths": paths, "labels": labels, "w": round(vw * scale, 3), "h": round(vh * scale, 3)}


def assemble(fig_id, fig, label_records):
    """One record for the figure, as typeset.py answers for a formula: its labels' glyphs and rules
    placed where the SVG put them, its paths beside them, every piece in drawing order (`k`), and
    the whole moved so x starts at 0 and y is measured down from a baseline at the figure's foot -
    with `anchors`, the box of each named part in the same convention."""
    glyphs, rules, paths = [], [], []
    lo_x, lo_y, hi_x, hi_y = math.inf, math.inf, -math.inf, -math.inf

    def grow(x0, y0, x1, y1):
        nonlocal lo_x, lo_y, hi_x, hi_y
        lo_x, lo_y, hi_x, hi_y = min(lo_x, x0), min(lo_y, y0), max(hi_x, x1), max(hi_y, y1)

    parts = {}             # id -> [x0, y0, x1, y1], before the move

    def part(name, x0, y0, x1, y1):
        if not name:
            return
        b = parts.get(name)
        parts[name] = [x0, y0, x1, y1] if b is None else [min(b[0], x0), min(b[1], y0),
                                                          max(b[2], x1), max(b[3], y1)]

    for p in fig["paths"]:
        k = int(p["k"]) * 1000
        paths.append({"k": k, "kind": p["kind"], "pts": p["pts"]})
        for x, y in p["pts"]:
            grow(x, y, x, y)
            part(p.get("id", ""), x, y, x, y)
    for lab, rec in zip(fig["labels"], label_records):
        if not rec.get("ok"):
            raise FigureError("its label %r: %s" % (lab["tex"], rec.get("error", "TeX could not set it")))
        w = float(rec.get("w", 0.0))
        dx = lab["x"] - {"start": 0.0, "middle": w / 2.0, "end": w}[lab["anchor"]]
        dy = lab["y"]
        base = int(lab["k"]) * 1000
        for g in rec.get("glyphs", []):
            g = dict(g)
            g["x"] = g["x"] + dx
            g["y"] = g["y"] + dy
            g["k"] = base + int(g.get("k", 0)) + 1
            glyphs.append(g)
            grow(g["x"], g["y"] - g.get("ht", 0.0), g["x"] + g.get("w", 0.0), g["y"] + g.get("dp", 0.0))
            part(lab.get("id", ""), g["x"], g["y"] - g.get("ht", 0.0), g["x"] + g.get("w", 0.0),
                 g["y"] + g.get("dp", 0.0))
        for r in rec.get("rules", []):
            r = dict(r)
            r["x"] = r["x"] + dx
            r["y"] = r["y"] + dy
            r["k"] = base + int(r.get("k", 0)) + 1
            rules.append(r)
            grow(r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
            part(lab.get("id", ""), r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])
    if lo_x == math.inf:
        raise FigureError("the drawing has nothing in it to draw")
    for g in glyphs:
        g["x"], g["y"] = round(g["x"] - lo_x, 4), round(g["y"] - hi_y, 4)
    for r in rules:
        r["x"], r["y"] = round(r["x"] - lo_x, 4), round(r["y"] - hi_y, 4)
    for p in paths:
        p["pts"] = [[round(x - lo_x, 3), round(y - hi_y, 3)] for x, y in p["pts"]]
    anchors = {name: [round(b[0] - lo_x, 4), round(b[1] - hi_y, 4), round(b[2] - lo_x, 4),
                      round(b[3] - hi_y, 4)] for name, b in parts.items()}
    return {"id": fig_id, "ok": True, "error": "", "figure": True, "w": round(hi_x - lo_x, 4),
            "h": round(hi_y - lo_y, 4), "d": 0.0, "glyphs": glyphs, "rules": rules, "paths": paths,
            "anchors": anchors}
