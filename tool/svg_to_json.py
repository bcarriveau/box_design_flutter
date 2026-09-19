#!/usr/bin/env python3
"""Convert a JDeation-Designer-style SVG into a box_design_flutter template JSON.

Source format (see https://github.com/jchancel/jdeation-designer, README):
millimeter-precision SVGs where **black strokes are cut lines** (mounting
holes, slots, cutouts) and **red strokes are visual guides** (the board
outline, connector footprints...). Output is the same JSON shape as
assets/templates/*.json:

    {"id": ..., "name": ..., "category": ...,
     "entities": [ {"type": "polyline", "closed": true, "vertices": [...]},
                   {"type": "circle", "center": {...}, "radius": ...}, ... ]}

* `--kind component` (default): the outline is the smallest closed red shape
  that still contains every black cut shape (which also skips the big red
  "sheet" rectangle some files draw around everything); black closed shapes
  that are circles become `circle` entities, other black shapes become
  polylines (slots keep their arcs as bulge segments).
* `--kind model`: the black shapes themselves are the parts -- the largest
  closed black shape is the outline and black shapes inside it are holes.

Units: SVG user units are converted to mm at 96 px/inch. A `viewBox` that
carries unit suffixes (e.g. "0 0 246mm 246mm", emitted by some exporters) is
invalid SVG and ignored by browsers/Inkscape -- user units are then plain
px -- so it's dropped here too instead of being used as a scale.

Coordinates come out with the outline's bottom-left corner at (0, 0), Y up,
matching every other template.

Usage:
    pip install svgelements
    python tool/svg_to_json.py board.svg --id my_board --name "My Board" \\
        --category controller -o assets/templates/my_board.json
"""
from __future__ import annotations

import argparse
import io
import json
import math
import re
import sys
from pathlib import Path

from svgelements import (
    SVG, Arc, Circle, Close, CubicBezier, Ellipse, Line, Move, Polygon,
    Polyline, QuadraticBezier, Rect, Shape, SimpleLine,
)
from svgelements import Path as SvgPath

PX_TO_MM = 25.4 / 96.0
VALID_CATEGORIES = ("controller", "controllerAddon", "receiver", "powerSupply", "powerDistribution", "box")

Vertex = tuple  # (x_mm, y_mm, bulge) -- y already flipped to Y-up


def load_svg(path: Path) -> SVG:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    root = re.search(r"<svg\b[^>]*>", text, re.S)
    if root:
        tag = root.group(0)
        fixed = re.sub(r'\sviewBox="[^"]*[A-Za-z][^"]*"', "", tag)
        text = text.replace(tag, fixed, 1)
    return SVG.parse(io.BytesIO(text.encode("utf-8")), reify=True, ppi=96.0)


def stroke_class(shape) -> str:
    """'black' (cut line), 'red' (guide), or 'other'/'none'."""
    c = shape.stroke
    if c is None or c.value is None or getattr(c, "alpha", 255) == 0:
        return "none"
    r, g, b = c.red, c.green, c.blue
    if r < 70 and g < 70 and b < 70:
        return "black"
    if r > 150 and g < 110 and b < 110:
        return "red"
    return "other"


def _pt(p) -> tuple:
    """SVG px (Y down) -> mm (Y up)."""
    return (p.x * PX_TO_MM, -p.y * PX_TO_MM)


def _circle_through(p0, p1, p2):
    ax, ay = p0
    bx, by = p1
    cx, cy = p2
    d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if abs(d) < 1e-12:
        return None
    ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
    uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
    return ux, uy, math.hypot(ax - ux, ay - uy)


def _bulge_from_three(p0, pm, p1):
    """Bulge of the circular arc p0 -> p1 passing through pm (positive =
    counter-clockwise, DXF convention), or None if the points are collinear."""
    circ = _circle_through(p0, pm, p1)
    if circ is None:
        return None
    cx, cy, _r = circ
    turn = (pm[0] - p0[0]) * (p1[1] - pm[1]) - (pm[1] - p0[1]) * (p1[0] - pm[0])
    if abs(turn) < 1e-12:
        return None
    a0 = math.atan2(p0[1] - cy, p0[0] - cx)
    a1 = math.atan2(p1[1] - cy, p1[0] - cx)
    ccw = turn > 0
    sweep = (a1 - a0) % (2 * math.pi) if ccw else (a0 - a1) % (2 * math.pi)
    if sweep < 1e-9:
        sweep = 2 * math.pi
    bulge = math.tan(sweep / 4)
    return bulge if ccw else -bulge


def _flatten_arc_points(p0, p1, bulge, n=48):
    """Points along the bulge arc p0 -> p1 (both endpoints included)."""
    if abs(bulge) < 1e-12:
        return [p0, p1]
    theta = 4 * math.atan(bulge)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    chord = math.hypot(dx, dy)
    r = chord / (2 * math.sin(abs(theta) / 2))
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    d = r * math.cos(abs(theta) / 2) * (1 if bulge > 0 else -1)
    cx, cy = mx + (-dy / chord) * d, my + (dx / chord) * d
    a0 = math.atan2(p0[1] - cy, p0[0] - cx)
    steps = max(2, int(abs(theta) / (2 * math.pi) * n) + 1)
    return [(cx + r * math.cos(a0 + theta * i / steps), cy + r * math.sin(a0 + theta * i / steps)) for i in range(steps + 1)]


def path_to_loops(shape) -> list:
    """A shape -> list of (vertices, closed) with vertices as (x, y, bulge) in mm, Y up."""
    path = shape if isinstance(shape, SvgPath) else SvgPath(shape)
    loops = []
    verts: list = []
    closed = False

    def flush():
        nonlocal verts, closed
        if len(verts) >= 2:
            if closed or math.hypot(verts[0][0] - verts[-1][0], verts[0][1] - verts[-1][1]) < 1e-4:
                if math.hypot(verts[0][0] - verts[-1][0], verts[0][1] - verts[-1][1]) < 1e-4:
                    last_bulge = verts[-1][2]
                    verts = verts[:-1]
                    if verts and last_bulge:
                        verts[-1] = (verts[-1][0], verts[-1][1], last_bulge)
                loops.append((verts, True))
            else:
                loops.append((verts, False))
        verts = []
        closed = False

    def add(p, bulge=0.0):
        if verts and math.hypot(verts[-1][0] - p[0], verts[-1][1] - p[1]) < 1e-9:
            if bulge and not verts[-1][2]:
                verts[-1] = (verts[-1][0], verts[-1][1], bulge)
            return
        verts.append((p[0], p[1], bulge))

    for seg in path:
        if isinstance(seg, Move):
            flush()
            if seg.end is not None:
                add(_pt(seg.end))
        elif isinstance(seg, Close):
            closed = True
        elif isinstance(seg, Line):
            if not verts:
                add(_pt(seg.start))
            add(_pt(seg.end))
        elif isinstance(seg, (Arc, CubicBezier, QuadraticBezier)):
            # Arc.delta is unreliable (svgelements can hand back degrees as
            # radians), so arcs and Beziers alike are re-derived from three
            # sampled points; anything that isn't a true circular arc
            # (elliptical, or a Bezier that isn't circle-like) is flattened.
            s, e = _pt(seg.start), _pt(seg.end)
            if not verts:
                add(s)
            pm = _pt(seg.point(0.5))
            bulge = _bulge_from_three(s, pm, e)
            ok = bulge is not None
            if ok:
                pts = _flatten_arc_points(s, e, bulge)
                for t in (0.25, 0.75):
                    q = _pt(seg.point(t))
                    # distance from q to the nearest flattened-arc sample
                    if min(math.hypot(q[0] - a[0], q[1] - a[1]) for a in _flatten_arc_points(s, e, bulge, n=400)) > 0.02:
                        ok = False
                        break
            if ok:
                verts[-1] = (verts[-1][0], verts[-1][1], bulge)
                add(e)
            else:
                for k in range(1, 13):
                    add(_pt(seg.point(k / 12)))
    flush()
    return loops


def loop_points(verts, closed=True, n=48):
    pts = []
    m = len(verts)
    for i in range(m if closed else m - 1):
        a, b = verts[i], verts[(i + 1) % m]
        seg = _flatten_arc_points((a[0], a[1]), (b[0], b[1]), a[2], n)
        pts.extend(seg[:-1])
    pts.append((verts[-1][0], verts[-1][1]) if not closed else (verts[0][0], verts[0][1]))
    return pts


def as_circle(verts):
    """(cx, cy, r) if a closed loop traces a full circle, else None."""
    pts = loop_points(verts)
    if len(pts) < 8:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    if w < 1e-6 or abs(w - h) > 0.03 * max(w, h):
        return None
    r = (w + h) / 4
    if max(abs(math.hypot(p[0] - cx, p[1] - cy) - r) for p in pts) > 0.02 * max(r, 1.0):
        return None
    return cx, cy, r


def bbox_of(verts, closed=True):
    pts = loop_points(verts, closed)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def _contains(outer, inner, tol=0.5):
    return outer[0] - tol <= inner[0] and outer[1] - tol <= inner[1] and outer[2] + tol >= inner[2] and outer[3] + tol >= inner[3]


def _reverse_verts(verts):
    """The same open polyline walked backwards (each segment's bulge flips)."""
    n = len(verts)
    return [(verts[i][0], verts[i][1], -verts[i - 1][2] if i > 0 else 0.0) for i in range(n - 1, -1, -1)]


def _near(a, b, tol):
    return math.hypot(a[0] - b[0], a[1] - b[1]) < tol


def chain_open(pieces, tol=0.1):
    """Join open pieces that touch end-to-end (DXF-style exports draw an
    outline as separate line/arc entities) into longer chains. Returns
    (closed_loops, still_open_chains), each a list of (x, y, bulge)."""
    remaining = [list(p) for p in pieces if len(p) >= 2]
    closed, opened = [], []
    while remaining:
        cur = remaining.pop(0)
        grew = True
        while grew:
            grew = False
            for i, other in enumerate(remaining):
                if _near(cur[-1], other[0], tol):
                    cur = cur[:-1] + other
                elif _near(cur[-1], other[-1], tol):
                    cur = cur[:-1] + _reverse_verts(other)
                elif _near(cur[0], other[-1], tol):
                    cur = other[:-1] + cur
                elif _near(cur[0], other[0], tol):
                    cur = _reverse_verts(other)[:-1] + cur
                else:
                    continue
                remaining.pop(i)
                grew = True
                break
        if len(cur) >= 4 and _near(cur[0], cur[-1], tol):
            closed.append(cur[:-1])
        else:
            opened.append(cur)
    return closed, opened


def collect(svg: SVG, min_guide_mm: float = 5.0):
    """(black, red): each a list of dicts {verts, closed, bbox, circle}."""
    black, red = [], []
    open_pieces = {"black": [], "red": []}

    def add(cls, verts, closed):
        bb = bbox_of(verts, closed)
        if bb[2] - bb[0] < 1e-6 and bb[3] - bb[1] < 1e-6:
            return
        item = {"verts": verts, "closed": closed, "bbox": bb, "circle": as_circle(verts) if closed else None}
        (black if cls == "black" else red).append(item)

    for e in svg.elements():
        if not isinstance(e, Shape):
            continue
        cls = stroke_class(e)
        if cls not in ("black", "red"):
            continue
        if isinstance(e, SvgPath) and len(e) == 0:
            continue
        try:
            loops = path_to_loops(e)
        except Exception:
            continue
        for verts, closed in loops:
            if len(verts) < 2:
                continue
            if not closed and len(verts) >= 3:
                # A path whose end just misses its start is a closed shape.
                if _near(verts[0], verts[-1], 0.6):
                    closed = True
            if closed:
                add(cls, verts, True)
            else:
                open_pieces[cls].append(verts)
                add(cls, verts, False)

    # Chain touching open pieces into closed loops (outlines drawn edge by
    # edge); the loose pieces themselves stay in the lists as open items.
    for cls in ("black", "red"):
        closed_loops, _still_open = chain_open(open_pieces[cls])
        for loop in closed_loops:
            add(cls, loop, True)
    return black, red


def _area(bb):
    return (bb[2] - bb[0]) * (bb[3] - bb[1])


def pick_outline(black, red):
    """The closed red shape containing the most black cut shapes; the smallest
    wins a tie, which also skips a big red "sheet" rectangle drawn around
    everything. None if no red shape contains any cut shape at all (the file
    just doesn't draw the board outline)."""
    best, best_key = None, None
    for it in red:
        if not it["closed"]:
            continue
        w, h = it["bbox"][2] - it["bbox"][0], it["bbox"][3] - it["bbox"][1]
        if w < 5 or h < 5:
            continue
        count = sum(1 for b in black if _contains(it["bbox"], b["bbox"]))
        if count == 0:
            continue
        key = (count, -_area(it["bbox"]))
        if best_key is None or key > best_key:
            best, best_key = it, key
    return best


def _r(v, n=4):
    v = round(v, n)
    return 0.0 if v == 0 else v


def polyline_entity(verts, closed, dx, dy):
    return {
        "type": "polyline",
        "closed": bool(closed),
        "vertices": [{"x": _r(x - dx), "y": _r(y - dy), "bulge": _r(b, 6)} for x, y, b in verts],
    }


def circle_entity(cx, cy, r, dx, dy):
    return {"type": "circle", "center": {"x": _r(cx - dx), "y": _r(cy - dy)}, "radius": _r(r)}


def build_template(svg: SVG, kind: str = "component"):
    """-> (entities, outline_bbox_mm, warnings)."""
    black, red = collect(svg)
    warnings: list = []
    if kind == "model":
        closed = [it for it in black if it["closed"]]
        if not closed:
            raise ValueError("no closed black shapes found")
        outline = max(closed, key=lambda it: (it["bbox"][2] - it["bbox"][0]) * (it["bbox"][3] - it["bbox"][1]))
        cut = [it for it in black if it is not outline and _contains(outline["bbox"], it["bbox"], 0.05)]
        skipped = len(black) - 1 - len(cut)
        if skipped:
            warnings.append(f"{skipped} black shape(s) outside the outline were ignored")
    else:
        outline = pick_outline(black, red)
        if outline is None:
            raise ValueError("no closed red outline found")
        cut = [it for it in black if _contains(outline["bbox"], it["bbox"])]
        if len(cut) < len(black):
            warnings.append(f"{len(black) - len(cut)} black shape(s) outside the outline were ignored")

    x0, y0, x1, y1 = outline["bbox"]
    entities = [polyline_entity(outline["verts"], True, x0, y0)]
    for it in cut:
        if it["circle"]:
            cx, cy, r = it["circle"]
            entities.append(circle_entity(cx, cy, r, x0, y0))
        elif it["closed"]:
            entities.append(polyline_entity(it["verts"], True, x0, y0))
        else:
            entities.append(polyline_entity(it["verts"], False, x0, y0))
    return entities, (x0, y0, x1, y1), warnings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("svg", type=Path)
    ap.add_argument("--id", dest="id_")
    ap.add_argument("--name")
    ap.add_argument("--category", choices=VALID_CATEGORIES)
    ap.add_argument("--kind", choices=("component", "model"), default="component")
    ap.add_argument("-o", "--output", type=Path)
    args = ap.parse_args()

    entities, bb, warnings = build_template(load_svg(args.svg), args.kind)
    w, h = bb[2] - bb[0], bb[3] - bb[1]
    circles = [e for e in entities if e["type"] == "circle"]
    print(f"Outline {w:.2f} x {h:.2f} mm, {len(circles)} circle(s), {len(entities) - 1 - len(circles)} other cut shape(s)")
    for wmsg in warnings:
        print("warning:", wmsg, file=sys.stderr)
    if args.output:
        if not (args.id_ and args.name and args.category):
            print("--output needs --id, --name and --category", file=sys.stderr)
            return 1
        template = {"id": args.id_, "name": args.name, "category": args.category, "entities": entities}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(template, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
